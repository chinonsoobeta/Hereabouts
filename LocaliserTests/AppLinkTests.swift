import XCTest
@testable import Localiser

@MainActor
final class AppLinkTests: XCTestCase {
    func testLinksRoundTrip() throws {
        let id = UUID()
        for link in [AppLink.find, .new, .putAway, .item(id)] { XCTAssertEqual(AppLink(url: link.url), link) }
        XCTAssertNil(AppLink(url: URL(string: "hereabouts://due")!), "The Due page is gone")
        XCTAssertNil(AppLink(url: URL(string: "hereabouts://item/not-an-id")!))
        XCTAssertNil(AppLink(url: URL(string: "https://find")!))
        XCTAssertNil(AppLink(url: URL(string: "hereabouts://elsewhere")!))
    }

    func testAppIconShortcutsAreFixedLinks() throws {
        let items = try XCTUnwrap(Bundle.main.object(forInfoDictionaryKey: "UIApplicationShortcutItems") as? [[String: Any]])
        let links = items.compactMap { ($0["UIApplicationShortcutItemType"] as? String).flatMap(URL.init(string:)).flatMap(AppLink.init(url:)) }
        XCTAssertEqual(links, [.find, .putAway])
        XCTAssertTrue(QuickActions.shared.handle(UIApplicationShortcutItem(type: "hereabouts://putaway", localizedTitle: "Put something away")))
        XCTAssertEqual(QuickActions.shared.link, .putAway)
        XCTAssertFalse(QuickActions.shared.handle(UIApplicationShortcutItem(type: "recent.thing", localizedTitle: "Passport")))
        QuickActions.shared.link = nil
    }

    func testWidgetButtonsOpenFindAndTheVoiceMemo() {
        XCTAssertEqual(WidgetButtons.links(for: Locale(identifier: "en_US")).compactMap(AppLink.init(url:)), [.find, .say])
        XCTAssertEqual(WidgetButtons.links(for: Locale(identifier: "en_GB")).compactMap(AppLink.init(url:)), [.find, .say])
        XCTAssertEqual(WidgetButtons.links(for: Locale(identifier: "fr_FR")).compactMap(AppLink.init(url:)), [.find], "No voice, so Find alone")
        XCTAssertEqual(WidgetButtons.find, AppLink.find.url)
        XCTAssertEqual(WidgetButtons.say, AppLink.say.url)
    }

    func testSendWhereItIs() throws {
        let store = try LocaliserStore(inMemory: true)
        let bowl = try store.addPlace(name: "Key bowl", parent: try store.addPlace(name: "Hall"))
        let key = try store.addItem(name: "Spare key", place: bowl)
        XCTAssertEqual(key.whereItIsSentence, "Spare key is in Hall › Key bowl.")
        let drill = try store.addItem(name: "Drill", place: bowl)
        drill.lentTo = "Sam"
        XCTAssertEqual(drill.whereItIsSentence, "Drill is with Sam.")
        XCTAssertNil(try store.addItem(name: "Torch").whereItIsSentence)
    }
    func testMissingThingIsReportedAsMissing() throws {
        let store = try LocaliserStore(inMemory: true)
        let drawer = try store.addPlace(name: "Drawer")
        let item = try store.addItem(name: "Passport", place: drawer)
        try store.markMissing(item)
        XCTAssertEqual(item.whereItIsSentence, "Passport is marked missing. It was last in Drawer.")
        item.place = nil
        XCTAssertEqual(item.whereItIsSentence, "Passport is marked missing.")
    }

}

/// What is open in the window must outlive the layout swapping between tabs and sidebar (M66).
@MainActor
final class WindowStateTests: XCTestCase {
    func testTabsKeepAnOpenPlaceTripOrKit() {
        let id = UUID()
        XCTAssertEqual(Destination.place(id).tab, .places)
        XCTAssertEqual(Destination(tab: .places, keeping: .place(id)), .place(id))
        XCTAssertEqual(Destination(tab: .packing, keeping: .trip(id)), .trip(id))
        XCTAssertEqual(Destination(tab: .packing, keeping: .place(id)), .trips)
        XCTAssertEqual(Destination(tab: .find, keeping: .kit(id)), .find)
        let ui = WindowState()
        ui.destination = .kit(id)
        XCTAssertEqual(ui.tab, .packing)
        ui.tab = .settings
        XCTAssertEqual(ui.destination, .settings)
    }

    func testRevealOpensTheTopLevelPlaceWithTheThing() throws {
        let store = try LocaliserStore(inMemory: true)
        let garage = try store.addPlace(name: "Garage")
        let rack = try store.addPlace(name: "Rack", parent: garage)
        let drill = try store.addItem(name: "Drill", place: rack)
        XCTAssertEqual(rack.topLevel, garage)
        let ui = WindowState()
        ui.reveal(rack, item: drill.id)
        XCTAssertEqual(ui.destination, .place(garage.id))
        XCTAssertEqual(ui.selectedItem, drill.id)
    }

    func testFoldingCarriesThePlaceAndThingBothWays() throws {
        let store = try LocaliserStore(inMemory: true)
        let garage = try store.addPlace(name: "Garage")
        let rack = try store.addPlace(name: "Rack", parent: garage)
        let shelf = try store.addPlace(name: "Shelf", parent: rack)
        let drill = try store.addItem(name: "Drill", place: shelf)
        let kettle = try store.addItem(name: "Kettle", place: try store.addPlace(name: "Kitchen"))

        // Wide to compact: the room, the places down to the thing, then the thing.
        let ui = WindowState()
        XCTAssertEqual(ui.routes(in: store), [], "Find has nothing pushed")
        ui.reveal(garage)
        XCTAssertEqual(ui.routes(in: store), [.place(garage.id)])
        ui.reveal(shelf, item: drill.id)
        XCTAssertEqual(ui.routes(in: store), [.place(garage.id), .place(rack.id), .place(shelf.id), .item(drill.id)])

        // Compact to wide: the first place is the room, a last thing is the selection.
        let phone = WindowState()
        phone.tab = .places
        phone.adopt([.place(garage.id), .place(rack.id), .item(drill.id)], in: store)
        XCTAssertEqual(phone.destination, .place(garage.id))
        XCTAssertEqual(phone.selectedItem, drill.id)
        phone.adopt([.place(garage.id), .place(rack.id)], in: store)
        XCTAssertNil(phone.selectedItem, "A place on top means no thing is open")
        phone.adopt([], in: store)
        XCTAssertEqual(phone.destination, .places, "Back at the list of places")
        phone.adopt([.place(rack.id)], in: store)
        XCTAssertEqual(phone.destination, .place(garage.id), "A place inside opens its room")

        // Round trip, and a path whose thing has gone is cut back.
        let round = WindowState()
        round.reveal(shelf, item: drill.id)
        let there = round.routes(in: store)
        let back = WindowState()
        back.tab = .places
        back.adopt(there, in: store)
        XCTAssertEqual(back.destination, .place(garage.id))
        XCTAssertEqual(back.selectedItem, drill.id)
        back.placesPath = there
        try store.deleteItem(drill)
        back.dropStaleSelection(in: store)
        XCTAssertEqual(back.placesPath, [.place(garage.id), .place(rack.id), .place(shelf.id)])
        XCTAssertNotNil(kettle)
    }

    func testStaleSelectionIsDroppedButLiveSelectionSurvives() throws {
        let store = try LocaliserStore(inMemory: true)
        let kitchen = try store.addPlace(name: "Kitchen")
        let garage = try store.addPlace(name: "Garage")
        let kettle = try store.addItem(name: "Kettle", place: kitchen)
        let ui = WindowState()
        ui.reveal(kitchen, item: kettle.id)
        ui.query = "ket"; ui.newThing = NewThing(name: "x"); ui.speaking = true
        ui.dropStaleSelection(in: store)
        XCTAssertEqual(ui.selectedItem, kettle.id)
        XCTAssertEqual(ui.query, "ket")
        XCTAssertNotNil(ui.newThing)
        XCTAssertTrue(ui.speaking)
        // The thing moves to another room: it is no longer the one beside the Kitchen.
        try store.move(kettle, to: garage)
        ui.dropStaleSelection(in: store)
        XCTAssertNil(ui.selectedItem)
        // The place itself is deleted: the window goes back to Find.
        try store.deletePlace(kitchen, clearContents: true)
        ui.dropStaleSelection(in: store)
        XCTAssertEqual(ui.destination, .find)
    }
}
