import XCTest

@MainActor final class LocaliserUITests: XCTestCase {
    func testNameOnlyCaptureSurvivesRelaunchAndCanBeFound() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Add item"].tap()
        let name = "Verification cable \(UUID().uuidString.prefix(8))"
        let field = app.textFields["item.name"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap(); field.typeText(name)
        app.buttons["item.save"].tap()
        XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 5))
        app.terminate(); app.launch()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap(); search.typeText(name)
        XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 5))
    }
}
