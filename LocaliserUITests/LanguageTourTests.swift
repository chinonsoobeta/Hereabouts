import XCTest

/// Screenshot tour of every tab, Settings, Pro and the introduction in each language, at the default
/// and the largest text size (M63). Runs only when TOUR_DIR is set, e.g. TEST_RUNNER_TOUR_DIR=/path xcodebuild ...
final class LanguageTourTests: XCTestCase {
    static let languages: [(folder: String, language: String, locale: String)] = [
        ("en-GB", "en-GB", "en_GB"), ("fr", "fr", "fr_FR"), ("es", "es", "es_ES"), ("pt-BR", "pt-BR", "pt_BR")]
    static let sizes = [("default", "UICTContentSizeCategoryL"), ("largest", "UICTContentSizeCategoryAccessibilityXXXL")]

    func testLanguageTour() throws {
        guard let root = ProcessInfo.processInfo.environment["TOUR_DIR"], !root.isEmpty else { throw XCTSkip("Set TOUR_DIR to take the language tour") }
        let only = ProcessInfo.processInfo.environment["TOUR_LANG"]
        for entry in Self.languages where only == nil || only == entry.folder {
            let folder = URL(fileURLWithPath: root).appendingPathComponent(entry.folder)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            for (sizeName, size) in Self.sizes {
                tour(entry.language, entry.locale, size: size) { name, app in
                    let data = app.screenshot().pngRepresentation
                    try? data.write(to: folder.appendingPathComponent("\(sizeName)-\(name).png"))
                }
            }
        }
    }

    private func launch(_ language: String, _ locale: String, size: String, extra: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(\(language))", "-AppleLocale", locale, "-UIPreferredContentSizeCategoryName", size,
                               "--ui-test-library", UUID().uuidString] + extra
        app.launch()
        return app
    }

    private func tour(_ language: String, _ locale: String, size: String, shot: (String, XCUIApplication) -> Void) {
        // Introduction, first page.
        var app = launch(language, locale, size: size, extra: ["--show-onboarding"])
        sleep(2); shot("1-introduction", app)
        app.terminate()

        // Tabs, Settings and Pro with the demo notebook.
        app = launch(language, locale, size: size, extra: ["--demo-library"])
        let tabs = app.tabBars.buttons
        XCTAssertTrue(tabs.firstMatch.waitForExistence(timeout: 10))
        sleep(1); shot("2-find", app)
        tabs.element(boundBy: 1).tap(); sleep(1); shot("3-places", app)
        tabs.element(boundBy: 2).tap(); sleep(1); shot("4-trips", app)
        tabs.element(boundBy: 3).tap(); sleep(1); shot("5-settings", app)
        app.swipeUp(); sleep(1); shot("6-settings-more", app)
        app.swipeUp(); app.swipeUp(); sleep(1); shot("7-settings-end", app)
        app.swipeDown(); app.swipeDown(); app.swipeDown(); app.swipeDown()
        let pro = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Hereabouts Pro")).firstMatch
        if pro.waitForExistence(timeout: 5) {
            pro.tap(); sleep(2); shot("8-pro", app)
            app.swipeUp(); sleep(1); shot("9-pro-more", app)
        }
        app.terminate()
    }
}
