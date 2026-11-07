import CoreData

@objc(Belonging)
final class Belonging: NSManagedObject, Identifiable {
    /// Read defensively: a view can still hold an object for one frame after it is deleted.
    var id: UUID { get { (value(forKey: "id") as? UUID) ?? LocaliserModel.missingID } set { setValue(newValue, forKey: "id") } }
    @NSManaged var name: String
    @NSManaged var notes: String
    @NSManaged var aliases: String
    @NSManaged var archived: Bool
    @NSManaged var createdAt: Date
    /// When someone last said this is where it lives: added, moved, put away or "Still there".
    @NSManaged var confirmedAt: Date?
    @NSManaged var photo: Data?
    /// Kept out of Spotlight, Siri, notifications, widgets and the calendar. Still in backups and exports.
    @NSManaged var isPrivate: Bool
    /// Set by "Not there"; cleared when it's found.
    @NSManaged var missingSince: Date?
    /// Who has it, when it's lent out. Empty when it's at home.
    @NSManaged var lentTo: String
    @NSManaged var lentAt: Date?
    @NSManaged var place: Place?
    /// The home it belongs to; follows its place, and stays put when it has none.
    @NSManaged var home: HomeRecord?
    @NSManaged var movements: Set<Movement>
    @NSManaged var deadlines: Set<Deadline>
    @NSManaged var scans: Set<ScanRecord>
    @NSManaged var tripEntries: Set<TripEntry>
    @NSManaged var kitEntries: Set<KitEntry>
    var lastConfirmed: Date { confirmedAt ?? movements.map(\.date).max() ?? createdAt }
    var isLent: Bool { !lentTo.isEmpty }
    var isMissing: Bool { missingSince != nil }
    /// The name to show outside the app: empty for a private thing, so the caller says "A saved thing".
    var publicName: String { isPrivate ? "" : name }
    var packedTrips: [TripRecord] {
        var seen = Set<UUID>()
        return tripEntries.filter(\.allocatesItem).compactMap(\.trip).filter { seen.insert($0.id).inserted }.sorted { $0.startDay < $1.startDay }
    }
}

@objc(Place)
final class Place: NSManagedObject, Identifiable {
    /// Read defensively: a view can still hold an object for one frame after it is deleted.
    var id: UUID { get { (value(forKey: "id") as? UUID) ?? LocaliserModel.missingID } set { setValue(newValue, forKey: "id") } }
    @NSManaged var name: String
    @NSManaged var parent: Place?
    @NSManaged var children: Set<Place>
    @NSManaged var items: Set<Belonging>
    /// Every place in a tree has its top place's home.
    @NSManaged var home: HomeRecord?

    /// This place and everything inside it.
    var subtree: [Place] {
        var result: [Place] = []
        var queue = [self]
        var seen = Set<UUID>()
        while let next = queue.popLast() {
            guard seen.insert(next.id).inserted else { continue }
            result.append(next)
            queue.append(contentsOf: next.children)
        }
        return result
    }

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

/// A home: the top of the notebook. Places, things, kits and trips belong to one.
@objc(HomeRecord)
final class HomeRecord: NSManagedObject, Identifiable {
    /// Read defensively: a view can still hold an object for one frame after it is deleted.
    var id: UUID { get { (value(forKey: "id") as? UUID) ?? LocaliserModel.missingID } set { setValue(newValue, forKey: "id") } }
    @NSManaged var name: String
    @NSManaged var createdAt: Date?
    @NSManaged var places: Set<Place>
    @NSManaged var items: Set<Belonging>
    @NSManaged var kits: Set<Kit>
    @NSManaged var trips: Set<TripRecord>
    var isEmpty: Bool { places.isEmpty && items.isEmpty && kits.isEmpty && trips.isEmpty }
}

@objc(Movement)
final class Movement: NSManagedObject, Identifiable {
    /// Read defensively: a view can still hold an object for one frame after it is deleted.
    var id: UUID { get { (value(forKey: "id") as? UUID) ?? LocaliserModel.missingID } set { setValue(newValue, forKey: "id") } }
    @NSManaged var date: Date
    @NSManaged var fromPath: String
    @NSManaged var toPath: String
    @NSManaged var kindRaw: String
    /// Who made the move, once a home is shared. Empty for the phone's owner.
    @NSManaged var by: String
    @NSManaged var item: Belonging?

    enum Kind: String, Sendable { case moved, found, lent, back }
    var kind: Kind { Kind(rawValue: kindRaw) ?? .moved }

    /// Moves record "Unspecified" when there was no place. The stored word stays for older backups.
    static let noPlace = "Unspecified"
    static func display(_ path: String) -> String { path.isEmpty || path == noPlace ? "No place" : path }
}

@objc(Deadline)
final class Deadline: NSManagedObject, Identifiable {
    /// Read defensively: a view can still hold an object for one frame after it is deleted.
    var id: UUID { get { (value(forKey: "id") as? UUID) ?? LocaliserModel.missingID } set { setValue(newValue, forKey: "id") } }
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
    var active: Bool {
        guard let item, !item.archived else { return false }
        return kind == .askBack && item.isLent && decision == .open
    }
    var reminderInput: ReminderInput? {
        guard let day, let kind, let decision else { return nil }
        guard active else { return nil }
        return ReminderInput(id: id, day: day, kind: kind, leadDays: Int(leadDays), hour: Int(hour), enabled: enabled, archived: item?.archived ?? true, decision: decision, itemName: item?.publicName ?? "", itemID: item?.id, person: item?.isPrivate == false ? item?.lentTo ?? "" : "")
    }
}

enum LocaliserModel {
    nonisolated static let missingID = UUID(uuid: (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0))
    @MainActor static let shared = Bundle.main.url(forResource: "Localiser", withExtension: "momd").flatMap(NSManagedObjectModel.init(contentsOf:))
}

@objc(ScanRecord)
final class ScanRecord: NSManagedObject, Identifiable {
    /// Read defensively: a view can still hold an object for one frame after it is deleted.
    var id: UUID { get { (value(forKey: "id") as? UUID) ?? LocaliserModel.missingID } set { setValue(newValue, forKey: "id") } }
    @NSManaged var createdAt: Date
    @NSManaged var counted: Bool
    @NSManaged var filename: String
    @NSManaged var mime: String
    @NSManaged var data: Data?
    @NSManaged var item: Belonging?
}
