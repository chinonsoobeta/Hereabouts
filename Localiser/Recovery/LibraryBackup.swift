import CoreData

enum BackupValue: Codable, Sendable, Equatable {
    case string(String), integer(Int64), boolean(Bool), date(Date), data(Data)
    var foundationValue: Any {
        switch self { case .string(let v): v; case .integer(let v): v; case .boolean(let v): v; case .date(let v): v; case .data(let v): v }
    }
}

struct BackupRecord: Codable, Sendable {
    var id: UUID
    var entity: String
    var attributes: [String: BackupValue]
    var relationships: [String: [UUID]]
    func string(_ key: String) -> String? { if case .string(let value) = attributes[key] { return value }; return nil }
    func integer(_ key: String) -> Int64? { if case .integer(let value) = attributes[key] { return value }; return nil }
}

struct LibraryBackup: Codable, Sendable {
    /// 2 added private, missing and lent things, kinds of move, and ask-back dates. 3 added homes and who moved
    /// a thing. Version 1 and 2 backups still restore, into one home.
    static let currentVersion = 3
    var version = currentVersion
    var createdAt = Date()
    var records: [BackupRecord]
    static let maximumBytes = 200 * 1024 * 1024
    /// The largest single photo a backup can carry.
    static let maximumFileBytes = 20 * 1024 * 1024

    func encoded() throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(self)
        guard data.count <= Self.maximumBytes else { throw LocaliserError.invalidBackup("This backup would be over 200 MB. Choose fewer photos and documents.") }
        return data
    }
    /// What's inside, as a person would say it: "12 things, 5 places and 3 dates".
    var contents: String {
        let kinds = [("Belonging", "thing", "things"), ("Place", "place", "places"), ("Deadline", "date", "dates"), ("Kit", "kit", "kits"), ("TripRecord", "trip", "trips")]
        let parts = kinds.compactMap { entity, one, many -> String? in
            let count = records.filter { $0.entity == entity }.count
            return count == 0 ? nil : count == 1 ? "1 \(one)" : "\(count) \(many)"
        }
        guard let last = parts.last else { return "An empty notebook" }
        return parts.count == 1 ? last : parts.dropLast().joined(separator: ", ") + " and " + last
    }

    static func decoded(_ data: Data) throws -> Self {
        guard data.count <= maximumBytes else { throw LocaliserError.invalidBackup("Choose a Hereabouts backup under 200 MB.") }
        struct Header: Decodable { var version: Int }
        do { return try JSONDecoder().decode(Self.self, from: data) } catch {
            // Say which problem it is. A newer app's backup gives its version. Every backup this app writes starts
            // with its date, because the keys are sorted, so a cut-off one is damaged. Anything else was never a backup.
            if let header = try? JSONDecoder().decode(Header.self, from: data), header.version > currentVersion { throw LocaliserError.invalidBackup(newerVersion) }
            throw LocaliserError.invalidBackup(data.starts(with: Data(#"{"createdAt":"#.utf8)) ? damaged : notABackup)
        }
    }
    /// Return, warranty and expiry dates from before 1.0 still restore, kept as they are but not shown.
    static let deadlineKinds: Set<String> = ["askBack", "returns", "warranty", "expiry"]
    static let decisions: Set<String> = ["open", "returned", "keeping", "returning"]
    static let newerVersion = "You need a newer version of Hereabouts for this backup. Update the app and try again."
    static let damaged = "This backup is damaged. Choose another one."
    static let notABackup = "This file isn't a Hereabouts backup. Choose one made with Back up everything."
}

@MainActor extension LocaliserStore {
    func backup(attachmentIDs: Set<UUID> = []) throws -> LibraryBackup {
        var records: [BackupRecord] = []
        var binaryBytes = 0
        for entity in container.managedObjectModel.entities {
            guard let name = entity.name else { continue }
            for object in try context.fetch(NSFetchRequest<NSManagedObject>(entityName: name)) {
                guard let id = object.value(forKey: "id") as? UUID else { throw LocaliserError.invalidBackup("Something in this notebook couldn't be backed up. Nothing has changed.") }
                var attributes: [String: BackupValue] = [:]
                for (key, attribute) in entity.attributesByName where key != "id" {
                    if attribute.attributeType == .binaryDataAttributeType && !attachmentIDs.contains(id) { continue }
                    guard let value = object.value(forKey: key) else { continue }
                    switch attribute.attributeType {
                    case .stringAttributeType: attributes[key] = .string(value as! String)
                    case .integer16AttributeType, .integer32AttributeType, .integer64AttributeType: attributes[key] = .integer((value as! NSNumber).int64Value)
                    case .booleanAttributeType: attributes[key] = .boolean((value as! NSNumber).boolValue)
                    case .dateAttributeType: attributes[key] = .date(value as! Date)
                    case .binaryDataAttributeType:
                        let data = value as! Data; binaryBytes += data.count
                        guard binaryBytes <= 140 * 1024 * 1024 else { throw LocaliserError.invalidBackup("Choose fewer photos and documents. A backup can hold up to 200 MB.") }
                        attributes[key] = .data(data)
                    default: throw LocaliserError.invalidBackup("Something in this notebook couldn't be backed up. Nothing has changed.")
                    }
                }
                var relationships: [String: [UUID]] = [:]
                for (key, relationship) in entity.relationshipsByName {
                    let related = relationship.isToMany ? (object.value(forKey: key) as? NSSet)?.allObjects.compactMap { $0 as? NSManagedObject } ?? [] : (object.value(forKey: key) as? NSManagedObject).map { [$0] } ?? []
                    relationships[key] = try related.map { value in
                        guard let id = value.value(forKey: "id") as? UUID else { throw LocaliserError.invalidBackup("Something in this notebook couldn't be backed up. Nothing has changed.") }
                        return id
                    }.sorted { $0.uuidString < $1.uuidString }
                }
                records.append(BackupRecord(id: id, entity: name, attributes: attributes, relationships: relationships))
            }
        }
        let file = LibraryBackup(records: records.sorted { $0.id.uuidString < $1.id.uuidString })
        try validateBackup(file)
        return file
    }

    /// Restores a backup. With `replacingExisting`, the current library is erased in the same save,
    /// so a failure leaves it exactly as it was.
    func restore(_ file: LibraryBackup, replacingExisting: Bool = false) throws {
        try validateBackup(file)
        forgetUndo()
        let staging = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        staging.parent = context
        do {
            if replacingExisting {
                for entity in container.managedObjectModel.entities {
                    if let name = entity.name { for object in try context.fetch(NSFetchRequest<NSManagedObject>(entityName: name)) { context.delete(object) } }
                }
            } else {
                // A new notebook already has its first, empty home. It gives way to the backup's homes.
                for entity in container.managedObjectModel.entities where entity.name != "Home" {
                    if let name = entity.name, try context.count(for: NSFetchRequest<NSFetchRequestResult>(entityName: name)) > 0 { throw LocaliserError.libraryNotEmpty }
                }
                for home in try context.fetch(NSFetchRequest<HomeRecord>(entityName: "Home")) { context.delete(home) }
            }
            var objects: [UUID: NSManagedObject] = [:]
            for record in file.records {
                let object = NSEntityDescription.insertNewObject(forEntityName: record.entity, into: staging)
                object.setValue(record.id, forKey: "id")
                for (key, value) in record.attributes { object.setValue(value.foundationValue, forKey: key) }
                objects[record.id] = object
            }
            for record in file.records {
                let object = objects[record.id]!
                for (key, ids) in record.relationships {
                    let relationship = object.entity.relationshipsByName[key]!
                    if relationship.isToMany { object.setValue(NSSet(array: ids.map { objects[$0]! }), forKey: key) }
                    else { object.setValue(ids.first.flatMap { objects[$0] }, forKey: key) }
                }
                try object.validateForInsert()
            }
            // One save: the restored records and any home they need land together.
            try staging.save(); try ensureHomes(saving: false); try save()
            try refresh()
        } catch { staging.rollback(); context.rollback(); try? refresh(); throw error }
    }

    static var laterFields: Set<String> { ["perDay", "unlinked", "confirmedAt", "isPrivate", "missingSince", "lentTo", "lentAt", "kindRaw", "by"] }
    /// Links added after the first format. Older backups omit them; restoring puts everything in one home.
    static var laterRelationships: Set<String> { ["home"] }

    func validateBackup(_ file: LibraryBackup) throws {
        guard file.version <= LibraryBackup.currentVersion else { throw LocaliserError.invalidBackup(LibraryBackup.newerVersion) }
        guard file.version >= 1 else { throw LocaliserError.invalidBackup(LibraryBackup.notABackup) }
        guard file.records.count <= 100_000 else { throw LocaliserError.invalidBackup("This backup is too big to restore.") }
        let schema = container.managedObjectModel.entitiesByName
        var records: [UUID: BackupRecord] = [:]
        for record in file.records {
            guard records[record.id] == nil, let entity = schema[record.entity] else { throw LocaliserError.invalidBackup("Part of this backup is damaged, or from a newer Hereabouts.") }
            let fields = entity.attributesByName.filter { $0.key != "id" }
            // Fields added after the first backup format; older backups omit them and get the model default.
            let required = Set(fields.filter { $0.value.attributeType != .binaryDataAttributeType && !Self.laterFields.contains($0.key) }.keys)
            guard required.isSubset(of: Set(record.attributes.keys)), Set(record.attributes.keys).isSubset(of: Set(fields.keys)), Set(record.relationships.keys).isSubset(of: Set(entity.relationshipsByName.keys)), Set(entity.relationshipsByName.keys).subtracting(record.relationships.keys).isSubset(of: Self.laterRelationships) else { throw LocaliserError.invalidBackup("Part of this backup is damaged, or from a newer Hereabouts.") }
            for (key, value) in record.attributes {
                switch (fields[key]!.attributeType, value) {
                case (.stringAttributeType, .string(let value)):
                    guard value.count <= 500_000, !["name", "title"].contains(key) || !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw LocaliserError.invalidBackup("Something in this backup has no name, or too much text.") }
                case (.booleanAttributeType, .boolean), (.dateAttributeType, .date), (.integer64AttributeType, .integer): break
                case (.integer16AttributeType, .integer(let value)): guard Int16(exactly: value) != nil else { throw LocaliserError.invalidBackup("A number in this backup is too big.") }
                case (.binaryDataAttributeType, .data(let value)): guard value.count <= LibraryBackup.maximumFileBytes else { throw LocaliserError.invalidBackup("A photo or document in this backup is over 20 MB.") }
                default: throw LocaliserError.invalidBackup("Part of this backup is damaged.")
                }
            }
            if record.entity == "Deadline" {
                guard CalendarDay(stored: record.string("dayString") ?? "") != nil, LibraryBackup.deadlineKinds.contains(record.string("kindRaw") ?? ""), LibraryBackup.decisions.contains(record.string("decisionRaw") ?? ""), (0...3650).contains(record.integer("leadDays") ?? -1), (0...23).contains(record.integer("hour") ?? -1) else { throw LocaliserError.invalidBackup("A date in this backup is damaged.") }
            }
            if record.entity == "TripRecord" {
                guard let start = CalendarDay(stored: record.string("startDay") ?? ""), let end = CalendarDay(stored: record.string("endDay") ?? ""), end >= start, TripState(rawValue: record.string("stateRaw") ?? "") != nil else { throw LocaliserError.invalidBackup("A trip in this backup is damaged.") }
            }
            if ["KitEntry", "TripEntry"].contains(record.entity) {
                guard (1...99).contains(record.integer("unitQuantity") ?? 0), PackingCondition(rawValue: record.string("conditionRaw") ?? "") != nil else { throw LocaliserError.invalidBackup("A packing list in this backup is damaged.") }
            }
            if record.entity == "TripEntry" {
                guard (-1...9999).contains(record.integer("manualQuantity") ?? -2), (record.integer("packedCount") ?? -1) >= 0, HomeResolution(rawValue: record.string("resolutionRaw") ?? "") != nil else { throw LocaliserError.invalidBackup("A packing list in this backup is damaged.") }
            }
            records[record.id] = record
        }
        for record in file.records {
            for (key, ids) in record.relationships {
                let relationship = schema[record.entity]!.relationshipsByName[key]!
                guard Set(ids).count == ids.count, relationship.isToMany || ids.count <= 1 else { throw LocaliserError.invalidBackup("Part of this backup is damaged.") }
                for id in ids {
                    guard let related = records[id], related.entity == relationship.destinationEntity?.name,
                          let inverse = relationship.inverseRelationship?.name, related.relationships[inverse]?.contains(record.id) == true else { throw LocaliserError.invalidBackup("Part of this backup is damaged.") }
                }
            }
            if record.entity == "TripRecord", record.string("stateRaw") == TripState.finished.rawValue {
                for id in record.relationships["entries"] ?? [] {
                    let entry = records[id]!
                    guard (entry.integer("packedCount") ?? 0) == 0 || ![HomeResolution.pending.rawValue, HomeResolution.unresolved.rawValue].contains(entry.string("resolutionRaw") ?? "") else { throw LocaliserError.invalidBackup("A finished trip in this backup still has things to put away.") }
                }
            }
        }
        var resolved = Set<UUID>()
        for place in file.records where place.entity == "Place" {
            var path = Set<UUID>(); var next: UUID? = place.id
            while let id = next, !resolved.contains(id) {
                guard path.insert(id).inserted else { throw LocaliserError.invalidBackup("Two places in this backup are inside each other.") }
                next = records[id]?.relationships["parent"]?.first
            }
            resolved.formUnion(path)
        }
    }

    func inventoryCSV() -> String {
        func escaped(_ text: String) -> String {
            let first = text.trimmingCharacters(in: .whitespacesAndNewlines).first
            let safe = first.map { "=+-@".contains($0) } == true ? "'" + text : text
            return "\"" + safe.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        let heading = ["id", "name", "home", "place", "notes", "other names", "archived", "private", "dates"].map(escaped).joined(separator: ",")
        return ([heading] + items.map { item in
            let dates = item.deadlines.filter { $0.kind == .askBack }.sorted { $0.dayString < $1.dayString }.map { "\($0.kind?.title ?? "Date") \($0.dayString)" }
            return [item.id.uuidString, item.name, item.home?.name ?? "", item.place?.path ?? "", item.notes, item.aliases, item.archived ? "yes" : "no", item.isPrivate ? "yes" : "no", dates.joined(separator: "; ")].map(escaped).joined(separator: ",")
        }).joined(separator: "\r\n") + "\r\n"
    }

    func resetLibrary() throws {
        forgetUndo()
        for entity in container.managedObjectModel.entities {
            if let name = entity.name { for object in try context.fetch(NSFetchRequest<NSManagedObject>(entityName: name)) { context.delete(object) } }
        }
        try save()
        try ensureHomes(); try refresh()
    }
}
