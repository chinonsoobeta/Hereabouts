import XCTest
@testable import Localiser

@MainActor
final class FindingTests: XCTestCase {
    func testFindingRecordsWhereItTurnedUpAndClearsMissing() throws {
        let store = try LocaliserStore(inMemory: true)
        let hall = try store.addPlace(name: "Hall"), coat = try store.addPlace(name: "Coat pocket")
        let keys = try store.addItem(name: "Keys", place: hall)
        let lost = Date(timeIntervalSinceNow: -86_400 * 3)
        try store.markMissing(keys, on: lost)
        XCTAssertTrue(keys.isMissing)
        XCTAssertEqual(store.missingItems.map(\.id), [keys.id])

        let found = Date(timeIntervalSinceNow: -60)
        try store.found(keys, at: coat, on: found)
        XCTAssertFalse(keys.isMissing)
        XCTAssertTrue(store.missingItems.isEmpty)
        XCTAssertEqual(keys.place, coat)
        XCTAssertEqual(keys.confirmedAt, found)
        let movement = try XCTUnwrap(keys.movements.first { $0.kind == .found })
        XCTAssertEqual(movement.fromPath, "Hall"); XCTAssertEqual(movement.toPath, "Coat pocket")
        XCTAssertEqual(movement.summary, "Found in Coat pocket")
        XCTAssertEqual(Movement.foundSentence(coat), "Noted. Next time, look in Coat pocket.")

        try store.found(keys, at: coat)
        XCTAssertEqual(keys.movements.filter { $0.kind == .found }.count, 2, "Finding it where it should be is still a find")
        XCTAssertEqual(keys.movements.sorted { $0.date > $1.date }.first?.summary, "Found where it should be")
    }

    func testSuggestionsStartWhereItShouldBeThenWhereItHasBeen() throws {
        let store = try LocaliserStore(inMemory: true)
        let hall = try store.addPlace(name: "Hall"), car = try store.addPlace(name: "Car"), bag = try store.addPlace(name: "Bag")
        let desk = try store.addPlace(name: "Desk"), shed = try store.addPlace(name: "Shed")
        let keys = try store.addItem(name: "Keys", place: car)
        try store.move(keys, to: bag)
        try store.move(keys, to: hall)
        let drill = try store.addItem(name: "Drill", place: desk)
        try store.move(drill, to: shed)
        let suggestions = store.foundSuggestions(for: keys)
        XCTAssertEqual(suggestions.first, hall)
        XCTAssertEqual(Array(suggestions.prefix(3)), [hall, bag, car])
        XCTAssertTrue(suggestions.contains(shed), "Then places used lately")
        XCTAssertEqual(Set(suggestions.map(\.id)).count, suggestions.count)
    }

    func testRecapCountsFindsAndStocktakeSkipsMissingThings() throws {
        let store = try LocaliserStore(inMemory: true)
        let hall = try store.addPlace(name: "Hall")
        let old = Calendar.current.date(byAdding: .month, value: -6, to: .now)!
        let torch = try store.addItem(name: "Torch", place: hall)
        let gloves = try store.addItem(name: "Gloves", place: hall)
        for item in [torch, gloves] { item.createdAt = old; item.confirmedAt = old }
        try store.save()
        try store.markMissing(gloves)
        XCTAssertEqual(Rituals.stale(store.items).map(\.id), [torch.id], "A missing thing isn't asked about")
        try store.found(torch, at: hall)
        let recap = Rituals.recap(items: store.items, deadlines: [])
        XCTAssertEqual(recap.found, 1)
        XCTAssertEqual(recap.moved, 0)
        XCTAssertEqual(recap.confirmed, 0)
    }

    func testFindingKeepsTheThingInTheRightHome() throws {
        let store = try LocaliserStore(inMemory: true)
        try store.ensureHomes()
        let flat = try XCTUnwrap(store.currentHome)
        let cabin = try store.addHome(name: "Cabin")
        let hall = try store.addPlace(name: "Hall", home: flat)
        let shed = try store.addPlace(name: "Shed", home: cabin)
        let keys = try store.addItem(name: "Keys", place: hall)
        let axe = try store.addItem(name: "Axe", place: shed)
        try store.found(axe, at: shed)
        XCTAssertEqual(store.foundSuggestions(for: keys).map(\.id), [hall.id], "Only places in the thing's own home")
        try store.markMissing(keys)
        try store.found(keys, at: shed)
        XCTAssertEqual(keys.home, cabin)
    }
}
