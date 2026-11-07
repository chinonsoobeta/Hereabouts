import XCTest
@testable import Localiser

final class LentOutRowTests: XCTestCase {
    private let locale = Locale(identifier: "en_US")
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
    private func date(_ month: Int, _ day: Int) -> Date { calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: 12))! }
    private func record(_ name: String, to person: String = "Sam", since: Date, askBack: String? = nil, isPrivate: Bool = false) -> LentOutRecord {
        LentOutRecord(name: name, isPrivate: isPrivate, person: person, since: since, askBackDay: askBack)
    }

    func testRowsAreNewestFirstAndStopAtTheLimit() {
        let records = [record("Ladder", since: date(9, 1)), record("Drill", since: date(10, 3)), record("Tent", since: date(8, 20)),
                       record("Book", since: date(10, 20)), record("Pump", since: date(7, 4))]
        let rows = LentOutRows.rows(records, limit: 4, locale: locale, calendar: calendar)
        XCTAssertEqual(rows.map(\.title), ["Book", "Drill", "Ladder", "Tent"])
        XCTAssertEqual(LentOutRows.rows(records, locale: locale, calendar: calendar).count, 4, "Four rows is what fits")
    }

    func testPrivateThingsShowAsAPrivateThing() {
        let rows = LentOutRows.rows([record("Diary", to: "Mum", since: date(10, 3), isPrivate: true)], locale: locale, calendar: calendar)
        XCTAssertEqual(rows.first?.title, "A private thing")
        XCTAssertEqual(rows.first?.person, "Mum", "Who has it still shows")
        XCTAssertFalse(rows.flatMap { [$0.title, $0.person, $0.sinceText, $0.askBackText ?? ""] }.joined().contains("Diary"))
    }

    func testSinceAndAskBackDatesAreWrittenForThePhone() {
        let row = LentOutRows.rows([record("Drill", since: date(10, 3), askBack: "2026-11-12")], locale: locale, calendar: calendar)[0]
        XCTAssertEqual(row.sinceText, "Since Oct 3")
        XCTAssertEqual(row.askBackText, "Ask for it back Nov 12")
        let none = LentOutRows.rows([record("Drill", since: date(10, 3))], locale: locale, calendar: calendar)[0]
        XCTAssertNil(none.askBackText)
        let bad = LentOutRows.rows([record("Drill", since: date(10, 3), askBack: "not a day")], locale: locale, calendar: calendar)[0]
        XCTAssertNil(bad.askBackText, "A date that doesn't read is left out")
    }

    func testNothingLentOutGivesNoRows() {
        XCTAssertTrue(LentOutRows.rows([], locale: locale, calendar: calendar).isEmpty)
    }
}

@MainActor final class LentOutReaderTests: XCTestCase {
    private nonisolated(unsafe) var folder: URL!
    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("LentOut-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: folder) }

    func testReadsWhoHasWhatFromTheNotebookFile() throws {
        let url = folder.appendingPathComponent("Localiser.sqlite")
        let day = CalendarDay(.now).adding(days: 10)!
        do {
            let store = try LocaliserStore(url: url)
            let drill = try store.addItem(name: "Drill")
            try store.lend(drill, to: "Sam", askBackOn: day)
            let diary = try store.addItem(name: "Diary", isPrivate: true)
            try store.lend(diary, to: "Mum", askBackOn: nil, on: Date(timeIntervalSinceNow: -86_400))
            let back = try store.addItem(name: "Tent")
            try store.lend(back, to: "Ana", askBackOn: CalendarDay(.now))
            try store.gotBack(back)
            _ = try store.addItem(name: "Torch")
            let archived = try store.addItem(name: "Ladder")
            try store.lend(archived, to: "Jo", askBackOn: nil)
            archived.archived = true
            try store.save()
        }
        let records = LentOutReader.records(at: url)
        XCTAssertEqual(records.map(\.person), ["Sam", "Mum"], "Newest first; returned, archived and at-home things are left out")
        XCTAssertEqual(records.first?.name, "Drill")
        XCTAssertEqual(records.first?.askBackDay, day.stored)
        XCTAssertNil(records.last?.askBackDay)
        XCTAssertEqual(records.last?.isPrivate, true)
        XCTAssertEqual(records.last?.name, "", "A private thing's name is never read out of the file")
    }

    func testAMissingOrUnreadableNotebookGivesNoRows() throws {
        XCTAssertTrue(LentOutReader.records(at: folder.appendingPathComponent("None.sqlite")).isEmpty)
        let junk = folder.appendingPathComponent("Junk.sqlite")
        try Data("not a database".utf8).write(to: junk)
        XCTAssertTrue(LentOutReader.records(at: junk).isEmpty)
    }

    func testReadingNeverChangesTheNotebook() throws {
        let url = folder.appendingPathComponent("Localiser.sqlite")
        do { let store = try LocaliserStore(url: url); try store.lend(try store.addItem(name: "Drill"), to: "Sam", askBackOn: nil) }
        let before = try Data(contentsOf: url)
        _ = LentOutReader.records(at: url)
        XCTAssertEqual(try Data(contentsOf: url), before)
    }
}
