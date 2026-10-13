import CoreData

enum PackingCondition: String, CaseIterable, Identifiable, Sendable {
    case always, flying, international, work
    var id: String { rawValue }
    var title: String { switch self { case .always: "Every trip"; case .flying: "Flying"; case .international: "International"; case .work: "Work" } }
}

/// How a packing row's quantity scales with trip length.
enum PackingScale: String, CaseIterable, Identifiable, Sendable {
    case once, perDay, perNight
    var id: String { rawValue }
    init(perNight: Bool, perDay: Bool) { self = perDay ? .perDay : (perNight ? .perNight : .once) }
    var title: String { switch self { case .once: "Fixed amount"; case .perDay: "Per day"; case .perNight: "Per night" } }
    var perNight: Bool { self == .perNight }
    var perDay: Bool { self == .perDay }
}

enum TripState: String {
    case packing, away, comingHome, finished, canceled
    static let titles: [TripState: String] = [.packing: "Packing", .away: "Away", .comingHome: "Coming home", .finished: "Finished", .canceled: "Called off"]
}
enum HomeResolution: String {
    case pending, putBack, newPlace, unresolved, noLongerHere
    var title: String {
        switch self {
        case .pending: "Not put away yet"
        case .putBack: "Put back"
        case .newPlace: "Moved to a new place"
        case .unresolved: "Left for later"
        case .noLongerHere: "No longer here"
        }
    }
}

struct TripDetails: Sendable {
    var name: String
    var start: CalendarDay
    var end: CalendarDay
    var flying: Bool = false
    var international: Bool = false
    var work: Bool = false
    var nights: Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        guard let startDate = start.date(calendar: calendar), let endDate = end.date(calendar: calendar) else { return 0 }
        return max(0, calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 0)
    }
    var nightsLabel: String { nights == 0 ? "Day trip" : nights == 1 ? "1 night" : "\(nights) nights" }
    /// Days away, counting both the departure and the return day.
    var days: Int { nights + 1 }
    func quantity(unit: Int, perNight: Bool, perDay: Bool = false, condition: PackingCondition) -> Int {
        let included: Bool = switch condition { case .always: true; case .flying: flying; case .international: international; case .work: work }
        let multiplier = perDay ? days : (perNight ? nights : 1)
        return included ? max(0, unit) * multiplier : 0
    }
}

@objc(Kit) final class Kit: NSManagedObject, Identifiable {
    /// Read defensively: a view can still hold an object for one frame after it is deleted.
    var id: UUID { get { (value(forKey: "id") as? UUID) ?? LocaliserModel.missingID } set { setValue(newValue, forKey: "id") } }
    @NSManaged var name: String
    @NSManaged var home: HomeRecord?
    @NSManaged var entries: Set<KitEntry>
    @NSManaged var tasks: Set<KitTask>
}

@objc(KitEntry) final class KitEntry: NSManagedObject, Identifiable {
    /// Read defensively: a view can still hold an object for one frame after it is deleted.
    var id: UUID { get { (value(forKey: "id") as? UUID) ?? LocaliserModel.missingID } set { setValue(newValue, forKey: "id") } }
    @NSManaged var name: String
    @NSManaged var unitQuantity: Int64
    @NSManaged var perNight: Bool
    @NSManaged var perDay: Bool
    @NSManaged var unlinked: Bool
    @NSManaged var conditionRaw: String
    @NSManaged var kit: Kit?
    @NSManaged var item: Belonging?
    var title: String { item?.name ?? name }
    var scale: PackingScale { PackingScale(perNight: perNight, perDay: perDay) }
    var condition: PackingCondition { PackingCondition(rawValue: conditionRaw) ?? .always }
}

@objc(KitTask) final class KitTask: NSManagedObject, Identifiable {
    /// Read defensively: a view can still hold an object for one frame after it is deleted.
    var id: UUID { get { (value(forKey: "id") as? UUID) ?? LocaliserModel.missingID } set { setValue(newValue, forKey: "id") } }
    @NSManaged var title: String
    @NSManaged var kit: Kit?
}

@objc(TripRecord) final class TripRecord: NSManagedObject, Identifiable {
    /// Read defensively: a view can still hold an object for one frame after it is deleted.
    var id: UUID { get { (value(forKey: "id") as? UUID) ?? LocaliserModel.missingID } set { setValue(newValue, forKey: "id") } }
    @NSManaged var name: String
    /// A trip packs from its own home's things.
    @NSManaged var home: HomeRecord?
    @NSManaged var startDay: String
    @NSManaged var endDay: String
    @NSManaged var flying: Bool
    @NSManaged var international: Bool
    @NSManaged var work: Bool
    @NSManaged var stateRaw: String
    @NSManaged var entries: Set<TripEntry>
    @NSManaged var tasks: Set<TripTask>
    var state: TripState? { TripState(rawValue: stateRaw) }
    var details: TripDetails? {
        guard let start = CalendarDay(stored: startDay), let end = CalendarDay(stored: endDay) else { return nil }
        return TripDetails(name: name, start: start, end: end, flying: flying, international: international, work: work)
    }
    var unresolvedEntries: [TripEntry] { entries.filter { $0.packedCount > 0 && ($0.resolution == .pending || $0.resolution == .unresolved) } }
    func overlaps(_ other: TripRecord) -> Bool { startDay <= other.endDay && other.startDay <= endDay }
}

@objc(TripEntry) final class TripEntry: NSManagedObject, Identifiable {
    /// Read defensively: a view can still hold an object for one frame after it is deleted.
    var id: UUID { get { (value(forKey: "id") as? UUID) ?? LocaliserModel.missingID } set { setValue(newValue, forKey: "id") } }
    @NSManaged var name: String
    @NSManaged var unitQuantity: Int64
    @NSManaged var perNight: Bool
    @NSManaged var perDay: Bool
    @NSManaged var unlinked: Bool
    @NSManaged var conditionRaw: String
    @NSManaged var manualQuantity: Int64
    @NSManaged var packedCount: Int64
    @NSManaged var resolutionRaw: String
    @NSManaged var trip: TripRecord?
    @NSManaged var item: Belonging?
    @NSManaged var homePlace: Place?
    var title: String { item?.name ?? name }
    var condition: PackingCondition { PackingCondition(rawValue: conditionRaw) ?? .always }
    var resolution: HomeResolution? { HomeResolution(rawValue: resolutionRaw) }
    var requiredCount: Int { required(for: trip?.details) }
    func required(for details: TripDetails?) -> Int {
        if manualQuantity >= 0 { return Int(manualQuantity) }
        return details?.quantity(unit: Int(unitQuantity), perNight: perNight, perDay: perDay, condition: condition) ?? 0
    }
    var allocatesItem: Bool {
        guard let trip, trip.state != .canceled, trip.state != .finished else { return false }
        return packedCount > 0 && (resolution == .pending || resolution == .unresolved)
    }
}

@objc(TripTask) final class TripTask: NSManagedObject, Identifiable {
    /// Read defensively: a view can still hold an object for one frame after it is deleted.
    var id: UUID { get { (value(forKey: "id") as? UUID) ?? LocaliserModel.missingID } set { setValue(newValue, forKey: "id") } }
    @NSManaged var title: String
    @NSManaged var checked: Bool
    @NSManaged var trip: TripRecord?
}
