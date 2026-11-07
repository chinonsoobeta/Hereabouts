import XCTest
@testable import Localiser

@MainActor final class DuplicatePlacesTests: XCTestCase {
    func testEmptyCopiesFoldIntoThePlaceWithThings() throws {
        let store = try LocaliserStore(inMemory: true)
        let kitchen = try store.addPlace(name: "Kitchen")
        let drawer = try store.addPlace(name: "Drawer", parent: kitchen)
        try store.addItem(name: "Scissors", place: drawer)
        let copy = try store.addPlace(name: "kitchen ")
        let copyDrawer = try store.addPlace(name: "Drawer", parent: copy)
        let copyShelf = try store.addPlace(name: "Shelf", parent: copy)
        XCTAssertEqual(store.sparePlaces, [copy])
        try store.mergeSparePlaces()
        XCTAssertTrue(store.sparePlaces.isEmpty)
        XCTAssertEqual(store.places.filter { $0.parent == nil }, [kitchen])
        XCTAssertEqual(Set(kitchen.children.map(\.name)), ["Drawer", "Shelf"])
        XCTAssertTrue(copyDrawer.isDeleted || copyDrawer.managedObjectContext == nil)
        XCTAssertEqual(copyShelf.parent, kitchen)
        XCTAssertEqual(drawer.items.map(\.name), ["Scissors"])
    }

    func testFoldingKeepsPackingReturnPlaces() throws {
        let store = try LocaliserStore(inMemory: true)
        let kitchen = try store.addPlace(name: "Kitchen")
        try store.addItem(name: "Kettle", place: kitchen)
        let copy = try store.addPlace(name: "Kitchen")
        let flask = try store.addItem(name: "Flask", place: copy)
        let kit = try store.addKit(name: "Picnic")
        _ = try store.setKitEntry(kit: kit, name: "", item: flask, unit: 1, perNight: false, condition: .always)
        let today = CalendarDay(.now)
        let trip = try store.addTrip(TripDetails(name: "Beach", start: today.adding(days: 3)!, end: today.adding(days: 4)!), kit: kit)
        let entry = try XCTUnwrap(trip.entries.first)
        try store.pack(entry, count: entry.requiredCount)
        XCTAssertEqual(entry.homePlace, copy)
        store.recordMove(flask, to: kitchen)
        XCTAssertEqual(store.sparePlaces, [copy])
        try store.mergeSparePlaces()
        XCTAssertEqual(entry.homePlace, kitchen)
    }

    func testPlacesWithThingsAreNeverMergedAndOtherLevelsAreLeftAlone() throws {
        let store = try LocaliserStore(inMemory: true)
        let a = try store.addPlace(name: "Garage")
        let b = try store.addPlace(name: "Garage")
        try store.addItem(name: "Drill", place: a)
        let old = try store.addItem(name: "Old drill", place: b)
        try store.setArchived(old, true)
        let hall = try store.addPlace(name: "Hall")
        try store.addPlace(name: "Garage", parent: hall)
        XCTAssertTrue(store.sparePlaces.isEmpty, "Archived things count; a place at another level isn't a copy")
        try store.addHome(name: "Mum's house")
        try store.addPlace(name: "Hall")
        XCTAssertTrue(store.sparePlaces.isEmpty, "Another home's Hall isn't a copy")
    }

    func testTwoEmptyCopiesKeepOne() throws {
        let store = try LocaliserStore(inMemory: true)
        try store.addPlace(name: "Loft"); try store.addPlace(name: "Loft"); try store.addPlace(name: "LOFT")
        XCTAssertEqual(store.sparePlaces.count, 2)
        try store.mergeSparePlaces()
        XCTAssertEqual(store.places.count, 1)
    }
}
