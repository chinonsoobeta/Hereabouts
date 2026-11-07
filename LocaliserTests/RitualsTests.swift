import XCTest
import CoreData
@testable import Localiser

@MainActor
final class RitualsTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/London")!
        calendar.firstWeekday = 2 // A Monday-first region must still count Sunday weeks.
        return calendar
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    func testWeeksStartOnSundayWhateverTheRegion() {
        // Wednesday 7 October 2026 belongs to the week starting Sunday 4 October.
        XCTAssertEqual(Rituals.weekStart(of: date(2026, 10, 7), calendar: calendar), date(2026, 10, 4, 0))
        XCTAssertEqual(Rituals.weekStart(of: date(2026, 10, 4, 0), calendar: calendar), date(2026, 10, 4, 0))
    }

    func testKeepingUpCountsConsecutiveWeeksAndAQuietMondayDoesNotReset() {
        let activity = [date(2026, 9, 15), date(2026, 9, 22), date(2026, 9, 30), date(2026, 10, 9)]
        // Saturday 10 October: four weeks running, this one included.
        XCTAssertEqual(Rituals.keepingUpWeeks(activity: activity, now: date(2026, 10, 10), calendar: calendar), 4)
        // Monday 12 October, nothing yet this week: still four, not zero.
        XCTAssertEqual(Rituals.keepingUpWeeks(activity: activity, now: date(2026, 10, 12), calendar: calendar), 4)
        // A whole empty week breaks the run.
        XCTAssertEqual(Rituals.keepingUpWeeks(activity: activity, now: date(2026, 10, 19), calendar: calendar), 0)
        // Future-dated activity never counts.
        XCTAssertEqual(Rituals.keepingUpWeeks(activity: [date(2026, 12, 1)], now: date(2026, 10, 10), calendar: calendar), 0)
    }

    func testKeepingUpSurvivesTheClocksChanging() {
        // UK clocks go back on Sunday 25 October 2026 and forward on Sunday 28 March 2027.
        let autumn = [date(2026, 10, 18), date(2026, 10, 25, 1), date(2026, 11, 1)]
        XCTAssertEqual(Rituals.keepingUpWeeks(activity: autumn, now: date(2026, 11, 2), calendar: calendar), 3)
        let spring = [date(2027, 3, 21), date(2027, 3, 28, 3), date(2027, 4, 4)]
        XCTAssertEqual(Rituals.keepingUpWeeks(activity: spring, now: date(2027, 4, 5), calendar: calendar), 3)
    }

    func testStocktakeAsksAboutAtMostFiveStaleThingsOldestFirst() throws {
        let store = try LocaliserStore(inMemory: true)
        let now = date(2026, 10, 10)
        var stale: [Belonging] = []
        for index in 0..<7 {
            let item = try store.addItem(name: "Old \(index)", place: nil)
            try store.confirm(item, on: calendar.date(byAdding: .month, value: -(4 + index), to: now)!)
            stale.append(item)
        }
        let fresh = try store.addItem(name: "Fresh", place: nil)
        try store.confirm(fresh, on: calendar.date(byAdding: .month, value: -2, to: now)!)
        let archived = try store.addItem(name: "Gone", place: nil)
        try store.confirm(archived, on: date(2024, 1, 1))
        try store.setArchived(archived, true)

        let asked = Rituals.stocktake(store.items, now: now, calendar: calendar)
        XCTAssertEqual(asked.map(\.name), ["Old 6", "Old 5", "Old 4", "Old 3", "Old 2"])
        XCTAssertFalse(asked.contains(fresh))
        XCTAssertFalse(asked.contains(archived))
        XCTAssertEqual(Rituals.stale(store.items, now: now, calendar: calendar).count, 7)
    }

    func testStocktakeIsOfferedOncePerMonth() throws {
        let store = try LocaliserStore(inMemory: true)
        let now = date(2026, 10, 10)
        let item = try store.addItem(name: "Drill", place: nil)
        try store.confirm(item, on: date(2026, 1, 1))
        XCTAssertTrue(Rituals.stocktakeDue(store.items, doneMonth: nil, now: now, calendar: calendar))
        XCTAssertFalse(Rituals.stocktakeDue(store.items, doneMonth: Rituals.monthKey(now, calendar: calendar), now: now, calendar: calendar))
        XCTAssertTrue(Rituals.stocktakeDue(store.items, doneMonth: "2026-09", now: now, calendar: calendar))
        try store.confirm(item, on: now)
        XCTAssertFalse(Rituals.stocktakeDue(store.items, doneMonth: nil, now: now, calendar: calendar))
    }

    func testStocktakeNudgeLandsOnTheFirstSaturday() {
        XCTAssertEqual(Rituals.nextStocktakeDate(after: date(2026, 10, 1), calendar: calendar), date(2026, 10, 3, 10))
        XCTAssertEqual(Rituals.nextStocktakeDate(after: date(2026, 10, 10), calendar: calendar), date(2026, 11, 7, 10))
        XCTAssertEqual(Rituals.nextStocktakeDate(after: date(2026, 12, 20), calendar: calendar), date(2027, 1, 2, 10))
    }

    func testMovingAndConfirmingRecordWhenAThingWasLastSeen() throws {
        let store = try LocaliserStore(inMemory: true)
        let shelf = try store.addPlace(name: "Shelf"), box = try store.addPlace(name: "Box")
        let item = try store.addItem(name: "Torch", place: shelf)
        XCTAssertNotNil(item.confirmedAt)
        try store.confirm(item, on: date(2025, 1, 1))
        XCTAssertEqual(item.lastConfirmed, date(2025, 1, 1))
        try store.move(item, to: box)
        XCTAssertGreaterThan(item.lastConfirmed, date(2026, 1, 1))
        try store.confirm(item, on: date(2025, 6, 1))
        try store.editItem(item, name: "Torch", place: shelf, notes: "", aliases: "", photo: nil)
        XCTAssertGreaterThan(item.lastConfirmed, date(2026, 1, 1), "Changing the place in the editor counts as seeing it")
    }

    func testRecapCoversTheLastWeekAndTheNext() throws {
        let store = try LocaliserStore(inMemory: true)
        let now = Date.now
        let new = try store.addItem(name: "New lamp", place: nil)
        let old = try store.addItem(name: "Old chair", place: nil)
        old.createdAt = calendar.date(byAdding: .month, value: -6, to: now)!
        try store.confirm(old, on: calendar.date(byAdding: .day, value: -2, to: now)!)
        let drifting = try store.addItem(name: "Tent", place: nil)
        drifting.createdAt = calendar.date(byAdding: .year, value: -1, to: now)!
        try store.confirm(drifting, on: drifting.createdAt)
        let today = CalendarDay(now, calendar: calendar)
        _ = try store.setDeadline(item: new, kind: .returns, day: today.adding(days: 3, calendar: calendar)!, source: "", leadDays: 3, hour: 9, enabled: true, confirmed: true)
        _ = try store.setDeadline(item: old, kind: .warranty, day: today.adding(days: 40, calendar: calendar)!, source: "", leadDays: 30, hour: 9, enabled: true, confirmed: true)

        let recap = Rituals.recap(items: store.items, deadlines: store.deadlines, now: now, calendar: calendar)
        XCTAssertEqual(recap.added, ["New lamp"])
        XCTAssertEqual(recap.confirmed, 1)
        XCTAssertEqual(recap.due.map { $0.item?.name }, ["New lamp"])
        XCTAssertEqual(recap.drifting.map(\.name), ["Tent"])
        XCTAssertEqual(recap.stocktakeCount, 1)
        XCTAssertGreaterThanOrEqual(recap.keepingUp, 1)
    }

    func testTripEveReminderOnlyForUnpackedTripsStillAhead() throws {
        let store = try LocaliserStore(inMemory: true)
        let today = CalendarDay(.now)
        let item = try store.addItem(name: "Goggles", place: nil)
        let kit = try store.addKit(name: "Ski")
        _ = try store.setKitEntry(kit: kit, name: "", item: item, unit: 1, perNight: false, condition: .always)
        let ahead = try store.addTrip(TripDetails(name: "Alps", start: today.adding(days: 5)!, end: today.adding(days: 9)!), kit: kit)
        let packed = try store.addTrip(TripDetails(name: "Packed", start: today.adding(days: 5)!, end: today.adding(days: 9)!), kit: kit)
        if let entry = packed.entries.first { try store.pack(entry, count: entry.requiredCount) }
        _ = try store.addTrip(TripDetails(name: "Today", start: today, end: today.adding(days: 2)!), kit: kit)
        XCTAssertEqual(Rituals.tripsNeedingEveReminder(store.trips).map(\.id), [ahead.id])
    }

    func testTripEveRemindersGoToTheNearestTrips() throws {
        let store = try LocaliserStore(inMemory: true)
        let today = CalendarDay(.now)
        let item = try store.addItem(name: "Goggles", place: nil)
        let kit = try store.addKit(name: "Ski")
        _ = try store.setKitEntry(kit: kit, name: "", item: item, unit: 1, perNight: false, condition: .always)
        for offset in (2...7).reversed() {
            _ = try store.addTrip(TripDetails(name: "In \(offset)", start: today.adding(days: offset)!, end: today.adding(days: offset + 2)!), kit: kit)
        }
        let reminded = Rituals.tripsNeedingEveReminder(store.trips).prefix(5).map(\.name)
        XCTAssertEqual(reminded, ["In 2", "In 3", "In 4", "In 5", "In 6"])
    }

    func testV5LibrariesMigrateAndBackfillLastConfirmed() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("v5.sqlite")
        let modelURL = try XCTUnwrap(Bundle.main.url(forResource: "LocaliserV5", withExtension: "mom", subdirectory: "Localiser.momd"))
        let model = try XCTUnwrap(NSManagedObjectModel(contentsOf: modelURL))
        let old = NSPersistentContainer(name: "Localiser", managedObjectModel: model)
        let description = NSPersistentStoreDescription(url: url)
        description.shouldAddStoreAsynchronously = false
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        old.persistentStoreDescriptions = [description]
        var loadError: Error?
        old.loadPersistentStores { _, error in loadError = error }
        if let loadError { throw loadError }
        let created = date(2025, 3, 1), moved = date(2025, 8, 1)
        let quiet = NSEntityDescription.insertNewObject(forEntityName: "Belonging", into: old.viewContext)
        quiet.setValue(UUID(), forKey: "id"); quiet.setValue("Quiet", forKey: "name"); quiet.setValue(created, forKey: "createdAt")
        let busy = NSEntityDescription.insertNewObject(forEntityName: "Belonging", into: old.viewContext)
        busy.setValue(UUID(), forKey: "id"); busy.setValue("Busy", forKey: "name"); busy.setValue(created, forKey: "createdAt")
        let movement = NSEntityDescription.insertNewObject(forEntityName: "Movement", into: old.viewContext)
        movement.setValue(UUID(), forKey: "id"); movement.setValue(moved, forKey: "date"); movement.setValue(busy, forKey: "item")
        try old.viewContext.save()
        old.viewContext.reset()
        for persistentStore in old.persistentStoreCoordinator.persistentStores { try old.persistentStoreCoordinator.remove(persistentStore) }

        let migrated = try LocaliserStore(url: url)
        defer { for persistentStore in migrated.container.persistentStoreCoordinator.persistentStores { try? migrated.container.persistentStoreCoordinator.remove(persistentStore) } }
        XCTAssertEqual(migrated.items.first { $0.name == "Quiet" }?.confirmedAt, created)
        XCTAssertEqual(migrated.items.first { $0.name == "Busy" }?.confirmedAt, moved)
    }

    func testRecapCountsEachThingOnce() throws {
        let store = try LocaliserStore(inMemory: true)
        let hall = try store.addPlace(name: "Hall"), shed = try store.addPlace(name: "Shed")
        let keys = try store.addItem(name: "Keys", place: hall)
        keys.createdAt = calendar.date(byAdding: .month, value: -2, to: .now)!
        try store.move(keys, to: shed)
        try store.move(keys, to: hall)
        let recap = Rituals.recap(items: store.items, deadlines: [], calendar: calendar)
        XCTAssertEqual(recap.moved, 1)
        XCTAssertEqual(recap.confirmed, 0)
    }

    func testRecapNamesSayHowManyMore() {
        XCTAssertFalse(RecapView.names(["Kettle", "Torch", "Passport", "Drill"]).contains("more"))
        let six = RecapView.names(["Kettle", "Torch", "Passport", "Drill", "Goggles", "Socks"])
        XCTAssertTrue(six.hasPrefix("Kettle") && six.hasSuffix("3 more"), six)
        XCTAssertFalse(six.contains("Drill"), six)
    }

    func testRecapIsOfferedFromSundayEvening() {
        // Sunday 11 October 2026: last week's recap until 18:00, then this week's, through Saturday.
        XCTAssertEqual(Rituals.recapWeekKey(now: date(2026, 10, 11, 17), calendar: calendar), "2026-10-04")
        XCTAssertEqual(Rituals.recapWeekKey(now: date(2026, 10, 11, 18), calendar: calendar), "2026-10-11")
        XCTAssertEqual(Rituals.recapWeekKey(now: date(2026, 10, 17, 23), calendar: calendar), "2026-10-11")
        // Sunday 25 October 2026, when the clocks go back: still last week's at 17:30, this week's from 18:00.
        let clocksBack = calendar.date(from: DateComponents(year: 2026, month: 10, day: 25, hour: 17, minute: 30))!
        XCTAssertEqual(Rituals.recapWeekKey(now: clocksBack, calendar: calendar), "2026-10-18")
        XCTAssertEqual(Rituals.recapWeekKey(now: date(2026, 10, 25, 18), calendar: calendar), "2026-10-25")
    }

    func testHomeNameReadsNaturallyMidSentence() {
        XCTAssertEqual("The flat".lowercasedFirstArticle, "the flat")
        XCTAssertEqual("Mum's house".lowercasedFirstArticle, "Mum's house")
        XCTAssertEqual("Theo's".lowercasedFirstArticle, "Theo's")
    }
}
