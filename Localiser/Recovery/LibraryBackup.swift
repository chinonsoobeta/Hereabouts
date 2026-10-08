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
    var version = 1
    var createdAt = Date()
    var records: [BackupRecord]
    static let maximumBytes = 200 * 1024 * 1024

    func encoded() throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(self)
        guard data.count <= Self.maximumBytes else { throw LocaliserError.invalidBackup("This export exceeds 200 MB. Choose fewer original files; all library records can still be included.") }
        return data
    }
    static func decoded(_ data: Data) throws -> Self {
        guard data.count <= maximumBytes else { throw LocaliserError.invalidBackup("Choose a Localiser backup under 200 MB.") }
        return try JSONDecoder().decode(Self.self, from: data)
    }
}

@MainActor extension LocaliserStore {
    func backup(attachmentIDs: Set<UUID> = []) throws -> LibraryBackup {
        var records: [BackupRecord] = []
        var binaryBytes = 0
        for entity in container.managedObjectModel.entities {
            guard let name = entity.name else { continue }
            for object in try context.fetch(NSFetchRequest<NSManagedObject>(entityName: name)) {
                guard let id = object.value(forKey: "id") as? UUID else { throw LocaliserError.invalidBackup("A record has no identifier. Your library has not been changed.") }
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
                        guard binaryBytes <= 140 * 1024 * 1024 else { throw LocaliserError.invalidBackup("Choose fewer original files for a backup under 200 MB.") }
                        attributes[key] = .data(data)
                    default: throw LocaliserError.invalidBackup("An unsupported stored field could not be exported.")
                    }
                }
                var relationships: [String: [UUID]] = [:]
                for (key, relationship) in entity.relationshipsByName {
                    let related = relationship.isToMany ? (object.value(forKey: key) as? NSSet)?.allObjects.compactMap { $0 as? NSManagedObject } ?? [] : (object.value(forKey: key) as? NSManagedObject).map { [$0] } ?? []
                    relationships[key] = try related.map { value in
                        guard let id = value.value(forKey: "id") as? UUID else { throw LocaliserError.invalidBackup("A related record has no identifier.") }
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

    func restore(_ file: LibraryBackup) throws {
        try validateBackup(file)
        for entity in container.managedObjectModel.entities {
            if let name = entity.name, try context.count(for: NSFetchRequest<NSFetchRequestResult>(entityName: name)) > 0 { throw LocaliserError.libraryNotEmpty }
        }
        guard !syncEnabled else { throw LocaliserError.invalidBackup("Turn off private sync and restart before restoring a local backup. Verify the cloud library before reconnecting it.") }
        guard !hasUsedSync else { throw LocaliserError.invalidBackup("This store has previously used private sync. Restoring into it requires a verified cloud reconnection procedure; use a fresh local installation for file recovery.") }
        let staging = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        staging.parent = context
        do {
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
            try staging.save(); try save()
            if isUserLibrary {
                UserDefaults.standard.set(true, forKey: "restoredLocalLibrary")
                UserDefaults.standard.set(false, forKey: "privateSyncRequested")
            }
        } catch { staging.rollback(); context.rollback(); try? refresh(); throw error }
    }

    func validateBackup(_ file: LibraryBackup) throws {
        guard file.version == 1, file.records.count <= 100_000 else { throw LocaliserError.invalidBackup("This backup version or record count is unsupported.") }
        let schema = container.managedObjectModel.entitiesByName
        var records: [UUID: BackupRecord] = [:]
        for record in file.records {
            guard records[record.id] == nil, let entity = schema[record.entity] else { throw LocaliserError.invalidBackup("Duplicate identifiers or unknown record types were found.") }
            let fields = entity.attributesByName.filter { $0.key != "id" }
            let required = Set(fields.filter { $0.value.attributeType != .binaryDataAttributeType }.keys)
            guard required.isSubset(of: Set(record.attributes.keys)), Set(record.attributes.keys).isSubset(of: Set(fields.keys)), Set(record.relationships.keys) == Set(entity.relationshipsByName.keys) else { throw LocaliserError.invalidBackup("A record has missing or unknown fields.") }
            for (key, value) in record.attributes {
                switch (fields[key]!.attributeType, value) {
                case (.stringAttributeType, .string(let value)):
                    guard value.count <= 500_000, !["name", "title"].contains(key) || !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw LocaliserError.invalidBackup("A name or text field is invalid.") }
                case (.booleanAttributeType, .boolean), (.dateAttributeType, .date), (.integer64AttributeType, .integer): break
                case (.integer16AttributeType, .integer(let value)): guard Int16(exactly: value) != nil else { throw LocaliserError.invalidBackup("A numeric field is out of range.") }
                case (.binaryDataAttributeType, .data(let value)): guard value.count <= ScanReader.maximumBytes else { throw LocaliserError.invalidBackup("An original file exceeds 20 MB.") }
                default: throw LocaliserError.invalidBackup("A field has the wrong value type.")
                }
            }
            if record.entity == "Deadline" {
                guard CalendarDay(stored: record.string("dayString") ?? "") != nil, DeadlineKind(rawValue: record.string("kindRaw") ?? "") != nil, ReturnDecision(rawValue: record.string("decisionRaw") ?? "") != nil, (0...3650).contains(record.integer("leadDays") ?? -1), (0...23).contains(record.integer("hour") ?? -1) else { throw LocaliserError.invalidBackup("A deadline is invalid.") }
            }
            if record.entity == "TripRecord" {
                guard let start = CalendarDay(stored: record.string("startDay") ?? ""), let end = CalendarDay(stored: record.string("endDay") ?? ""), end >= start, TripState(rawValue: record.string("stateRaw") ?? "") != nil else { throw LocaliserError.invalidBackup("A trip date or status is invalid.") }
            }
            if ["KitEntry", "TripEntry"].contains(record.entity) {
                guard (1...99).contains(record.integer("unitQuantity") ?? 0), PackingCondition(rawValue: record.string("conditionRaw") ?? "") != nil else { throw LocaliserError.invalidBackup("A packing rule is invalid.") }
            }
            if record.entity == "TripEntry" {
                guard (-1...9999).contains(record.integer("manualQuantity") ?? -2), (record.integer("packedCount") ?? -1) >= 0, HomeResolution(rawValue: record.string("resolutionRaw") ?? "") != nil else { throw LocaliserError.invalidBackup("Packing progress is invalid.") }
            }
            records[record.id] = record
        }
        for record in file.records {
            for (key, ids) in record.relationships {
                let relationship = schema[record.entity]!.relationshipsByName[key]!
                guard Set(ids).count == ids.count, relationship.isToMany || ids.count <= 1 else { throw LocaliserError.invalidBackup("A relationship has an invalid number of records.") }
                for id in ids {
                    guard let related = records[id], related.entity == relationship.destinationEntity?.name,
                          let inverse = relationship.inverseRelationship?.name, related.relationships[inverse]?.contains(record.id) == true else { throw LocaliserError.invalidBackup("A relationship is missing or inconsistent.") }
                }
            }
            if record.entity == "TripRecord", record.string("stateRaw") == TripState.finished.rawValue {
                for id in record.relationships["entries"] ?? [] {
                    let entry = records[id]!
                    guard (entry.integer("packedCount") ?? 0) == 0 || ![HomeResolution.pending.rawValue, HomeResolution.unresolved.rawValue].contains(entry.string("resolutionRaw") ?? "") else { throw LocaliserError.invalidBackup("A finished trip has unresolved items.") }
                }
            }
        }
        var resolved = Set<UUID>()
        for place in file.records where place.entity == "Place" {
            var path = Set<UUID>(); var next: UUID? = place.id
            while let id = next, !resolved.contains(id) {
                guard path.insert(id).inserted else { throw LocaliserError.invalidBackup("The places contain a cycle.") }
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
        let heading = ["id", "name", "place", "notes", "aliases", "archived", "confirmed dates"].map(escaped).joined(separator: ",")
        return ([heading] + items.map { item in
            [item.id.uuidString, item.name, item.place?.path ?? "", item.notes, item.aliases, item.archived ? "true" : "false", item.deadlines.sorted { $0.dayString < $1.dayString }.map { "\($0.kindRaw):\($0.dayString)" }.joined(separator: "; ")].map(escaped).joined(separator: ",")
        }).joined(separator: "\r\n") + "\r\n"
    }

    func resetLibrary() throws {
        guard !syncEnabled else { throw LocaliserError.invalidBackup("Turn off private sync and restart before erasing the local library. Cloud deletion and reconnection require separate verification.") }
        guard !hasUsedSync else { throw LocaliserError.invalidBackup("This store has previously used private sync. Erasing and reconnecting could affect the cloud library, so this operation is unavailable until that procedure is verified.") }
        for entity in container.managedObjectModel.entities {
            if let name = entity.name { for object in try context.fetch(NSFetchRequest<NSManagedObject>(entityName: name)) { context.delete(object) } }
        }
        try save()
        if isUserLibrary { UserDefaults.standard.removeObject(forKey: "restoredLocalLibrary") }
    }
}
