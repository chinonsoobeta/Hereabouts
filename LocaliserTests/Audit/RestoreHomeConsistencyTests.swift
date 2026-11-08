import XCTest
@testable import Localiser

extension AuditCodexTests {
    func testRestoreDoesNotSplitAThingFromItsPlacesHome() throws {
        let source = try LocaliserStore(inMemory: true)
        let first = try XCTUnwrap(source.currentHome)
        let drawer = try source.addPlace(name: "Drawer")
        let item = try source.addItem(name: "Passport", place: drawer)
        let second = try source.addHome(name: "Cottage")
        var file = try source.backup()
        let itemIndex = try XCTUnwrap(file.records.firstIndex { $0.id == item.id })
        let firstIndex = try XCTUnwrap(file.records.firstIndex { $0.id == first.id })
        let secondIndex = try XCTUnwrap(file.records.firstIndex { $0.id == second.id })
        // Keep every inverse correct; only the home/place invariant is broken.
        file.records[itemIndex].relationships["home"] = [second.id]
        file.records[firstIndex].relationships["items"] = []
        file.records[secondIndex].relationships["items"] = [item.id]
        let target = try LocaliserStore(inMemory: true)
        do { try target.restore(try LibraryBackup.decoded(file.encoded())) }
        catch let error as LocaliserError {
            if case .invalidBackup = error { return }
            throw error
        }
        let restored = try XCTUnwrap(target.items.first { $0.id == item.id })
        XCTAssertEqual(restored.home, restored.place?.home,
                       "Home lists must agree with the home of the place that contains the thing")
    }
}
