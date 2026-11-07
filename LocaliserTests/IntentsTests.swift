import XCTest
@testable import Localiser

@MainActor
final class IntentsTests: XCTestCase {
    nonisolated override func tearDown() async throws {
        await MainActor.run { IntentLibrary.store = nil }
        try await super.tearDown()
    }

    func testWhereIsAnswersFromTheNotebook() throws {
        let store = try LocaliserStore(inMemory: true)
        IntentLibrary.store = store
        let hall = try store.addPlace(name: "Hall closet")
        let shelf = try store.addPlace(name: "Top shelf", parent: hall)
        let passport = try store.addItem(name: "Passport", place: shelf)
        let loose = try store.addItem(name: "Torch", place: nil)
        XCTAssertEqual(FindThingIntent.answer(for: passport), "Passport is in Hall closet › Top shelf.")
        XCTAssertEqual(FindThingIntent.answer(for: loose), "You've saved Torch, but haven't added a place yet.")
        try store.setArchived(passport, true)
        XCTAssertEqual(FindThingIntent.answer(for: passport), "Passport is archived. It was last in Hall closet › Top shelf.")
        try store.setArchived(loose, true)
        XCTAssertEqual(FindThingIntent.answer(for: loose), "Torch is archived.")
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
        let intent = AddThingIntent()
        intent.name = "Drill"
        intent.place = PlaceEntity(garage, severalHomes: false)
        _ = try await intent.perform()
        XCTAssertEqual(store.items.first?.name, "Drill")
        XCTAssertEqual(store.items.first?.place?.id, garage.id)
    }

    func testAddThingStopsAtTheFreeAllowance() async throws {
        let store = try LocaliserStore(inMemory: true)
        IntentLibrary.store = store
        for index in 0..<CreationKind.item.freeLimit { _ = try store.addItem(name: "Thing \(index)") }
        let intent = AddThingIntent()
        intent.name = "One too many"
        do {
            _ = try await intent.perform()
            XCTFail("Should stop at the free allowance")
        } catch let error as HereaboutsIntentError {
            XCTAssertEqual(error, .freeLimit)
        }
        XCTAssertEqual(store.activeItemCount, CreationKind.item.freeLimit)
    }
    func testMissingAnswerAndPrivacyPrecedence() throws {
        let store = try LocaliserStore(inMemory: true)
        let drawer = try store.addPlace(name: "Drawer")
        let item = try store.addItem(name: "Passport", place: drawer)
        try store.markMissing(item)
        XCTAssertEqual(FindThingIntent.answer(for: item), "Passport is marked missing. It was last in Drawer.")
        item.place = nil
        XCTAssertEqual(FindThingIntent.answer(for: item), "Passport is marked missing.")
        item.archived = true
        XCTAssertEqual(FindThingIntent.answer(for: item), "Passport is archived.")
        item.isPrivate = true
        XCTAssertEqual(FindThingIntent.answer(for: item), "That one's private. Open Hereabouts to see it.")
    }

    func testPlaceChoicesNameTheHomeWhenThereAreSeveral() throws {
        let store = try LocaliserStore(inMemory: true)
        let hall = try store.addPlace(name: "Hall")
        XCTAssertEqual(PlaceEntity(hall, severalHomes: store.hasSeveralHomes).title, "Hall")
        let boat = try store.addHome(name: "The boat")
        let deck = try store.addPlace(name: "Deck", home: boat)
        let entity = PlaceEntity(deck, severalHomes: store.hasSeveralHomes)
        XCTAssertEqual(entity.title, "The boat · Deck")
        XCTAssertEqual(entity.path, "Deck")
    }

    func testSiriTipsAreShownOnceEach() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "SiriTipsTests.\(UUID().uuidString)"))
        XCTAssertTrue(SiriTip.allCases.allSatisfy { $0.isShown(in: defaults) }, "Both start out showing")
        SiriTip.whereIs.dismiss(in: defaults)
        XCTAssertFalse(SiriTip.whereIs.isShown(in: defaults))
        XCTAssertTrue(SiriTip.writeDown.isShown(in: defaults), "Dismissing one leaves the other")
        SiriTip.writeDown.dismiss(in: defaults)
        XCTAssertFalse(SiriTip.writeDown.isShown(in: defaults))
        XCTAssertNotEqual(SiriTip.whereIs.key, SiriTip.writeDown.key)
    }
}
