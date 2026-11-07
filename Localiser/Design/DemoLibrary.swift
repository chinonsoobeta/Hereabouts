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
        let photos = try store.addItem(name: "Spare passport photos", place: leftDrawer)
        let drill = try store.addItem(name: "Cordless drill", place: rack)
        let goggles = try store.addItem(name: "Ski goggles", place: drawer)
        let layers = try store.addItem(name: "Base layers", place: drawer)
        try store.addItem(name: "Running shoes", place: hall)
        try store.addItem(name: "Rain jacket", place: hall)
        let tires = try store.addItem(name: "Winter tires", place: backWall)
        // A believable week, as on the recap canvas. Most things were written down months ago and three this week.
        // The goggles moved to the garage this week and the passports were checked; a few things nobody has
        // looked at in months fill the stocktake and the recap's drifting list.
        func ago(months: Int = 0, days: Int = 0) -> Date { Calendar.current.date(byAdding: DateComponents(month: -months, day: -days), to: .now) ?? .now }
        for (item, months) in [(passport, 8), (photos, 9), (drill, 10), (goggles, 11), (tires, 12)] {
            item.createdAt = ago(months: months); item.confirmedAt = ago(months: months)
        }
        for (item, months) in [(drill, 4), (tires, 7), (photos, 5)] { try store.confirm(item, on: ago(months: months)) }
        try store.confirm(passport, on: ago(days: 2))
        try store.move(goggles, to: rack)

        let today = CalendarDay(.now)
        func day(_ offset: Int) -> CalendarDay { today.adding(days: offset) ?? today }
        try store.lend(drill, to: "Sam", askBackOn: day(5))

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
