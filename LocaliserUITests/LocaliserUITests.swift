import XCTest

@MainActor final class LocaliserUITests: XCTestCase {
    func testSettingsExportsAndProAreReachable() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-library", UUID().uuidString]
        app.launch()
        for tab in ["Find", "Places", "Due soon", "Packing"] {
            app.tabBars.buttons[tab].tap()
            let image = XCTAttachment(screenshot: app.screenshot()); image.name = "Tab \(tab)"; image.lifetime = .keepAlways; add(image)
        }
        app.tabBars.buttons["Find"].tap()
        app.buttons["Find options"].tap()
        app.buttons["Settings and backup"].tap()
        let pro = app.buttons["Purchase or restore lifetime Pro"]
        XCTAssertTrue(pro.waitForExistence(timeout: 5)); pro.tap()
        let restorePurchase = app.buttons["Restore purchases"]
        for _ in 0..<8 { if restorePurchase.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(restorePurchase.isHittable)
        let paywall = XCTAttachment(screenshot: app.screenshot()); paywall.name = "Lifetime Pro"; paywall.lifetime = .keepAlways; add(paywall)
        app.buttons["Close"].tap()
        let csv = app.buttons["Export inventory CSV"]
        for _ in 0..<8 { if csv.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(csv.isHittable)
        let restoreFile = app.buttons["Export restorable backup"]
        for _ in 0..<8 { if restoreFile.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(restoreFile.isHittable)
        let backup = XCTAttachment(screenshot: app.screenshot()); backup.name = "Backup settings"; backup.lifetime = .keepAlways; add(backup)
    }

    func testNameOnlyCaptureSurvivesRelaunchAndCanBeFound() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-library", UUID().uuidString]
        app.launch()
        app.buttons["Add item"].tap()
        let name = "Verification cable \(UUID().uuidString.prefix(8))"
        let field = app.textFields["item.name"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap(); field.typeText(name)
        app.buttons["item.save"].tap()
        XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 5))
        let screenshot = XCTAttachment(screenshot: app.screenshot()); screenshot.name = "Saved item"; screenshot.lifetime = .keepAlways; add(screenshot)
        app.staticTexts[name].tap()
        app.buttons["Add date"].tap()
        let save = app.buttons["deadline.save"]
        XCTAssertTrue(save.waitForExistence(timeout: 5)); XCTAssertFalse(save.isEnabled)
        app.swipeUp()
        let confirmationSwitch = app.switches["deadline.confirm"]
        confirmationSwitch.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        XCTAssertEqual(confirmationSwitch.value as? String, "1")
        let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: save)
        XCTAssertEqual(XCTWaiter.wait(for: [enabled], timeout: 5), .completed)
        let confirmation = XCTAttachment(screenshot: app.screenshot()); confirmation.name = "Date after confirmation"; confirmation.lifetime = .keepAlways; add(confirmation)
        save.tap()
        XCTAssertTrue(save.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Return deadline"].waitForExistence(timeout: 5))
        app.staticTexts["Return deadline"].tap()
        app.buttons["Add to Calendar"].tap()
        XCTAssertTrue(app.textFields["Title"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertEqual(app.textFields["Title"].value as? String, "Localiser: Return deadline")
        let calendar = XCTAttachment(screenshot: app.screenshot()); calendar.name = "Calendar event preview"; calendar.lifetime = .keepAlways; add(calendar)
        app.buttons["Cancel"].tap()
        let discard = app.buttons["Discard Changes"]
        XCTAssertTrue(discard.waitForExistence(timeout: 5), app.debugDescription)
        discard.tap()
        XCTAssertTrue(app.navigationBars["New Event"].waitForNonExistence(timeout: 5))
        let deleteDate = app.buttons["Delete date"].firstMatch
        for _ in 0..<5 { if deleteDate.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(deleteDate.isHittable); deleteDate.tap()
        app.sheets.buttons["Delete date"].tap()
        XCTAssertTrue(app.buttons["Add date"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Return deadline"].exists)
        app.terminate(); app.launch()
        app.tabBars.buttons["Find"].tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap(); search.typeText(name)
        XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 5))
        app.staticTexts[name].tap()
        let remove = app.buttons["Delete item permanently"].firstMatch
        for _ in 0..<5 { if remove.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(remove.isHittable); remove.tap()
        app.sheets.buttons["Delete item permanently"].tap()
        XCTAssertTrue(app.navigationBars["Localiser"].waitForExistence(timeout: 5))
    }

    func testKitTripPackingAndComingHome() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-library", UUID().uuidString]
        app.launch()
        app.tabBars.buttons["Packing"].tap()
        app.buttons["New kit"].tap()
        let kitName = "Travel kit \(UUID().uuidString.prefix(6))"
        app.textFields["kit.name"].tap(); app.textFields["kit.name"].typeText(kitName)
        app.buttons["kit.save"].tap()
        app.staticTexts[kitName].tap()
        app.buttons["Add packing row"].tap()
        let rowName = "Clothes \(UUID().uuidString.prefix(6))"
        app.textFields["kit.entry.name"].tap(); app.textFields["kit.entry.name"].typeText(rowName)
        app.buttons["kit.entry.save"].tap()
        app.buttons["Create trip from this kit"].tap()
        let tripName = "Trip \(UUID().uuidString.prefix(6))"
        app.textFields["trip.name"].tap(); app.textFields["trip.name"].typeText(tripName)
        app.buttons["trip.save"].tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.staticTexts[tripName].tap()
        app.staticTexts[rowName].tap()
        app.buttons["Pack all"].tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        for title in ["Check appliances", "Lock doors", "Take keys"] { app.switches[title].tap() }
        app.buttons["Mark away"].tap()
        app.buttons["Start coming home"].tap()
        app.staticTexts[rowName].tap()
        app.buttons["Confirm unpacked"].tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["Finish coming home"].tap()
        XCTAssertTrue(app.staticTexts["Status: finished"].waitForExistence(timeout: 5))
        let screenshot = XCTAttachment(screenshot: app.screenshot()); screenshot.name = "Completed packing cycle"; screenshot.lifetime = .keepAlways; add(screenshot)
    }
}
