import XCTest
@testable import Localiser

extension AuditCodexTests {
    func testDeletingAPackedReturnPlaceKeepsTheReplacementLocation() throws {
        let store = try LocaliserStore(inMemory: true)
        let room = try store.addPlace(name: "Room")
        let box = try store.addPlace(name: "Box", parent: room)
        let pocket = try store.addPlace(name: "Pocket", parent: box)
        let camera = try store.addItem(name: "Camera", place: box)
        let charger = try store.addItem(name: "Charger", place: pocket)
        try store.lend(charger, to: "Sam", askBackOn: nil)
        let kit = try store.addKit(name: "Travel")
        try store.setKitEntry(kit: kit, name: "", item: camera, unit: 1, perNight: false, condition: .always)
        let day = try XCTUnwrap(CalendarDay(stored: "2030-06-01"))
        let trip = try store.addTrip(TripDetails(name: "Weekend", start: day, end: day), kit: kit)
        let entry = try XCTUnwrap(trip.entries.first)
        try store.pack(entry, count: 1)
        try store.deletePlace(box, clearContents: true)
        XCTAssertEqual(camera.place, room)
        XCTAssertEqual(pocket.parent, room)
        XCTAssertEqual(charger.lentTo, "Sam")
        XCTAssertEqual(kit.entries.first?.item, camera)

        try store.changeTripState(trip, to: .comingHome)
        try store.resolveHome(entry, resolution: .putBack)
        XCTAssertEqual(camera.place, room,
                       "Putting it back must not erase the replacement place selected by deletion")
    }
}
