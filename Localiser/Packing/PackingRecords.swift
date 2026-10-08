import CoreData

enum PackingCondition: String, CaseIterable, Identifiable, Sendable {
    case always, flying, international, work
    var id: String { rawValue }
    var title: String { switch self { case .always: "Every trip"; case .flying: "Flying"; case .international: "International"; case .work: "Work" } }
}

enum TripState: String { case packing, away, comingHome, finished, canceled }
enum HomeResolution: String { case pending, putBack, newPlace, unresolved, noLongerHere }

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
    func quantity(unit: Int, perNight: Bool, condition: PackingCondition) -> Int {
        let included: Bool = switch condition { case .always: true; case .flying: flying; case .international: international; case .work: work }
        return included ? max(0, unit) * (perNight ? nights : 1) : 0
    }
}

@objc(Kit) final class Kit: NSManagedObject, Identifiable {
    @NSManaged var id: UUID
    @NSManaged var name: String
    @NSManaged var entries: Set<KitEntry>
    @NSManaged var tasks: Set<KitTask>
}

@objc(KitEntry) final class KitEntry: NSManagedObject, Identifiable {
    @NSManaged var id: UUID
    @NSManaged var name: String
    @NSManaged var unitQuantity: Int64
    @NSManaged var perNight: Bool
    @NSManaged var conditionRaw: String
    @NSManaged var kit: Kit?
    @NSManaged var item: Belonging?
    var title: String { item?.name ?? name }
    var condition: PackingCondition { PackingCondition(rawValue: conditionRaw) ?? .always }
}

@objc(KitTask) final class KitTask: NSManagedObject, Identifiable {
    @NSManaged var id: UUID
    @NSManaged var title: String
    @NSManaged var kit: Kit?
}

@objc(TripRecord) final class TripRecord: NSManagedObject, Identifiable {
    @NSManaged var id: UUID
    @NSManaged var name: String
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
    @NSManaged var id: UUID
    @NSManaged var name: String
    @NSManaged var unitQuantity: Int64
    @NSManaged var perNight: Bool
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
        return details?.quantity(unit: Int(unitQuantity), perNight: perNight, condition: condition) ?? 0
    }
    var allocatesItem: Bool {
        guard let trip, trip.state != .canceled, trip.state != .finished else { return false }
        return packedCount > 0 && (resolution == .pending || resolution == .unresolved)
    }
}

@objc(TripTask) final class TripTask: NSManagedObject, Identifiable {
    @NSManaged var id: UUID
    @NSManaged var title: String
    @NSManaged var checked: Bool
    @NSManaged var trip: TripRecord?
}
