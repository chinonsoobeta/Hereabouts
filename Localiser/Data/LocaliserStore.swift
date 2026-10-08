import CoreData
import Observation

enum LocaliserError: LocalizedError, Equatable {
    case nameRequired, placeCycle, occupiedPlace, schemaUnavailable, dateNotConfirmed, invalidReminder, closedReturn
    var errorDescription: String? {
        switch self {
        case .nameRequired: "Enter a name."
        case .placeCycle: "A place cannot be moved into itself or one of its contents."
        case .occupiedPlace: "Move the contents first, or explicitly clear their locations before deleting this place."
        case .schemaUnavailable: "The data model is missing. Your library has not been deleted."
        case .dateNotConfirmed: "Review and confirm the final date before saving it."
        case .invalidReminder: "Choose a valid reminder time and lead time."
        case .closedReturn: "Choose to reopen this return decision before editing it."
        }
    }
}

@MainActor @Observable
final class LocaliserStore {
    let container: NSPersistentContainer
    var items: [Belonging] = []
    var places: [Place] = []
    var deadlines: [Deadline] = []
    var completedScans = 0
    var revision = 0
    var context: NSManagedObjectContext { container.viewContext }

    init(url: URL? = nil, inMemory: Bool = false) throws {
        guard let model = LocaliserModel.shared else { throw LocaliserError.schemaUnavailable }
        container = NSPersistentContainer(name: "Localiser", managedObjectModel: model)
        let description = NSPersistentStoreDescription()
        if inMemory { description.type = NSInMemoryStoreType }
        else {
            let directory = try url?.deletingLastPathComponent() ?? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            description.url = url ?? directory.appendingPathComponent("Localiser.sqlite")
        }
        description.shouldAddStoreAsynchronously = false
        description.shouldMigrateStoreAutomatically = true
        description.shouldInferMappingModelAutomatically = true
        container.persistentStoreDescriptions = [description]
        var loadError: Error?
        container.loadPersistentStores { _, error in loadError = error }
        if let loadError { throw loadError }
        context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        context.automaticallyMergesChangesFromParent = true
        try refresh()
    }

    func refresh() throws {
        let itemRequest = NSFetchRequest<Belonging>(entityName: "Belonging")
        itemRequest.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        items = try context.fetch(itemRequest)
        places = try context.fetch(NSFetchRequest<Place>(entityName: "Place")).sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
        deadlines = try context.fetch(NSFetchRequest<Deadline>(entityName: "Deadline")).sorted { $0.dayString < $1.dayString }
        let scanRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "ScanRecord")
        scanRequest.predicate = NSPredicate(format: "counted == YES")
        completedScans = try context.count(for: scanRequest)
        revision += 1
    }

    func save() throws {
        do { try context.save(); try refresh() }
        catch { context.rollback(); try? refresh(); throw error }
    }

    @discardableResult
    func addItem(name: String, place: Place? = nil, notes: String = "", aliases: String = "", photo: Data? = nil) throws -> Belonging {
        let clean = try requiredName(name)
        let item = NSEntityDescription.insertNewObject(forEntityName: "Belonging", into: context) as! Belonging
        item.id = UUID(); item.name = clean; item.notes = notes; item.aliases = aliases
        item.createdAt = .now; item.archived = false; item.place = place; item.photo = photo
        try save()
        return item
    }

    func editItem(_ item: Belonging, name: String, place: Place?, notes: String, aliases: String, photo: Data?) throws {
        let clean = try requiredName(name)
        recordMove(item, to: place)
        item.name = clean; item.notes = notes; item.aliases = aliases; item.photo = photo
        try save()
    }

    func move(_ item: Belonging, to place: Place?) throws {
        recordMove(item, to: place)
        try save()
    }

    private func recordMove(_ item: Belonging, to place: Place?) {
        guard item.place?.id != place?.id else { return }
        let movement = NSEntityDescription.insertNewObject(forEntityName: "Movement", into: context) as! Movement
        movement.id = UUID(); movement.date = .now; movement.item = item
        movement.fromPath = item.place?.path ?? "Unspecified"
        movement.toPath = place?.path ?? "Unspecified"
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

    private func requiredName(_ name: String) throws -> String {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { throw LocaliserError.nameRequired }
        return clean
    }
}
