import XCTest
@testable import Localiser

extension AuditCodexTests {
    func testRestoreCannotCreateAnOverLimitFreeNotebook() throws {
        let source = try LocaliserStore(inMemory: true)
        for index in 0...CreationKind.item.freeLimit { try source.addItem(name: "Thing \(index)") }
        for index in 0...CreationKind.kit.freeLimit { try source.addKit(name: "Kit \(index)") }
        // A new notebook already contains one home.
        for index in 1...CreationKind.home.freeLimit { try source.addHome(name: "Home \(index)") }
        let file = try LibraryBackup.decoded(source.backup().encoded())
        let target = try LocaliserStore(inMemory: true)
        for index in 0..<CreationKind.item.freeLimit { try target.addItem(name: "Existing \(index)") }
        XCTAssertFalse(ProAccess().unlocked)
        let originalIDs = Set(target.items.map(\.id))

        // Rejection is acceptable; silently creating more than all three allowances is not.
        do { try target.restore(file, replacingExisting: true) }
        catch {
            XCTAssertEqual(Set(target.items.map(\.id)), originalIDs, "Refusing restore must preserve the full notebook")
        }
        XCTAssertLessThanOrEqual(target.activeItemCount, CreationKind.item.freeLimit)
        XCTAssertLessThanOrEqual(target.kits.count, CreationKind.kit.freeLimit)
        XCTAssertLessThanOrEqual(target.homes.count, CreationKind.home.freeLimit)
    }
}
