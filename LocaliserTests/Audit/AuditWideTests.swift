import XCTest
@testable import Localiser

/// The wide layout's window state: what a fold carries across, and where links land.
@MainActor
final class AuditWideTests: XCTestCase {
    // Some tests add or switch homes, which writes the current home to the standard defaults.
    private nonisolated(unsafe) var savedHomeDefaults: [String: Any] = [:]

    override func setUpWithError() throws {
        for key in [LocaliserStore.currentHomeKey, Home.nameKey] { savedHomeDefaults[key] = UserDefaults.standard.object(forKey: key) }
    }

    override func tearDownWithError() throws {
        for key in [LocaliserStore.currentHomeKey, Home.nameKey] {
            if let value = savedHomeDefaults[key] { UserDefaults.standard.set(value, forKey: key) } else { UserDefaults.standard.removeObject(forKey: key) }
        }
        savedHomeDefaults = [:]
    }

    /// Two homes: "Home" has Garage > Back wall > Rack 2 with a drill in it; "Cabin" has Pantry with jam. Home is current.
    private func twoHomes() throws -> (store: LocaliserStore, garage: Place, wall: Place, rack: Place, drill: Belonging, pantry: Place, jam: Belonging) {
        let store = try LocaliserStore(inMemory: true)
        let first = try XCTUnwrap(store.currentHome)
        let garage = try store.addPlace(name: "Garage")
        let wall = try store.addPlace(name: "Back wall", parent: garage)
        let rack = try store.addPlace(name: "Rack 2", parent: wall)
        let drill = try store.addItem(name: "Drill", place: rack)
        _ = try store.addHome(name: "Cabin")
        let pantry = try store.addPlace(name: "Pantry")
        let jam = try store.addItem(name: "Jam", place: pantry)
        store.switchHome(to: first)
        return (store, garage, wall, rack, drill, pantry, jam)
    }

    // MARK: Codex's tests

    func testNestedPlaceSurvivesACompactWideCompactRoundTrip() throws {
        let store = try LocaliserStore(inMemory: true)
        let room = try store.addPlace(name: "Room")
        let drawer = try store.addPlace(name: "Drawer", parent: room)
        let original: [PlaceRoute] = [.place(room.id), .place(drawer.id)]
        let ui = WindowState()
        ui.tab = .places
        ui.placesPath = original
        // These are the two conversions used by RootView when the width class changes.
        ui.adopt(ui.placesPath, in: store)
        ui.placesPath = ui.routes(in: store)
        XCTAssertEqual(ui.placesPath, original, "Return to the open drawer, not its room")
    }

    func testThingOpenedDirectlyFromPlacesSurvivesUnfolding() throws {
        let store = try LocaliserStore(inMemory: true)
        let room = try store.addPlace(name: "Room")
        let drill = try store.addItem(name: "Drill", place: room)
        try store.lend(drill, to: "Sam", askBackOn: nil)
        let ui = WindowState()
        ui.tab = .places
        // The Lent out row uses RouteLink(.item) directly, without a preceding place.
        ui.placesPath = [.item(drill.id)]
        ui.adopt(ui.placesPath, in: store)
        XCTAssertTrue(ui.selectedItem == drill.id || ui.findItem == drill.id,
                      "The open thing must still have a visible selection after unfolding")
    }

    func testHomeSwitchClearsThePreviousHomesCompactSelection() throws {
        let store = try LocaliserStore(inMemory: true)
        let room = try store.addPlace(name: "Old home room")
        let drill = try store.addItem(name: "Drill", place: room)
        let ui = WindowState()
        ui.reveal(room, item: drill.id)
        ui.placesPath = ui.routes(in: store)
        _ = try store.addHome(name: "Other home") // Also switches the current home.
        ui.dropStaleSelection(in: store)
        XCTAssertEqual(ui.destination, .find)
        XCTAssertNil(ui.selectedItem, "Do not retain a selection from the previous home")
        XCTAssertTrue(ui.placesPath.isEmpty, "Do not reopen the previous home's place on the compact Places tab")
    }

    // MARK: Links on a wide layout

    func testAThingInTheCurrentHomeOpensBesideItsRoomWhenWide() throws {
        let h = try twoHomes()
        let ui = WindowState()
        h.store.openedItem = h.drill.id
        ui.openThing(h.drill.id, wide: true, in: h.store)
        XCTAssertEqual(ui.destination, .place(h.garage.id))
        XCTAssertEqual(ui.selectedItem, h.drill.id)
        XCTAssertNil(h.store.openedItem)
    }

    func testAThingInAnotherHomeOpensInFindWithoutSwitchingHomes() throws {
        let h = try twoHomes()
        let before = h.store.currentHome
        let ui = WindowState()
        h.store.openedItem = h.jam.id
        ui.openThing(h.jam.id, wide: true, in: h.store)
        XCTAssertEqual(ui.destination, .find)
        XCTAssertEqual(ui.findItem, h.jam.id)
        XCTAssertNil(ui.selectedItem)
        XCTAssertEqual(h.store.currentHome, before, "A thing opens where it is, in Find")
        XCTAssertNil(h.store.openedItem, "Consumed here, so Find doesn't open it a second time")
    }

    func testAThingWithNoPlaceOpensInFindWhenWide() throws {
        let store = try LocaliserStore(inMemory: true)
        let loose = try store.addItem(name: "Loose")
        let ui = WindowState()
        ui.openThing(loose.id, wide: true, in: store)
        XCTAssertEqual(ui.destination, .find)
        XCTAssertEqual(ui.findItem, loose.id)
    }

    func testAThingLinkOnACompactLayoutIsLeftToFind() throws {
        let h = try twoHomes()
        let ui = WindowState()
        h.store.openedItem = h.jam.id
        ui.openThing(h.jam.id, wide: false, in: h.store)
        XCTAssertEqual(ui.destination, .find)
        XCTAssertNil(ui.findItem, "Find's own view takes it")
        XCTAssertEqual(h.store.openedItem, h.jam.id)
    }

    func testAPlaceInAnotherHomeSwitchesHomesAndOpensWhenWide() throws {
        let h = try twoHomes()
        let ui = WindowState()
        ui.openPlace(h.pantry.id, wide: true, in: h.store)
        XCTAssertEqual(h.store.currentHome, h.pantry.home)
        XCTAssertEqual(ui.destination, .place(h.pantry.id))
        XCTAssertTrue(ui.roomPaths[h.pantry.id, default: []].isEmpty)
        ui.dropStaleSelection(in: h.store)
        XCTAssertEqual(ui.destination, .place(h.pantry.id), "...and the open place isn't mistaken for a stale one")
    }

    func testANestedPlaceLinkOpensTheBoxInsideItsRoomWhenWide() throws {
        let h = try twoHomes()
        let ui = WindowState()
        ui.openPlace(h.rack.id, wide: true, in: h.store)
        XCTAssertEqual(ui.destination, .place(h.garage.id))
        XCTAssertEqual(ui.roomPaths[h.garage.id], [.place(h.wall.id), .place(h.rack.id)])
        XCTAssertEqual(ui.labelled, h.rack.id, "From a box label: Put things in this box")
        // The compact Places tab gets the same places when the window folds.
        XCTAssertEqual(ui.routes(in: h.store), [.place(h.garage.id), .place(h.wall.id), .place(h.rack.id)])
    }

    func testARoomLinkOpensTheRoomWhenWide() throws {
        let h = try twoHomes()
        let ui = WindowState()
        ui.openPlace(h.garage.id, wide: true, in: h.store)
        XCTAssertEqual(ui.destination, .place(h.garage.id))
        XCTAssertTrue(ui.roomPaths[h.garage.id, default: []].isEmpty)
        XCTAssertEqual(ui.labelled, h.garage.id)
    }

    func testAPlaceLinkOnACompactLayoutIsLeftToPlaces() throws {
        let h = try twoHomes()
        let ui = WindowState()
        ui.openPlace(h.rack.id, wide: false, in: h.store)
        XCTAssertEqual(ui.destination, .places)
        XCTAssertEqual(h.store.openedPlace, h.rack.id)
    }

    func testAPlaceThatIsNotInTheNotebookIsLeftToPlacesToSay() throws {
        let h = try twoHomes()
        let ui = WindowState()
        let unknown = UUID()
        ui.openPlace(unknown, wide: true, in: h.store)
        XCTAssertEqual(ui.destination, .places)
        XCTAssertEqual(h.store.openedPlace, unknown)
    }

    // MARK: What a fold carries

    func testANestedPlaceOpenOnTheWideLayoutFoldsToTheCompactPath() throws {
        let h = try twoHomes()
        let ui = WindowState()
        ui.reveal(h.garage)
        ui.roomPaths[h.garage.id] = [.place(h.wall.id)]
        XCTAssertEqual(ui.routes(in: h.store), [.place(h.garage.id), .place(h.wall.id)])
        ui.selectedItem = h.drill.id
        XCTAssertEqual(ui.routes(in: h.store), [.place(h.garage.id), .place(h.wall.id), .place(h.rack.id), .item(h.drill.id)])
    }

    func testAPlaceOpenedDirectlyOnCompactUnfoldsInsideItsRoom() throws {
        let h = try twoHomes()
        let ui = WindowState()
        ui.tab = .places
        ui.placesPath = [.place(h.rack.id)] // a box label opened it, with no room before it
        ui.adopt(ui.placesPath, in: h.store)
        XCTAssertEqual(ui.destination, .place(h.garage.id))
        XCTAssertEqual(ui.roomPaths[h.garage.id], [.place(h.wall.id), .place(h.rack.id)])
    }

    func testAThingOpenedFromLentOutBesideItsRoomOrInFindWhenUnfolding() throws {
        let h = try twoHomes()
        let ui = WindowState()
        ui.tab = .places
        ui.placesPath = [.item(h.drill.id)]
        ui.adopt(ui.placesPath, in: h.store)
        XCTAssertEqual(ui.destination, .place(h.garage.id))
        XCTAssertEqual(ui.selectedItem, h.drill.id)

        let loose = try h.store.addItem(name: "Loose")
        let again = WindowState()
        again.tab = .places
        again.placesPath = [.item(loose.id)]
        again.adopt(again.placesPath, in: h.store)
        XCTAssertEqual(again.destination, .find)
        XCTAssertEqual(again.findItem, loose.id)
    }

    // MARK: Stale selections

    func testAHomeSwitchTrimsTheNestedPlacesOfTheOldHome() throws {
        let h = try twoHomes()
        let ui = WindowState()
        ui.openPlace(h.rack.id, wide: true, in: h.store)
        XCTAssertNotNil(ui.roomPaths[h.garage.id])
        h.store.switchHome(to: try XCTUnwrap(h.pantry.home))
        ui.dropStaleSelection(in: h.store)
        XCTAssertEqual(ui.destination, .find)
        XCTAssertNil(ui.roomPaths[h.garage.id], "Nothing left of the old home's places")
        XCTAssertNil(ui.labelled)
    }

    func testAPlaceOrThingFromAnotherHomeSurvivesCleanup() throws {
        let h = try twoHomes()
        let ui = WindowState()
        ui.tab = .places
        ui.placesPath = [.item(h.jam.id)] // Lent out lists things from every home
        ui.dropStaleSelection(in: h.store)
        XCTAssertEqual(ui.placesPath, [.item(h.jam.id)])
    }

    // MARK: Leaving a stack with a bound path

    func testLeavingSettingsOnTheWideLayoutClosesItsPage() {
        let ui = WindowState()
        ui.wide = true
        ui.destination = .settings
        ui.settingsPath = [.homes]
        ui.destination = .find
        XCTAssertTrue(ui.settingsPath.isEmpty, "A page can't stay pushed in a stack that leaves the detail column")
    }

    func testAFoldOrResizeKeepsTheSettingsPageOpen() {
        let ui = WindowState()
        ui.wide = true
        ui.destination = .settings
        ui.settingsPath = [.acknowledgements]
        ui.wide = false
        ui.wide = true
        ui.tab = .settings // asking for the tab already showing changes nothing
        XCTAssertEqual(ui.settingsPath, [.acknowledgements])
    }

    func testTheCompactLayoutKeepsASettingsPageWhenAnotherTabIsShown() {
        let ui = WindowState()
        ui.tab = .settings
        ui.settingsPath = [.pro]
        ui.tab = .find
        ui.tab = .settings
        XCTAssertEqual(ui.settingsPath, [.pro], "Unchanged: the tabs keep their pages")
    }

    func testLeavingARoomOnTheWideLayoutClosesTheBoxesPushedInIt() throws {
        let h = try twoHomes()
        let ui = WindowState()
        ui.wide = true
        ui.openPlace(h.rack.id, wide: true, in: h.store)
        ui.destination = .find
        XCTAssertNil(ui.roomPaths[h.garage.id])
        XCTAssertNil(ui.labelled)
    }

    // MARK: Editors and trips survive a fold

    private func beach() -> TripDetails { TripDetails(name: "Beach", start: CalendarDay(.now), end: CalendarDay(.now)) }

    func testTheEditorsSheetsAreHeldByTheWindowSoAFoldKeepsThem() throws {
        let store = try LocaliserStore(inMemory: true)
        let room = try store.addPlace(name: "Room")
        let kit = try store.addKit(name: "Weekend")
        let trip = try store.addTrip(beach(), kit: kit)
        let ui = WindowState()
        XCTAssertFalse(ui.sheetOpen)
        for sheet in [PlaceSheet.edit(room.id), .addInside(room.id)] {
            ui.placeSheet = sheet
            XCTAssertTrue(ui.sheetOpen, "\(sheet) is presented by the window, so the keyboard shortcuts wait for it")
            ui.wide = true; ui.wide = false
            XCTAssertEqual(ui.placeSheet, sheet, "A fold leaves it open")
            ui.placeSheet = nil
        }
        for sheet in [PackingSheet.newTrip, .newKit, .editTrip(trip.id), .editKit(kit.id), .tripWithKit(kit.id), .addToTrip(trip.id), .addToKit(kit.id)] {
            ui.packingSheet = sheet
            XCTAssertTrue(ui.sheetOpen)
            ui.wide = true; ui.wide = false
            XCTAssertEqual(ui.packingSheet, sheet)
            ui.packingSheet = nil
        }
        XCTAssertFalse(ui.sheetOpen)
    }

    func testAnEditorSheetForSomethingThatIsGoneCloses() throws {
        let store = try LocaliserStore(inMemory: true)
        let room = try store.addPlace(name: "Room")
        let kit = try store.addKit(name: "Weekend")
        let ui = WindowState()
        ui.placeSheet = .edit(room.id)
        ui.dropStaleSelection(in: store)
        XCTAssertEqual(ui.placeSheet, .edit(room.id), "Still there")
        try store.deletePlace(room, clearContents: true)
        ui.dropStaleSelection(in: store)
        XCTAssertNil(ui.placeSheet)
        ui.packingSheet = .editKit(kit.id)
        try store.deleteKit(kit)
        ui.dropStaleSelection(in: store)
        XCTAssertNil(ui.packingSheet)
        ui.packingSheet = .newTrip
        ui.dropStaleSelection(in: store)
        XCTAssertEqual(ui.packingSheet, .newTrip, "A new trip has nothing to be gone")
    }

    func testAnOpenTripOrKitSurvivesAFoldBothWays() throws {
        let store = try LocaliserStore(inMemory: true)
        let kit = try store.addKit(name: "Weekend")
        let trip = try store.addTrip(beach(), kit: kit)
        // Wide to compact: the trip or the kit the sidebar picked is pushed on the Trips tab.
        let wide = WindowState()
        wide.destination = .trip(trip.id)
        XCTAssertEqual(wide.tripRoutes(), [.trip(trip.id)])
        wide.destination = .kit(kit.id)
        XCTAssertEqual(wide.tripRoutes(), [.kit(kit.id)])
        wide.destination = .trips
        wide.tripsPath = [.trip(trip.id)]
        XCTAssertEqual(wide.tripRoutes(), [.trip(trip.id)], "A trip opened from the list stays open")
        wide.destination = .find
        XCTAssertEqual(wide.tripRoutes(), [])
        // Compact to wide: the trip pushed is the sidebar's pick, and the path is not kept twice.
        let phone = WindowState()
        phone.tab = .packing
        phone.tripsPath = [.trip(trip.id)]
        phone.adoptTrips(phone.tripsPath, in: store)
        XCTAssertEqual(phone.destination, .trip(trip.id))
        phone.tripsPath = [.kit(kit.id)]
        phone.adoptTrips(phone.tripsPath, in: store)
        XCTAssertEqual(phone.destination, .kit(kit.id))
        phone.adoptTrips([], in: store)
        XCTAssertEqual(phone.destination, .trips, "Back at the list")
        // A round trip returns to the same page.
        let round = WindowState()
        round.destination = .trip(trip.id)
        let there = round.tripRoutes()
        let back = WindowState()
        back.tab = .packing
        back.adoptTrips(there, in: store)
        XCTAssertEqual(back.destination, .trip(trip.id))
        // A trip that has gone is cut off the path.
        back.tripsPath = there
        try store.deleteTrip(trip)
        back.dropStaleSelection(in: store)
        XCTAssertEqual(back.tripsPath, [])
        XCTAssertEqual(back.destination, .trips)
    }

    func testLeavingTheTripsListOnTheWideLayoutClosesATripPushedInIt() throws {
        let store = try LocaliserStore(inMemory: true)
        let trip = try store.addTrip(beach(), kit: nil)
        let ui = WindowState()
        ui.wide = true
        ui.destination = .trips
        ui.tripsPath = [.trip(trip.id)]
        ui.wide = false; ui.wide = true
        XCTAssertEqual(ui.tripsPath, [.trip(trip.id)], "A fold doesn't change the destination")
        ui.destination = .find
        XCTAssertEqual(ui.tripsPath, [], "The bound stack leaves the detail column with no page pushed")
    }
}
