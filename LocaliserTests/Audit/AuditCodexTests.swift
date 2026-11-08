import XCTest
@testable import Localiser

@MainActor
final class AuditCodexTests: XCTestCase {
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

    func testBlankShortcutSearchDoesNotDisclosePrivateNames() async throws {
        let store = try LocaliserStore(inMemory: true)
        let visible = try store.addItem(name: "Kettle")
        let secret = try store.addItem(name: "Recovery codes", isPrivate: true)
        let previous = IntentLibrary.store
        IntentLibrary.store = store
        defer { IntentLibrary.store = previous }

        for query in ["", " \t\n"] {
            let entities = try await ThingQuery().entities(matching: query)
            XCTAssertTrue(entities.contains { $0.id == visible.id })
            XCTAssertFalse(entities.contains { $0.id == secret.id },
                           "A blank query must not enumerate private thing names in Shortcuts")
        }
    }
}
