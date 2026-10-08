import CoreData

@objc(Belonging)
final class Belonging: NSManagedObject, Identifiable {
    @NSManaged var id: UUID
    @NSManaged var name: String
    @NSManaged var notes: String
    @NSManaged var aliases: String
    @NSManaged var archived: Bool
    @NSManaged var createdAt: Date
    @NSManaged var photo: Data?
    @NSManaged var place: Place?
    @NSManaged var movements: Set<Movement>
    @NSManaged var deadlines: Set<Deadline>
    @NSManaged var scans: Set<ScanRecord>
}

@objc(Place)
final class Place: NSManagedObject, Identifiable {
    @NSManaged var id: UUID
    @NSManaged var name: String
    @NSManaged var parent: Place?
    @NSManaged var children: Set<Place>
    @NSManaged var items: Set<Belonging>

    var path: String {
        var names = [name]
        var seen: Set<UUID> = [id]
        var next = parent
        while let node = next, seen.insert(node.id).inserted {
            names.insert(node.name, at: 0)
            next = node.parent
        }
        return names.joined(separator: " › ")
    }

    func isWithin(_ ancestor: Place) -> Bool {
        var next: Place? = self
        var seen = Set<UUID>()
        while let node = next, seen.insert(node.id).inserted {
            if node.id == ancestor.id { return true }
            next = node.parent
        }
        return false
    }
}

@objc(Movement)
final class Movement: NSManagedObject, Identifiable {
    @NSManaged var id: UUID
    @NSManaged var date: Date
    @NSManaged var fromPath: String
    @NSManaged var toPath: String
    @NSManaged var item: Belonging?
}

@objc(Deadline)
final class Deadline: NSManagedObject, Identifiable {
    @NSManaged var id: UUID
    @NSManaged var dayString: String
    @NSManaged var kindRaw: String
    @NSManaged var decisionRaw: String
    @NSManaged var source: String
    @NSManaged var leadDays: Int16
    @NSManaged var hour: Int16
    @NSManaged var enabled: Bool
    @NSManaged var item: Belonging?

    var kind: DeadlineKind? { DeadlineKind(rawValue: kindRaw) }
    var decision: ReturnDecision? { ReturnDecision(rawValue: decisionRaw) }
    var day: CalendarDay? { CalendarDay(stored: dayString) }
    var active: Bool { item != nil && item?.archived == false && (kind != .returns || [.open, .returning].contains(decision)) }
    var reminderInput: ReminderInput? {
        guard let day, let kind, let decision else { return nil }
        return ReminderInput(id: id, day: day, kind: kind, leadDays: Int(leadDays), hour: Int(hour), enabled: enabled, archived: item?.archived ?? true, decision: decision)
    }
}

@MainActor enum LocaliserModel {
    static let shared = Bundle.main.url(forResource: "Localiser", withExtension: "momd").flatMap(NSManagedObjectModel.init(contentsOf:))
}

@objc(ScanRecord)
final class ScanRecord: NSManagedObject, Identifiable {
    @NSManaged var id: UUID
    @NSManaged var createdAt: Date
    @NSManaged var counted: Bool
    @NSManaged var filename: String
    @NSManaged var mime: String
    @NSManaged var data: Data?
    @NSManaged var item: Belonging?
}
