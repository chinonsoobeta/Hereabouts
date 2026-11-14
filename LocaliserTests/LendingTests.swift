import XCTest
@testable import Localiser

@MainActor
final class LendingTests: XCTestCase {
    func testLendingAndGettingItBack() throws {
        let store = try LocaliserStore(inMemory: true)
        let shed = try store.addPlace(name: "Shed")
        let drill = try store.addItem(name: "Drill", place: shed)
        let today = CalendarDay(.now)
        let askOn = try XCTUnwrap(today.adding(days: 14))
        let deadline = try XCTUnwrap(try store.lend(drill, to: " Sam ", askBackOn: askOn))
        XCTAssertEqual(drill.lentTo, "Sam")
        XCTAssertEqual(drill.place, shed, "Its home stays")
        XCTAssertEqual(store.lentItems.map(\.id), [drill.id])
        XCTAssertEqual(drill.movements.first { $0.kind == .lent }?.summary, "Lent to Sam")
        XCTAssertEqual(deadline.kind, .askBack)
        XCTAssertTrue(deadline.active)
        XCTAssertNotNil(deadline.reminderInput)
        XCTAssertTrue(drill.lentLine?.hasPrefix("With Sam · since ") == true)
        XCTAssertTrue(FindThingIntent.answer(for: drill).hasPrefix("You lent your Drill to Sam on "))
        XCTAssertEqual(ItemSearch.results(query: "sam", entries: store.searchIndex, archived: false).map(\.id), [drill.id])

        try store.askAgainNextWeek(deadline)
        XCTAssertEqual(deadline.day, askOn.adding(days: 7))

        try store.gotBack(drill)
        XCTAssertFalse(drill.isLent)
        XCTAssertFalse(deadline.active)
        XCTAssertNil(deadline.reminderInput, "No reminder once it's back")
        XCTAssertEqual(drill.movements.first { $0.kind == .back }?.summary, "Back from Sam")
        XCTAssertTrue(store.lentItems.isEmpty)
    }

    /// Beta feedback (13 Nov): asked where a lent thing is, Siri says who has it, since when, and that it isn't back.
    func testSiriSaysALentThingIsWithTheBorrower() throws {
        let store = try LocaliserStore(inMemory: true)
        let shed = try store.addPlace(name: "Shed")
        let drill = try store.addItem(name: "Cordless drill", place: shed)
        let lentOn = try XCTUnwrap(Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 12, hour: 18)))
        try store.lend(drill, to: "Sam", askBackOn: nil, on: lentOn)
        let day = lentOn.formatted(.dateTime.day().month(.wide))
        XCTAssertEqual(FindThingIntent.answer(for: drill), "You lent your Cordless drill to Sam on \(day) and haven't received it back yet.")
        XCTAssertFalse(FindThingIntent.answer(for: drill).contains("Shed"), "Not where it usually lives: it's with Sam")

        drill.lentAt = nil
        XCTAssertEqual(FindThingIntent.answer(for: drill), "You lent your Cordless drill to Sam and haven't received it back yet.", "No lend date saved")

        drill.isPrivate = true
        XCTAssertEqual(FindThingIntent.answer(for: drill), "That one's private. Open Hereabouts to see it.", "A private thing never says who has it")

        drill.isPrivate = false
        try store.gotBack(drill)
        XCTAssertEqual(FindThingIntent.answer(for: drill), "Cordless drill is in Shed.", "Back home, Siri gives its place again")
    }

    func testSettingRemindingAndClearingAnAskBackDate() throws {
        let store = try LocaliserStore(inMemory: true)
        let drill = try store.addItem(name: "Drill")
        let today = CalendarDay(.now)
        let askOn = try XCTUnwrap(today.adding(days: 3))
        let deadline = try XCTUnwrap(store.lend(drill, to: "Sam", askBackOn: askOn, hour: 10))
        XCTAssertEqual(drill.openAskBack, deadline)
        var queued = ReminderPlan.candidates(store.deadlines.compactMap(\.reminderInput))
        XCTAssertEqual(queued.count, 1, "One reminder, on the day")
        XCTAssertEqual(queued.first?.deadlineID, deadline.id)
        XCTAssertEqual(queued.first.map { CalendarDay($0.fireDate) }, askOn)
        XCTAssertEqual(queued.first.map { Calendar.current.component(.hour, from: $0.fireDate) }, 10)
        // Lending again moves the same date rather than adding another.
        try store.lend(drill, to: "Sam", askBackOn: XCTUnwrap(today.adding(days: 5)))
        XCTAssertEqual(store.deadlines.count, 1)
        XCTAssertEqual(store.deadlines.first?.day, today.adding(days: 5))
        // An overdue ask-back stays open until the thing comes back.
        deadline.dayString = try XCTUnwrap(today.adding(days: -2)).stored
        XCTAssertTrue(deadline.active)
        try store.gotBack(drill)
        XCTAssertNil(drill.openAskBack)
        queued = ReminderPlan.candidates(store.deadlines.compactMap(\.reminderInput))
        XCTAssertTrue(queued.isEmpty, "Cleared once it's back")
        try store.deleteDeadline(deadline)
        XCTAssertTrue(store.deadlines.isEmpty)
    }

    func testAskBackReminderWording() throws {
        let store = try LocaliserStore(inMemory: true)
        let drill = try store.addItem(name: "Drill")
        let ring = try store.addItem(name: "Ring", isPrivate: true)
        let day = try XCTUnwrap(CalendarDay(.now).adding(days: 3))
        let named = try XCTUnwrap(try store.lend(drill, to: "Sam", askBackOn: day)?.reminderInput)
        let hidden = try XCTUnwrap(try store.lend(ring, to: "Alex", askBackOn: day)?.reminderInput)
        let reminders = ReminderPlan.candidates([named, hidden])
        let drillText = try XCTUnwrap(reminders.first { $0.deadlineID == named.id }).content(showingNames: true)
        XCTAssertEqual(drillText.body, "Ask Sam for Drill back.")
        XCTAssertEqual(drillText.title, "Lent out")
        XCTAssertEqual(try XCTUnwrap(reminders.first { $0.deadlineID == named.id }).content(showingNames: false).body, "Ask for something back.")
        XCTAssertEqual(try XCTUnwrap(reminders.first { $0.deadlineID == hidden.id }).content(showingNames: true).body, "Ask for something back.")
    }

    func testLendingSurvivesABackup() throws {
        let source = try LocaliserStore(inMemory: true)
        let drill = try source.addItem(name: "Drill")
        try source.lend(drill, to: "Sam", askBackOn: CalendarDay(.now).adding(days: 5))
        let target = try LocaliserStore(inMemory: true)
        try target.restore(try LibraryBackup.decoded(source.backup().encoded()))
        let restored = try XCTUnwrap(target.items.first)
        XCTAssertEqual(restored.lentTo, "Sam")
        XCTAssertEqual(restored.deadlines.first?.kind, .askBack)
        XCTAssertTrue(restored.deadlines.first?.active == true)
        XCTAssertEqual(restored.movements.first?.kind, .lent)
    }
}
