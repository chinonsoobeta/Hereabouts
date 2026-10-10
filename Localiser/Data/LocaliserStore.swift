import CoreData
import Observation

enum LocaliserError: LocalizedError, Equatable {
    case nameRequired, placeCycle, occupiedPlace, schemaUnavailable, dateNotConfirmed, invalidReminder, closedReturn
    case invalidPackingEntry, invalidTripDates, packingConflict(String), incompleteDeparture, unresolvedHome
    case invalidBackup(String), libraryNotEmpty, tooLong(String, Int)
    var errorDescription: String? {
        switch self {
        case .nameRequired: "Enter a name."
        case .tooLong(let field, let limit): "\(field) can be up to \(limit.formatted()) characters."
        case .placeCycle: "A place cannot be moved into itself or one of its contents."
        case .occupiedPlace: "Move what's inside first, or clear its place, before deleting this place."
        case .schemaUnavailable: "The data model is missing. Your library has not been deleted."
        case .dateNotConfirmed: "Review and confirm the final date before saving it."
        case .invalidReminder: "Choose a valid reminder time and lead time."
        case .closedReturn: "Choose to reopen this return decision before editing it."
        case .invalidPackingEntry: "Check the thing, quantity and trip before changing this list."
        case .invalidTripDates: "The return date must be on or after the departure date."
        case .packingConflict(let trip): "This is already packed for \(trip). Unpack it there or finish that trip first."
        case .incompleteDeparture: "Finish packing and the departure checklist before marking yourself away."
        case .unresolvedHome: "Say where the rest of the things went before finishing coming home."
        case .invalidBackup(let reason): reason
        case .libraryNotEmpty: "Your library already has records. Choose Erase and restore to replace them with this backup, or export them first."
        }
    }
}

/// Maximum lengths for free text, so a pasted document cannot swamp every list row.
enum TextLimit {
    static let name = 120
    static let aliases = 1_000
    static let notes = 5_000
}

@MainActor @Observable
final class LocaliserStore {
    let container: NSPersistentContainer
    let isUserLibrary: Bool
    var items: [Belonging] = []
    var searchIndex: [ItemSearch.Entry] = []
    var places: [Place] = []
    var deadlines: [Deadline] = []
    /// Successful scans in the current calendar month. The free tier resets on the 1st.
    var completedScans = 0
    var kits: [Kit] = []
    var trips: [TripRecord] = []
    var tripEntries: [TripEntry] = []
    var revision = 0
    /// Name of the most recent permanent deletion that can still be undone.
    var undoableDeletion: String?
    /// Item to show on the Find tab, set by Spotlight, Siri or a widget.
    var openedItem: UUID?
    var context: NSManagedObjectContext { container.viewContext }
    /// Items that count toward the free tier. Archived items never do.
    var activeItemCount: Int { items.lazy.filter { !$0.archived }.count }

    init(url: URL? = nil, inMemory: Bool = false) throws {
        isUserLibrary = url == nil && !inMemory
        guard let model = LocaliserModel.shared else { throw LocaliserError.schemaUnavailable }
        container = NSPersistentContainer(name: "Localiser", managedObjectModel: model)
        let description = NSPersistentStoreDescription()
        if inMemory { description.type = NSInMemoryStoreType }
        else {
            let file = try url ?? Self.defaultStoreURL()
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            description.url = file
        }
        description.shouldAddStoreAsynchronously = false
        description.shouldMigrateStoreAutomatically = true
        description.shouldInferMappingModelAutomatically = true
        // Earlier builds enabled history tracking. Turning it off would make those stores read-only.
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        container.persistentStoreDescriptions = [description]
        var loadError: Error?
        container.loadPersistentStores { _, error in loadError = error }
        if let loadError { throw loadError }
        context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        context.automaticallyMergesChangesFromParent = true
        try backfillConfirmation()
        try refresh()
    }

    /// Libraries from before V6 have no confirmation date; the last move or the day it was added stands in.
    private func backfillConfirmation() throws {
        let request = NSFetchRequest<Belonging>(entityName: "Belonging")
        request.predicate = NSPredicate(format: "confirmedAt == nil")
        let items = try context.fetch(request)
        guard !items.isEmpty else { return }
        for item in items { item.confirmedAt = item.movements.map(\.date).max() ?? item.createdAt }
        try context.save()
    }

    /// The on-device library file. The name predates the Hereabouts rename and must not change.
    static func defaultStoreURL() throws -> URL {
        let directory = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("Localiser.sqlite")
    }

    func refresh() throws {
        let itemRequest = NSFetchRequest<Belonging>(entityName: "Belonging")
        itemRequest.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        items = try context.fetch(itemRequest)
        searchIndex = items.map(ItemSearch.Entry.init)
        places = try context.fetch(NSFetchRequest<Place>(entityName: "Place")).sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
        deadlines = try context.fetch(NSFetchRequest<Deadline>(entityName: "Deadline")).sorted { $0.dayString < $1.dayString }
        let scanRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "ScanRecord")
        let monthStart = Calendar.current.dateInterval(of: .month, for: .now)?.start ?? .distantPast
        scanRequest.predicate = NSPredicate(format: "counted == YES AND createdAt >= %@", monthStart as NSDate)
        completedScans = try context.count(for: scanRequest)
        kits = try context.fetch(NSFetchRequest<Kit>(entityName: "Kit")).sorted { $0.name < $1.name }
        trips = try context.fetch(NSFetchRequest<TripRecord>(entityName: "TripRecord")).sorted { $0.startDay > $1.startDay }
        tripEntries = try context.fetch(NSFetchRequest<TripEntry>(entityName: "TripEntry"))
        revision += 1
    }

    func save(keepingUndo: Bool = false) throws {
        // Any other change closes the undo window, so Undo can only ever reverse the deletion.
        if !keepingUndo { forgetUndo() }
        do { try context.save(); try refresh() }
        catch { context.rollback(); try? refresh(); throw error }
    }

    @discardableResult
    func addItem(name: String, place: Place? = nil, notes: String = "", aliases: String = "", photo: Data? = nil) throws -> Belonging {
        // Validate everything before inserting, so a rejected item never lingers half-made in the context.
        let clean = try requiredName(name)
        let cleanNotes = try limited(notes, TextLimit.notes), cleanAliases = try limited(aliases, TextLimit.aliases)
        let item = NSEntityDescription.insertNewObject(forEntityName: "Belonging", into: context) as! Belonging
        item.id = UUID(); item.name = clean; item.notes = cleanNotes; item.aliases = cleanAliases
        item.createdAt = .now; item.confirmedAt = .now; item.archived = false; item.place = place; item.photo = photo
        try save()
        return item
    }

    func editItem(_ item: Belonging, name: String, place: Place?, notes: String, aliases: String, photo: Data?) throws {
        let clean = try requiredName(name)
        let cleanNotes = try limited(notes, TextLimit.notes), cleanAliases = try limited(aliases, TextLimit.aliases)
        recordMove(item, to: place)
        item.name = clean; item.notes = cleanNotes; item.aliases = cleanAliases; item.photo = photo
        try save()
    }

    func move(_ item: Belonging, to place: Place?) throws {
        recordMove(item, to: place)
        item.confirmedAt = .now
        try save()
    }

    /// "Still there": the thing is where the notebook says.
    func confirm(_ item: Belonging, on date: Date = .now) throws {
        item.confirmedAt = date
        try save()
    }

    func recordMove(_ item: Belonging, to place: Place?) {
        guard item.place?.id != place?.id else { return }
        item.confirmedAt = .now
        let movement = NSEntityDescription.insertNewObject(forEntityName: "Movement", into: context) as! Movement
        movement.id = UUID(); movement.date = .now; movement.item = item
        movement.fromPath = item.place?.path ?? Movement.noPlace
        movement.toPath = place?.path ?? Movement.noPlace
        item.place = place
    }

    @discardableResult
    func addPlace(name: String, parent: Place? = nil) throws -> Place {
        let clean = try requiredName(name)
        let place = NSEntityDescription.insertNewObject(forEntityName: "Place", into: context) as! Place
        place.id = UUID(); place.name = clean; place.parent = parent
        try save()
        return place
    }

    func editPlace(_ place: Place, name: String, parent: Place?) throws {
        let clean = try requiredName(name)
        if parent?.isWithin(place) == true { throw LocaliserError.placeCycle }
        place.name = clean; place.parent = parent
        try save()
    }

    func deletePlace(_ place: Place, clearContents: Bool = false) throws {
        if !clearContents && (!place.items.isEmpty || !place.children.isEmpty) { throw LocaliserError.occupiedPlace }
        for item in place.items { recordMove(item, to: nil) }
        for child in place.children { child.parent = nil }
        context.delete(place)
        try save()
    }

    func setArchived(_ item: Belonging, _ archived: Bool) throws { item.archived = archived; try save() }

    /// Permanently deletes an item. Call `undoLastDeletion()` shortly afterwards to bring it back.
    func deleteItem(_ item: Belonging) throws {
        let undo = UndoManager()
        forgetUndo()
        context.processPendingChanges()
        context.undoManager = undo
        undo.beginUndoGrouping()
        let name = item.name
        for entry in item.kitEntries { entry.name = item.name; entry.unlinked = true }
        for entry in item.tripEntries { entry.name = item.name; entry.unlinked = true }
        for movement in item.movements { context.delete(movement) }
        for deadline in item.deadlines { context.delete(deadline) }
        for scan in item.scans { context.delete(scan) }
        context.delete(item)
        context.processPendingChanges()
        undo.endUndoGrouping()
        do { try save(keepingUndo: true) } catch { context.undoManager = nil; undoableDeletion = nil; throw error }
        undoableDeletion = name
    }

    /// Restores the item removed by the last `deleteItem`, with its dates, scans and history.
    func undoLastDeletion() throws {
        guard let undo = context.undoManager, undo.canUndo else { undoableDeletion = nil; return }
        undo.undo()
        context.undoManager = nil
        undoableDeletion = nil
        try save(keepingUndo: true)
    }

    /// Ends the undo window, so later edits are not tracked.
    func forgetUndo() {
        context.undoManager = nil
        undoableDeletion = nil
    }

    @discardableResult
    func setDeadline(item: Belonging, kind: DeadlineKind, day: CalendarDay, source: String, leadDays: Int, hour: Int, enabled: Bool, confirmed: Bool, existing: Deadline? = nil, reopen: Bool = false, scan: ScanDraft? = nil, retainSource: Bool = false) throws -> Deadline {
        guard confirmed else { throw LocaliserError.dateNotConfirmed }
        guard (0...3650).contains(leadDays), (0...23).contains(hour) else { throw LocaliserError.invalidReminder }
        if let existing, existing.kind == .returns, [.keeping, .returned].contains(existing.decision), !reopen { throw LocaliserError.closedReturn }
        let deadline = existing ?? (NSEntityDescription.insertNewObject(forEntityName: "Deadline", into: context) as! Deadline)
        if existing == nil { deadline.id = UUID(); deadline.decisionRaw = ReturnDecision.open.rawValue }
        if reopen { deadline.decisionRaw = ReturnDecision.open.rawValue }
        deadline.item = item; deadline.kindRaw = kind.rawValue; deadline.dayString = day.stored
        deadline.source = source; deadline.leadDays = Int16(leadDays); deadline.hour = Int16(hour); deadline.enabled = enabled
        if let scan {
            let record = NSEntityDescription.insertNewObject(forEntityName: "ScanRecord", into: context) as! ScanRecord
            record.id = UUID(); record.createdAt = .now; record.item = item
            record.counted = !scan.candidates.isEmpty
            record.filename = retainSource ? scan.filename : "Date-only scan"
            record.mime = retainSource ? scan.mime : ""
            record.data = retainSource ? scan.data : nil
        }
        try save()
        return deadline
    }

    func decide(_ deadline: Deadline, _ decision: ReturnDecision) throws {
        guard deadline.kind == .returns else { return }
        deadline.decisionRaw = decision.rawValue
        if decision == .returned { deadline.item?.archived = true }
        try save()
    }

    func deleteDeadline(_ deadline: Deadline) throws { context.delete(deadline); try save() }

    func removeScanSource(_ scan: ScanRecord) throws {
        scan.data = nil; scan.filename = "Date-only scan"; scan.mime = ""
        try save()
    }

    func requiredName(_ name: String) throws -> String {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { throw LocaliserError.nameRequired }
        guard clean.count <= TextLimit.name else { throw LocaliserError.tooLong("Names", TextLimit.name) }
        return clean
    }

    func limited(_ text: String, _ limit: Int) throws -> String {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.count <= limit else { throw LocaliserError.tooLong(limit == TextLimit.notes ? "Notes" : "Other names", limit) }
        return clean
    }

    /// Another place with the same name at the same level, if one exists. Used to warn, not to block.
    func duplicatePlace(named name: String, parent: Place?, excluding: Place? = nil) -> Place? {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return places.first { $0 != excluding && $0.parent == parent && $0.name.localizedCaseInsensitiveCompare(clean) == .orderedSame }
    }
}
