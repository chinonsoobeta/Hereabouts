import XCTest
@testable import Localiser

extension AuditCodexTests {
    func testRestoredNotesRemainEditableWithoutDeletingExistingText() throws {
        let source = try LocaliserStore(inMemory: true)
        let item = try source.addItem(name: "Camera")
        var file = try source.backup()
        let index = try XCTUnwrap(file.records.firstIndex { $0.id == item.id })
        file.records[index].attributes["notes"] = .string(String(repeating: "a", count: TextLimit.notes + 1))
        let target = try LocaliserStore(inMemory: true)
        do { try target.restore(try LibraryBackup.decoded(file.encoded())) }
        catch let error as LocaliserError {
            if case .invalidBackup = error { return }
            throw error
        }
        let restored = try XCTUnwrap(target.items.first { $0.id == item.id })
        XCTAssertNoThrow(try target.editItem(restored, name: "Renamed camera", place: restored.place,
                                            notes: restored.notes, aliases: restored.aliases, photo: restored.photo),
                         "An accepted backup must not require deleting notes before an unrelated edit can be saved")
    }
}
