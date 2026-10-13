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
        XCTAssertEqual(deadline.group, .later)
        XCTAssertTrue(drill.lentLine?.hasPrefix("With Sam · since ") == true)
        XCTAssertTrue(FindThingIntent.answer(for: drill).hasPrefix("Drill is with Sam, since "))
        XCTAssertEqual(ItemSearch.results(query: "sam", entries: store.searchIndex, archived: false).map(\.id), [drill.id])

        try store.askAgainNextWeek(deadline)
        XCTAssertEqual(deadline.day, askOn.adding(days: 7))

        try store.gotBack(drill)
        XCTAssertFalse(drill.isLent)
        XCTAssertFalse(deadline.active)
        XCTAssertEqual(deadline.group, .done)
        XCTAssertNil(deadline.reminderInput, "No reminder once it's back")
        XCTAssertEqual(drill.movements.first { $0.kind == .back }?.summary, "Back from Sam")
        XCTAssertTrue(store.lentItems.isEmpty)
    }

    func testAnOverdueAskBackWaitsInMissed() throws {
        let today = CalendarDay(.now)
        XCTAssertEqual(DueGroup.of(kind: .askBack, active: true, day: today.adding(days: -2), today: today), .missed)
        XCTAssertEqual(DueGroup.of(kind: .warranty, active: true, day: today.adding(days: -2), today: today), .done)
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
