import XCTest
@testable import Localiser

@MainActor
final class PutAwayTests: XCTestCase {
    func testNameIdeasComeFromLabelTextNotDatesOrCodes() {
        let text = "BOSCH\nCordless drill\n18V 2.0Ah\nBest before 12/03/2027\n12345678\ncordless DRILL\nOK"
        XCTAssertEqual(NameSuggestions.from(text), ["Bosch", "Cordless drill"])
        XCTAssertTrue(NameSuggestions.from("").isEmpty)
        XCTAssertEqual(NameSuggestions.from((1...9).map { "Label number \($0) word" }.joined(separator: "\n")).count, 4)
    }

    func testRecentPlacesComeNewestFirst() throws {
        let store = try LocaliserStore(inMemory: true)
        let hall = try store.addPlace(name: "Hall"), shed = try store.addPlace(name: "Shed"), loft = try store.addPlace(name: "Loft")
        let old = try store.addItem(name: "Old", place: loft)
        old.createdAt = .distantPast
        let drill = try store.addItem(name: "Drill", place: hall)
        drill.createdAt = Date(timeIntervalSinceNow: -60)
        try store.move(drill, to: shed)
        XCTAssertEqual(store.recentPlaces(), [shed, hall, loft])
        XCTAssertEqual(store.recentPlaces(limit: 1), [shed])
    }

    func testPutAwayIntentOpensTheCaptureScreen() async throws {
        XCTAssertTrue(PutAwayIntent.openAppWhenRun)
        _ = try await PutAwayIntent().perform()
        XCTAssertEqual(QuickActions.shared.link, .putAway)
        QuickActions.shared.link = nil
    }
}
