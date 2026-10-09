#if DEBUG
import Foundation

/// Debug-only sample library matching the design canvas, for screenshots and design review.
/// Launch with `--demo-library` together with `--ui-test-library <UUID>` so it never touches a real library.
enum DemoLibrary {
    @MainActor static func seed(_ store: LocaliserStore) throws {
        guard store.items.isEmpty, store.places.isEmpty else { return }
        let hall = try store.addPlace(name: "Hall closet")
        let topShelf = try store.addPlace(name: "Top shelf", parent: hall)
        let garage = try store.addPlace(name: "Garage")
        let backWall = try store.addPlace(name: "Back wall", parent: garage)
        let rack = try store.addPlace(name: "Rack 2", parent: backWall)
        let bedroom = try store.addPlace(name: "Bedroom")
        let drawer = try store.addPlace(name: "Drawer 3", parent: bedroom)
        let office = try store.addPlace(name: "Office")
        let leftDrawer = try store.addPlace(name: "Left drawer", parent: office)

        let passport = try store.addItem(name: "Passports (family)", place: topShelf, aliases: "passport")
        _ = try store.addItem(name: "Spare passport photos", place: leftDrawer)
        _ = try store.addItem(name: "Cordless drill", place: rack)
        let goggles = try store.addItem(name: "Ski goggles", place: rack)
        let layers = try store.addItem(name: "Base layers", place: drawer)
        let shoes = try store.addItem(name: "Running shoes", place: hall)
        let jacket = try store.addItem(name: "Rain jacket", place: hall)
        _ = try store.addItem(name: "Winter tires", place: backWall)

        let today = CalendarDay(.now)
        func day(_ offset: Int) -> CalendarDay { today.adding(days: offset) ?? today }
        _ = try store.setDeadline(item: shoes, kind: .returns, day: day(2), source: "Sport Shop", leadDays: 3, hour: 9, enabled: true, confirmed: true)
        _ = try store.setDeadline(item: jacket, kind: .returns, day: day(5), source: "", leadDays: 3, hour: 9, enabled: true, confirmed: true)
        _ = try store.setDeadline(item: passport, kind: .expiry, day: day(190), source: "", leadDays: 180, hour: 9, enabled: true, confirmed: true)

        let kit = try store.addKit(name: "Ski trip")
        _ = try store.setKitEntry(kit: kit, name: "", item: goggles, unit: 1, perNight: false, condition: .always)
        _ = try store.setKitEntry(kit: kit, name: "", item: layers, unit: 1, perNight: false, condition: .always)
        _ = try store.setKitEntry(kit: kit, name: "Wool socks", item: nil, unit: 1, perNight: false, perDay: true, condition: .always)
        _ = try store.setKitEntry(kit: kit, name: "Sunscreen", item: nil, unit: 1, perNight: false, condition: .always)
        let trip = try store.addTrip(TripDetails(name: "Ski trip", start: day(10), end: day(14)), kit: kit)
        if let entry = trip.entries.first(where: { $0.item?.id == goggles.id }) { try store.pack(entry, count: entry.requiredCount) }
    }
}
#endif
