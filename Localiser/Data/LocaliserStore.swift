import CoreData
import Observation

enum LocaliserError: LocalizedError, Equatable {
    case nameRequired, placeCycle, occupiedPlace, schemaUnavailable, dateNotConfirmed, invalidReminder
    case invalidPackingEntry, invalidTripDates, packingConflict(String), incompleteDeparture, unresolvedHome
    case invalidBackup(String), libraryNotEmpty, tooLong(String, Int), homeNotEmpty, lastHome
    var errorDescription: String? {
        switch self {
        case .nameRequired: "Enter a name."
        case .tooLong(let field, let limit): "\(field) can be up to \(limit.formatted()) characters."
        case .placeCycle: "A place can't go inside itself, or inside anything it holds."
        case .occupiedPlace: "Move what's inside somewhere else first."
        case .schemaUnavailable: "Hereabouts couldn't open your notebook. Nothing has been deleted."
        case .dateNotConfirmed: "Review and confirm the final date before saving it."
        case .invalidReminder: "Choose when to be reminded."
        case .invalidPackingEntry: "Check the thing, quantity and trip before changing this list."
        case .invalidTripDates: "Come home on or after the day you leave."
        case .packingConflict(let trip): "This is already packed for \(trip). Unpack it there or finish that trip first."
        case .incompleteDeparture: "Finish packing and the departure checklist before marking yourself away."
        case .unresolvedHome: "Say where the rest of the things went before finishing coming home."
        case .invalidBackup(let reason): reason
        case .homeNotEmpty: "Move or delete what's in this home first."
        case .lastHome: "The notebook needs at least one home."
        case .libraryNotEmpty: "This notebook already has things in it. Choose Erase and restore to replace them, or back them up first."
        }
    }
}

/// Maximum lengths for free text, so a pasted document cannot swamp every list row.
enum TextLimit {
    static let name = 120
    static let aliases = 1_000
    static let notes = 5_000
    static let source = 2_000
}

@MainActor @Observable
final class LocaliserStore {
    let container: NSPersistentContainer
    let isUserLibrary: Bool
    var items: [Belonging] = []
    var searchIndex: [ItemSearch.Entry] = []
    var places: [Place] = []
    var deadlines: [Deadline] = []
    var kits: [Kit] = []
    var trips: [TripRecord] = []
    var tripEntries: [TripEntry] = []
    var homes: [HomeRecord] = []
    /// Who is making changes, for "Sam moved it". Empty for the phone's owner; set once a home is shared.
    var author = ""
    var currentHomeID = UserDefaults.standard.string(forKey: LocaliserStore.currentHomeKey).flatMap(UUID.init(uuidString:))
    var revision = 0
    /// Name of the most recent permanent deletion that can still be undone.
    var undoableDeletion: String?
    /// Item to show on the Find tab, set by Spotlight, Siri or a widget.
    var openedItem: UUID?
    /// An app icon shortcut or link for Find: search, write something down, or put something away.
    var findRequest: AppLink?
    /// A place opened from a box label.
    var openedPlace: UUID?
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
            let file = try url ?? NotebookFile.location(legacy: Self.defaultStoreURL())
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
        context.transactionAuthor = Self.appAuthor
        try backfillConfirmation()
        try ensureHomes()
        try removeCutDates()
        // A failed trim only costs disk space.
        if !inMemory { try? trimHistory() }
        try refresh()
    }

    /// Who the app's own saves are from, so it can skip them when reading the history.
    static let appAuthor = "app"

    /// Without trimming, every edit ever made stays in the library file. Only history every reader has
    /// seen goes (see `mergeOutsideChanges`).
    func trimHistory(before cutoff: Date = LocaliserStore.historyCutoff()) throws {
        try context.execute(NSPersistentHistoryChangeRequest.deleteHistory(before: cutoff))
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

    /// Return, warranty and expiry dates and receipt scans left Hereabouts in 1.0. The first launch after the
    /// update deletes them from the notebook; ask-back dates stay. The ScanRecord entity stays in the model, empty.
    func removeCutDates() throws {
        let dates = NSFetchRequest<NSManagedObject>(entityName: "Deadline")
        dates.predicate = NSPredicate(format: "kindRaw != %@", DeadlineKind.askBack.rawValue)
        let removed = try context.fetch(dates) + context.fetch(NSFetchRequest<NSManagedObject>(entityName: "ScanRecord"))
        guard !removed.isEmpty else { return }
        for object in removed { context.delete(object) }
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
        kits = try context.fetch(NSFetchRequest<Kit>(entityName: "Kit")).sorted { $0.name < $1.name }
        trips = try context.fetch(NSFetchRequest<TripRecord>(entityName: "TripRecord")).sorted { $0.startDay > $1.startDay }
        tripEntries = try context.fetch(NSFetchRequest<TripEntry>(entityName: "TripEntry"))
        homes = try context.fetch(NSFetchRequest<HomeRecord>(entityName: "Home")).sorted { ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast) }
        revision += 1
    }

    func save(keepingUndo: Bool = false) throws {
        // Any other change closes the undo window, so Undo can only ever reverse the deletion.
        if !keepingUndo { forgetUndo() }
        do { try context.save(); try refresh() }
        catch { context.rollback(); try? refresh(); throw error }
    }

    @discardableResult
    func addItem(name: String, place: Place? = nil, notes: String = "", aliases: String = "", photo: Data? = nil, isPrivate: Bool = false) throws -> Belonging {
        // Validate everything before inserting, so a rejected item never lingers half-made in the context.
        let clean = try requiredName(name)
        let cleanNotes = try limited(notes, TextLimit.notes, field: "Notes"), cleanAliases = try limited(aliases, TextLimit.aliases, field: "Other names")
        let item = NSEntityDescription.insertNewObject(forEntityName: "Belonging", into: context) as! Belonging
        item.id = UUID(); item.name = clean; item.notes = cleanNotes; item.aliases = cleanAliases
        item.createdAt = .now; item.confirmedAt = .now; item.archived = false; item.place = place; item.photo = photo; item.isPrivate = isPrivate
        item.home = place?.home ?? currentHome
        try save()
        return item
    }

    func editItem(_ item: Belonging, name: String, place: Place?, notes: String, aliases: String, photo: Data?, isPrivate: Bool? = nil) throws {
        let clean = try requiredName(name)
        let cleanNotes = try limited(notes, TextLimit.notes, field: "Notes"), cleanAliases = try limited(aliases, TextLimit.aliases, field: "Other names")
        recordMove(item, to: place)
        item.name = clean; item.notes = cleanNotes; item.aliases = cleanAliases; item.photo = photo
        if let isPrivate { item.isPrivate = isPrivate }
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
        movement.id = UUID(); movement.date = .now; movement.item = item; movement.by = author
        movement.fromPath = item.place?.path ?? Movement.noPlace
        movement.toPath = place?.path ?? Movement.noPlace
        item.place = place
        if let home = place?.home { item.home = home }
    }

    @discardableResult
    func addPlace(name: String, parent: Place? = nil, home: HomeRecord? = nil) throws -> Place {
        let clean = try requiredName(name)
        let place = NSEntityDescription.insertNewObject(forEntityName: "Place", into: context) as! Place
        place.id = UUID(); place.name = clean; place.parent = parent
        place.home = parent?.home ?? home ?? currentHome
        try save()
        return place
    }

    func editPlace(_ place: Place, name: String, parent: Place?) throws {
        let clean = try requiredName(name)
        if parent?.isWithin(place) == true { throw LocaliserError.placeCycle }
        place.name = clean; place.parent = parent
        if let parent { move(place, into: parent.home) }
        try save()
    }

    /// With `clearContents`, everything inside moves up a level: into the place's parent, or out of any place
    /// when it was a room. Moving up isn't seeing a thing, so when each was last checked stays as it was.
    func deletePlace(_ place: Place, clearContents: Bool = false) throws {
        if !clearContents && (!place.items.isEmpty || !place.children.isEmpty) { throw LocaliserError.occupiedPlace }
        for item in place.items {
            let seen = item.lastConfirmed
            recordMove(item, to: place.parent)
            item.confirmedAt = seen
        }
        for child in place.children { child.parent = place.parent }
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

    /// Restores the item removed by the last `deleteItem`, with its dates and history.
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
    func setDeadline(item: Belonging, kind: DeadlineKind, day: CalendarDay, source: String, leadDays: Int, hour: Int, enabled: Bool, confirmed: Bool, existing: Deadline? = nil) throws -> Deadline {
        guard confirmed else { throw LocaliserError.dateNotConfirmed }
        guard (0...3650).contains(leadDays), (0...23).contains(hour) else { throw LocaliserError.invalidReminder }
        let cleanSource = try limited(source, TextLimit.source, field: "Source or terms")
        let deadline = existing ?? (NSEntityDescription.insertNewObject(forEntityName: "Deadline", into: context) as! Deadline)
        if existing == nil { deadline.id = UUID(); deadline.decisionRaw = ReturnDecision.open.rawValue }
        deadline.item = item; deadline.kindRaw = kind.rawValue; deadline.dayString = day.stored
        deadline.source = cleanSource; deadline.leadDays = Int16(leadDays); deadline.hour = Int16(hour); deadline.enabled = enabled
        try save()
        return deadline
    }

    func deleteDeadline(_ deadline: Deadline) throws { context.delete(deadline); try save() }

    func requiredName(_ name: String) throws -> String {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { throw LocaliserError.nameRequired }
        guard clean.count <= TextLimit.name else { throw LocaliserError.tooLong("Names", TextLimit.name) }
        return clean
    }

    func limited(_ text: String, _ limit: Int, field: String) throws -> String {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.count <= limit else { throw LocaliserError.tooLong(field, limit) }
        return clean
    }

    /// Another place with the same name at the same level, if one exists. Used to warn, not to block.
    func duplicatePlace(named name: String, parent: Place?, excluding: Place? = nil, home: HomeRecord? = nil) -> Place? {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let home = parent?.home ?? home ?? currentHome
        return places.first { $0 != excluding && $0.parent == parent && $0.home == home && $0.name.localizedCaseInsensitiveCompare(clean) == .orderedSame }
    }
}
