import CoreData

/// The widget, share sheet and controls run outside the app, so the notebook moves into a shared
/// App Group folder. Until the group exists (it needs the paid developer account) nothing calls `move`.
enum NotebookFile {
    enum Outcome: Equatable { case moved, alreadyThere, nothingToMove }

    static let movedKey = "notebookMovedToGroup"
    /// Read by the widget and share sheet to apply the free limits.
    static let proUnlockedKey = "proUnlocked"

    /// The App Group named by `HEREABOUTS_APP_GROUP`, or nil while it's empty (before enrolment).
    static var appGroup: String? {
        let name = (Bundle.main.object(forInfoDictionaryKey: "HereaboutsAppGroup") as? String)?.trimmingCharacters(in: .whitespaces) ?? ""
        return name.isEmpty || name.hasPrefix("$(") ? nil : name
    }

    static func sharedDefaults(group: String? = appGroup) -> UserDefaults? { group.flatMap(UserDefaults.init(suiteName:)) }

    /// Where the notebook lives in the group's folder, when there is a group and the phone grants it.
    static func groupStoreURL(group: String? = appGroup) -> URL? {
        guard let group, let folder = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) else { return nil }
        return folder.appendingPathComponent("Library/Application Support/Localiser.sqlite")
    }

    /// The notebook to open. With an App Group, the first launch copies the notebook across and opens
    /// the copy; the launch after that removes the original. Without one, or if the copy fails, the
    /// notebook stays where it was.
    @MainActor static func location(legacy: URL, group: URL? = groupStoreURL(), defaults: UserDefaults = .standard) -> URL {
        guard let group else { return legacy }
        if defaults.bool(forKey: movedKey) {
            try? removeOriginal(at: legacy)
            return group
        }
        do {
            switch try move(from: legacy, to: group) {
            case .moved, .alreadyThere, .nothingToMove: defaults.set(true, forKey: movedKey); return group
            }
        } catch { return legacy }
    }

    enum MoveError: LocalizedError {
        case countsDiffer(String)
        var errorDescription: String? {
            switch self { case .countsDiffer(let entity): "The copied notebook was missing some \(entity) records, so the original was kept." }
        }
    }

    /// Copies the notebook at `source` to `destination`, photos kept outside the database included, and
    /// checks every kind of record arrived. The original stays put until `removeOriginal` is called on a
    /// later launch. Calling it again once the copy exists does nothing.
    @MainActor static func move(from source: URL, to destination: URL) throws -> Outcome {
        let files = FileManager.default
        if files.fileExists(atPath: destination.path) { return .alreadyThere }
        guard files.fileExists(atPath: source.path) else { return .nothingToMove }
        guard let model = LocaliserModel.shared else { throw LocaliserError.schemaUnavailable }
        // Opening the original first brings it up to the current model, so both sides count the same way.
        let before = try counts(at: source, model: model)
        try files.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        try coordinator.replacePersistentStore(at: destination, destinationOptions: options, withPersistentStoreFrom: source, sourceOptions: options, type: .sqlite)
        let after = try counts(at: destination, model: model)
        if let missing = before.keys.sorted().first(where: { before[$0] != after[$0] }) {
            try? coordinator.destroyPersistentStore(at: destination, type: .sqlite, options: options)
            throw MoveError.countsDiffer(missing)
        }
        return .moved
    }

    /// On the launch after a move, once the copy has opened, the original goes.
    @MainActor static func removeOriginal(at source: URL) throws {
        guard FileManager.default.fileExists(atPath: source.path), let model = LocaliserModel.shared else { return }
        try NSPersistentStoreCoordinator(managedObjectModel: model).destroyPersistentStore(at: source, type: .sqlite, options: options)
        // Destroying empties the database but leaves its files, and the folder of photos beside it.
        let name = source.deletingPathExtension().lastPathComponent
        let folder = source.deletingLastPathComponent()
        for leftover in [source.path, source.path + "-wal", source.path + "-shm", folder.appendingPathComponent(".\(name)_SUPPORT").path] {
            try? FileManager.default.removeItem(atPath: leftover)
        }
    }

    private static var options: [String: NSObject] {
        [NSPersistentHistoryTrackingKey: true as NSNumber,
         NSMigratePersistentStoresAutomaticallyOption: true as NSNumber,
         NSInferMappingModelAutomaticallyOption: true as NSNumber]
    }

    /// Records of each kind, plus the photos and scans stored with them.
    private static func counts(at url: URL, model: NSManagedObjectModel) throws -> [String: Int] {
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        let store = try coordinator.addPersistentStore(type: .sqlite, at: url, options: options)
        defer { try? coordinator.remove(store) }
        let entityNames = model.entities.compactMap(\.name)
        let context = NSManagedObjectContext(.privateQueue)
        context.persistentStoreCoordinator = coordinator
        return try context.performAndWait {
            var result: [String: Int] = [:]
            for name in entityNames {
                result[name] = try context.count(for: NSFetchRequest<NSManagedObject>(entityName: name))
            }
            let photos = NSFetchRequest<NSManagedObject>(entityName: "Belonging"); photos.predicate = NSPredicate(format: "photo != nil")
            result["photo"] = try context.count(for: photos)
            let scans = NSFetchRequest<NSManagedObject>(entityName: "ScanRecord"); scans.predicate = NSPredicate(format: "data != nil")
            result["scan"] = try context.count(for: scans)
            return result
        }
    }
}

/// Each part of Hereabouts that reads the notebook (the app, and later the widget and share sheet)
/// remembers how far through the change history it has read. History is only trimmed behind all of them.
struct HistoryLedger {
    var defaults: UserDefaults = .standard
    private static let datesKey = "historyReadDates"
    private static func tokenKey(_ reader: String) -> String { "historyToken.\(reader)" }

    func token(for reader: String) -> NSPersistentHistoryToken? {
        defaults.data(forKey: Self.tokenKey(reader)).flatMap { try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSPersistentHistoryToken.self, from: $0) }
    }

    func record(_ token: NSPersistentHistoryToken, at date: Date, for reader: String) {
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true) { defaults.set(data, forKey: Self.tokenKey(reader)) }
        var dates = defaults.dictionary(forKey: Self.datesKey) as? [String: Date] ?? [:]
        dates[reader] = date
        defaults.set(dates, forKey: Self.datesKey)
    }

    /// The point every reader has reached, or nil before any has read.
    var everyoneRead: Date? { (defaults.dictionary(forKey: Self.datesKey) as? [String: Date])?.values.min() }
}

@MainActor extension LocaliserStore {
    /// Brings in what another process (the widget, the share sheet) saved to the notebook since this
    /// reader last looked. Returns how many outside changes arrived.
    @discardableResult func mergeOutsideChanges(reader: String = LocaliserStore.appAuthor, ledger: HistoryLedger = HistoryLedger()) throws -> Int {
        let request = NSPersistentHistoryChangeRequest.fetchHistory(after: ledger.token(for: reader))
        request.resultType = .transactionsAndChanges
        let result = try context.execute(request) as? NSPersistentHistoryResult
        let transactions = result?.result as? [NSPersistentHistoryTransaction] ?? []
        guard let last = transactions.last else { return 0 }
        let outside = transactions.filter { $0.author != reader }
        for transaction in outside { context.mergeChanges(fromContextDidSave: transaction.objectIDNotification()) }
        ledger.record(last.token, at: last.timestamp, for: reader)
        if !outside.isEmpty { try refresh() }
        return outside.count
    }

    /// The trim cutoff: a week back, but never past a reader that hasn't caught up.
    static func historyCutoff(now: Date = .now, ledger: HistoryLedger = HistoryLedger()) -> Date {
        let week = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now
        return min(week, ledger.everyoneRead ?? week)
    }
}
