import XCTest
@testable import Localiser

@MainActor final class ShelfPhotoTests: XCTestCase {
    func testCleaningKeepsOrderAndDropsRepeatsAndBlanks() {
        XCTAssertEqual(ShelfReading.clean([" Drill ", "drill", "", "Spirit level.", "  "]), ["Drill", "Spirit level"])
        XCTAssertEqual(ShelfReading.clean(["Blue\nsuitcase"]), ["Blue suitcase"])
        XCTAssertEqual(ShelfReading.clean((1...20).map { "Box \($0)" }).count, 12)
    }

    func testFreePlanFitting() {
        XCTAssertEqual(ShelfReading.fitting(5, unlocked: false, activeItems: 17, freeLimit: 20), 3)
        XCTAssertEqual(ShelfReading.fitting(5, unlocked: false, activeItems: 25, freeLimit: 20), 0)
        XCTAssertEqual(ShelfReading.fitting(5, unlocked: false, activeItems: 0, freeLimit: 20), 5)
        XCTAssertEqual(ShelfReading.fitting(5, unlocked: true, activeItems: 25, freeLimit: 20), 5)
    }

    func testStandInReaderAndSavingTogether() async throws {
        let store = try LocaliserStore(inMemory: true)
        let shed = try store.addPlace(name: "Shed")
        let names = ShelfReading.clean(try await StandInShelfReader(result: ["Drill", "Saw", "Drill"]).names(in: Data()))
        try store.addItems(named: names, place: shed)
        XCTAssertEqual(store.items.filter { $0.place == shed }.map(\.name).sorted(), ["Drill", "Saw"])
    }

    func testReaderFailureIsThrown() async {
        do {
            _ = try await StandInShelfReader(failure: ScanError.unreadable).names(in: Data())
            XCTFail("Expected a failure")
        } catch {}
    }
}
