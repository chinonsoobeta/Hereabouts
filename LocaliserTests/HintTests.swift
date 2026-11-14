import XCTest
@testable import Localiser

/// One-time hints are cards in the list with their own buttons, never bubbles hanging from the top of the screen (owner, 14 November).
final class HintTests: XCTestCase {
    private func freshDefaults() throws -> UserDefaults {
        try XCTUnwrap(UserDefaults(suiteName: "HintTests.\(UUID().uuidString)"))
    }

    func testEachHintShowsUntilItIsDismissedOrUsed() throws {
        let defaults = try freshDefaults()
        XCTAssertTrue(Hint.allCases.allSatisfy { $0.isShown(in: defaults) }, "Every hint starts out showing")
        Hint.putAway.dismiss(in: defaults)
        XCTAssertFalse(Hint.putAway.isShown(in: defaults), "Dismissed, or turned on, it stays gone")
        XCTAssertTrue(Hint.move.isShown(in: defaults), "Dismissing one leaves the others")
        XCTAssertTrue(Hint.leaving.isShown(in: defaults))
        XCTAssertEqual(Set(Hint.allCases.map(\.key)).count, Hint.allCases.count)
    }

    func testPutAwayIsSuggestedOnceThereAreAFewThingsToPutAway() throws {
        let defaults = try freshDefaults()
        XCTAssertFalse(Hint.suggestsPutAway(itemCount: 4, putAwayOn: false, in: defaults), "Not with only a few things")
        XCTAssertTrue(Hint.suggestsPutAway(itemCount: 5, putAwayOn: false, in: defaults))
        XCTAssertFalse(Hint.suggestsPutAway(itemCount: 5, putAwayOn: true, in: defaults), "Not while it's already on")
        Hint.putAway.dismiss(in: defaults)
        XCTAssertFalse(Hint.suggestsPutAway(itemCount: 50, putAwayOn: false, in: defaults))
    }

    func testNoHintIsABubbleFromTheTopOfTheScreen() throws {
        let app = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Localiser")
        let files = try XCTUnwrap(FileManager.default.enumerator(at: app, includingPropertiesForKeys: nil)).compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
        XCTAssertFalse(files.isEmpty)
        for file in files {
            let source = try String(contentsOf: file, encoding: .utf8)
            for bubble in ["popoverTip(", "TipView(", "import TipKit"] {
                XCTAssertFalse(source.contains(bubble), "\(file.lastPathComponent) uses \(bubble)")
            }
        }
    }
}
