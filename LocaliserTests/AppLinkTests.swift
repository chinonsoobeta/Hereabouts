import XCTest
import UniformTypeIdentifiers
@testable import Localiser

@MainActor
final class AppLinkTests: XCTestCase {
    func testLinksRoundTrip() throws {
        let id = UUID()
        for link in [AppLink.find, .new, .putAway, .lent, .item(id)] { XCTAssertEqual(AppLink(url: link.url), link) }
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

    /// The Lent out widget opens the Lent out tab, not Find (beta feedback, 12 Nov).
    func testTheLentOutWidgetOpensLentOut() {
        XCTAssertEqual(AppLink(url: WidgetButtons.lent), .lent)
        XCTAssertEqual(WidgetButtons.lent, AppLink.lent.url)
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

    /// Lent out is its own tab, between Trips and Settings (owner, 12 Nov).
    func testLentOutIsItsOwnTab() {
        let id = UUID()
        XCTAssertEqual(Destination.lent.tab, .lent)
        XCTAssertEqual(Destination(tab: .lent, keeping: .place(id)), .lent)
        XCTAssertEqual(Destination(tab: .places, keeping: .lent), .places)
        let ui = WindowState()
        ui.tab = .lent
        XCTAssertEqual(ui.destination, .lent)
        XCTAssertEqual(AppTab.allCases, [.find, .places, .packing, .lent, .settings], "Settings stays the rightmost tab")
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

/// M67: a thing dropped on a place in the sidebar moves the way the Move sheet moves it, and the layout follows the width.
@MainActor
final class DropAndLayoutTests: XCTestCase {
    func testDroppingAThingOnAPlaceMovesItLikeTheMoveSheet() throws {
        let store = try LocaliserStore(inMemory: true)
        let kitchen = try store.addPlace(name: "Kitchen")
        let garage = try store.addPlace(name: "Garage")
        let kettle = try store.addItem(name: "Kettle", place: kitchen)
        let tin = try store.addItem(name: "Tin", place: kitchen)
        let before = Date.now.addingTimeInterval(-60)
        kettle.confirmedAt = before
        XCTAssertEqual(try store.moveDropped([kettle.id], to: garage), 1)
        try store.move(tin, to: garage)
        XCTAssertEqual(kettle.place, garage)
        XCTAssertEqual(kettle.home, garage.home)
        XCTAssertGreaterThan(try XCTUnwrap(kettle.confirmedAt), before, "Moving confirms the thing is there")
        let moves = kettle.movements.sorted { $0.date < $1.date }
        let same = tin.movements.sorted { $0.date < $1.date }
        XCTAssertEqual(moves.map(\.fromPath), same.map(\.fromPath))
        XCTAssertEqual(moves.map(\.toPath), same.map(\.toPath))
        XCTAssertEqual(moves.last?.fromPath, "Kitchen")
        XCTAssertEqual(moves.last?.toPath, "Garage")
        XCTAssertEqual(garage.activeItemCount, 2)
    }

    func testDroppingOnThePlaceItIsAlreadyInDoesNothing() throws {
        let store = try LocaliserStore(inMemory: true)
        let kitchen = try store.addPlace(name: "Kitchen")
        let kettle = try store.addItem(name: "Kettle", place: kitchen)
        let confirmed = try XCTUnwrap(kettle.confirmedAt)
        let moves = kettle.movements.count
        XCTAssertEqual(try store.moveDropped([kettle.id], to: kitchen), 0)
        XCTAssertEqual(kettle.movements.count, moves, "No history is written")
        XCTAssertEqual(kettle.confirmedAt, confirmed)
    }

    func testDropsLeaveThingsFromAnotherHomeAndThingsThatAreGone() throws {
        let store = try LocaliserStore(inMemory: true)
        let flat = try XCTUnwrap(store.currentHome)
        let kitchen = try store.addPlace(name: "Kitchen")
        let kettle = try store.addItem(name: "Kettle", place: kitchen)
        let boat = try store.addHome(name: "The boat")
        let galley = try store.addPlace(name: "Galley")
        XCTAssertEqual(galley.home, boat)
        XCTAssertEqual(try store.moveDropped([kettle.id], to: galley), 0, "A thing changes home through Move to another home")
        XCTAssertEqual(kettle.place, kitchen)
        XCTAssertEqual(kettle.home, flat)
        store.switchHome(to: flat)
        let gone = try store.addItem(name: "Gone", place: kitchen)
        let goneID = gone.id
        try store.deleteItem(gone)
        let pantry = try store.addPlace(name: "Pantry")
        XCTAssertEqual(try store.moveDropped([goneID, UUID()], to: pantry), 0)
    }

    func testAPrivateThingMovesAndNeverCarriesItsNameInTheDrag() throws {
        let store = try LocaliserStore(inMemory: true)
        let drawer = try store.addPlace(name: "Drawer")
        let safe = try store.addPlace(name: "Safe")
        let passport = try store.addItem(name: "Passport", place: drawer, isPrivate: true)
        XCTAssertEqual(try store.moveDropped([passport.id], to: safe), 1)
        XCTAssertEqual(passport.place, safe)
        XCTAssertTrue(passport.isPrivate)
        let payload = try XCTUnwrap(String(data: JSONEncoder().encode(ThingDrag(id: passport.id)), encoding: .utf8))
        XCTAssertFalse(payload.contains("Passport"))
        XCTAssertFalse(payload.contains("Drawer"))
        XCTAssertEqual(try JSONDecoder().decode(ThingDrag.self, from: Data(payload.utf8)).id, passport.id)
    }

    func testTheDragTypeIsDeclaredSoOnlyHereaboutsTakesIt() throws {
        let declared = try XCTUnwrap(Bundle.main.object(forInfoDictionaryKey: "UTExportedTypeDeclarations") as? [[String: Any]])
        XCTAssertEqual(declared.compactMap { $0["UTTypeIdentifier"] as? String }, ["dev.hereabouts.app.thing"])
        XCTAssertEqual(UTType.hereaboutsThing.identifier, "dev.hereabouts.app.thing")
    }

    func testTheLayoutFollowsTheWidthClass() {
        XCTAssertTrue(WindowLayout.isWide(.regular))
        XCTAssertFalse(WindowLayout.isWide(.compact), "A third-width Split View window, Slide Over and every iPhone")
        XCTAssertFalse(WindowLayout.isWide(nil))
    }

    func testAnyOpenSheetCountsAsOne() {
        let ui = WindowState()
        XCTAssertFalse(ui.sheetOpen)
        ui.newThing = NewThing(); XCTAssertTrue(ui.sheetOpen); ui.newThing = nil
        ui.speaking = true; XCTAssertTrue(ui.sheetOpen); ui.speaking = false
        ui.addingPlace = true; XCTAssertTrue(ui.sheetOpen); ui.addingPlace = false
        ui.upgrading = true; XCTAssertTrue(ui.sheetOpen); ui.upgrading = false
        ui.ritual = .recap; XCTAssertTrue(ui.sheetOpen); ui.ritual = nil
        ui.itemSheet = .move(UUID()); XCTAssertTrue(ui.sheetOpen); ui.itemSheet = nil
        XCTAssertFalse(ui.sheetOpen)
    }
}
