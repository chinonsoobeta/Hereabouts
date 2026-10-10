import XCTest
@testable import Localiser

@MainActor
final class IntentsTests: XCTestCase {
    override func tearDown() { IntentLibrary.store = nil; super.tearDown() }

    func testWhereIsAnswersFromTheNotebook() throws {
        let store = try LocaliserStore(inMemory: true)
        IntentLibrary.store = store
        let hall = try store.addPlace(name: "Hall closet")
        let shelf = try store.addPlace(name: "Top shelf", parent: hall)
        let passport = try store.addItem(name: "Passport", place: shelf)
        let loose = try store.addItem(name: "Torch", place: nil)
        XCTAssertEqual(FindThingIntent.answer(for: passport), "Passport is in Hall closet › Top shelf.")
        XCTAssertEqual(FindThingIntent.answer(for: loose), "Torch is written down, but without a place yet.")
        try store.setArchived(passport, true)
        XCTAssertTrue(FindThingIntent.answer(for: passport).hasPrefix("Passport is archived."))
    }

    func testThingQueryMatchesNamesAndAliasesButNotArchived() async throws {
        let store = try LocaliserStore(inMemory: true)
        IntentLibrary.store = store
        _ = try store.addItem(name: "Passports (family)", aliases: "travel documents")
        let old = try store.addItem(name: "Old passport")
        try store.setArchived(old, true)
        let byName = try await ThingQuery().entities(matching: "passport")
        XCTAssertEqual(byName.map(\.name), ["Passports (family)"])
        let byAlias = try await ThingQuery().entities(matching: "travel")
        XCTAssertEqual(byAlias.map(\.name), ["Passports (family)"])
    }

    func testAddThingWritesItDownInTheChosenPlace() async throws {
        let store = try LocaliserStore(inMemory: true)
        IntentLibrary.store = store
        let garage = try store.addPlace(name: "Garage")
        var intent = AddThingIntent()
        intent.name = "Drill"
        intent.place = PlaceEntity(id: garage.id, path: garage.path)
        _ = try await intent.perform()
        XCTAssertEqual(store.items.first?.name, "Drill")
        XCTAssertEqual(store.items.first?.place?.id, garage.id)
    }

    func testAddThingStopsAtTheFreeAllowance() async throws {
        let store = try LocaliserStore(inMemory: true)
        IntentLibrary.store = store
        for index in 0..<CreationKind.item.freeLimit { _ = try store.addItem(name: "Thing \(index)") }
        var intent = AddThingIntent()
        intent.name = "One too many"
        do {
            _ = try await intent.perform()
            XCTFail("Should stop at the free allowance")
        } catch let error as HereaboutsIntentError {
            XCTAssertEqual(error, .freeLimit)
        }
        XCTAssertEqual(store.activeItemCount, CreationKind.item.freeLimit)
    }
}
