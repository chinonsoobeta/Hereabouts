import XCTest
@testable import Localiser

extension AuditCodexTests {
    func testSiriLocationDistinguishesIdenticalPathsInDifferentHomes() throws {
        let store = try LocaliserStore(inMemory: true)
        let first = try XCTUnwrap(store.currentHome)
        try store.renameHome(first, to: "Downtown")
        let firstDrawer = try store.addPlace(name: "Drawer")
        let item = try store.addItem(name: "Passport", place: firstDrawer)
        let second = try store.addHome(name: "Cottage")
        let secondDrawer = try store.addPlace(name: "Drawer")
        try store.moveThing(item, toHome: second, place: secondDrawer)

        let answer = FindThingIntent.answer(for: item)
        XCTAssertTrue(answer.contains(second.name),
                      "Siri must identify which home's Drawer now contains the Passport; actual: \(answer)")
    }
}
