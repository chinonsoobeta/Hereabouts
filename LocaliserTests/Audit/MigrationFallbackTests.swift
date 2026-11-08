import XCTest
import CoreData
@testable import Localiser

extension AuditCodexTests {
    func testMigrationFallbackEditsSurviveAStaleGroupCopyReturning() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let legacy = folder.appendingPathComponent("Old/Localiser.sqlite")
        let group = folder.appendingPathComponent("Group/Localiser.sqlite")
        let suite = "MigrationAudit.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        func close(_ store: LocaliserStore) throws {
            store.context.reset()
            for file in store.container.persistentStoreCoordinator.persistentStores {
                try store.container.persistentStoreCoordinator.remove(file)
            }
        }
        let original = try LocaliserStore(url: legacy)
        try original.addItem(name: "Passport")
        let snapshot = try original.backup()
        try close(original)
        XCTAssertEqual(NotebookFile.location(legacy: legacy, group: group, defaults: defaults), group)

        // The first launch completed the copy; before the next launch its files went missing.
        let model = try XCTUnwrap(LocaliserModel.shared)
        try NSPersistentStoreCoordinator(managedObjectModel: model)
            .destroyPersistentStore(at: group, type: .sqlite, options: nil)
        for suffix in ["", "-wal", "-shm"] {
            try? FileManager.default.removeItem(atPath: group.path + suffix)
        }
        XCTAssertEqual(NotebookFile.location(legacy: legacy, group: group, defaults: defaults), legacy)
        let recovered = try LocaliserStore(url: legacy)
        try recovered.addItem(name: "Wallet added after recovery")
        try close(recovered)

        // Reproduce a readable but stale shared copy reappearing after fallback was used.
        let stale = try LocaliserStore(url: group)
        try stale.restore(snapshot)
        try close(stale)
        let selected = NotebookFile.location(legacy: legacy, group: group, defaults: defaults)
        let reopened = try LocaliserStore(url: selected)
        defer { try? close(reopened) }
        XCTAssertEqual(Set(reopened.items.map(\.name)), ["Passport", "Wallet added after recovery"],
                       "Recovery must not discard edits and delete the only notebook containing them")
    }
}
