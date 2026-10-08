import XCTest

@MainActor final class LocaliserUITests: XCTestCase {
    func testSettingsExportsAndProAreReachable() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-library", UUID().uuidString]
        app.launch()
        for tab in ["Find", "Places", "Due soon", "Packing"] {
            app.tabBars.buttons[tab].tap()
            let image = XCTAttachment(screenshot: app.screenshot()); image.name = "Tab \(tab)"; image.lifetime = .keepAlways; add(image)
            try app.performAccessibilityAudit(for: [.elementDetection, .hitRegion, .sufficientElementDescription, .trait])
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
        try app.performAccessibilityAudit(for: [.elementDetection, .hitRegion, .sufficientElementDescription, .trait])
        app.buttons["Close"].tap()
        let csv = app.buttons["Export inventory CSV"]
        for _ in 0..<8 { if csv.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(csv.isHittable)
        let restoreFile = app.buttons["Export restorable backup"]
        for _ in 0..<8 { if restoreFile.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(restoreFile.isHittable)
        let backup = XCTAttachment(screenshot: app.screenshot()); backup.name = "Backup settings"; backup.lifetime = .keepAlways; add(backup)
        try app.performAccessibilityAudit(for: [.elementDetection, .hitRegion, .sufficientElementDescription, .trait])
    }

    func testLaunchTabsContrastAndClippingWithoutChangingTextSize() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-library", UUID().uuidString]
        app.launch()
        for tab in ["Find", "Places", "Due soon", "Packing"] {
            app.tabBars.buttons[tab].tap()
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = "Contrast and clipping audit \(tab)"
            screenshot.lifetime = .keepAlways
            add(screenshot)
            try app.performAccessibilityAudit(for: [.contrast, .textClipped])
        }
    }

    func testTypographyAccessibilityOnLaunchTabs() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-library", UUID().uuidString]
        app.launch()
        for tab in ["Find", "Places", "Due soon", "Packing"] {
            app.tabBars.buttons[tab].tap()
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = "Typography audit \(tab)"
            screenshot.lifetime = .keepAlways
            add(screenshot)
            try app.performAccessibilityAudit(for: [.contrast, .dynamicType, .textClipped])
        }
        app.tabBars.buttons["Find"].tap()
        app.buttons["Find options"].tap()
        app.buttons["Settings and backup"].tap()
        let pro = app.buttons["Purchase or restore lifetime Pro"]
        reveal(pro, in: app); pro.tap()
        reveal(app.buttons["Restore purchases"], in: app)
        let paywall = XCTAttachment(screenshot: app.screenshot())
        paywall.name = "Typography audit Pro"; paywall.lifetime = .keepAlways; add(paywall)
        try app.performAccessibilityAudit(for: [.contrast, .dynamicType, .textClipped])
        app.buttons["Close"].tap()
        reveal(app.buttons["Export restorable backup"], in: app)
        let settings = XCTAttachment(screenshot: app.screenshot())
        settings.name = "Typography audit Backup"; settings.lifetime = .keepAlways; add(settings)
        try app.performAccessibilityAudit(for: [.contrast, .dynamicType, .textClipped])
    }

    func testNameOnlyCaptureSurvivesRelaunchAndCanBeFound() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-library", UUID().uuidString]
        app.launch()
        app.tabBars.buttons["Due soon"].tap()
        let disabled = app.descendants(matching: .any).matching(identifier: "Open notification settings").firstMatch
        reveal(app.buttons["Enable notifications"], in: app)
        if !disabled.exists {
            app.buttons["Enable notifications"].tap()
            let deny = XCUIApplication(bundleIdentifier: "com.apple.springboard").buttons["Don’t Allow"]
            XCTAssertTrue(deny.waitForExistence(timeout: 5), app.debugDescription)
            deny.tap()
        }
        reveal(disabled, in: app)
        XCTAssertTrue(disabled.waitForExistence(timeout: 5))
        let denied = XCTAttachment(screenshot: app.screenshot()); denied.name = "Notifications denied"; denied.lifetime = .keepAlways; add(denied)
        app.tabBars.buttons["Find"].tap()
        app.buttons["Add item"].tap()
        let name = "Verification cable \(UUID().uuidString.prefix(8))"
        let field = app.textFields["item.name"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap(); field.typeText(name)
        app.buttons["item.save"].tap()
        XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 5))
        let screenshot = XCTAttachment(screenshot: app.screenshot()); screenshot.name = "Saved item"; screenshot.lifetime = .keepAlways; add(screenshot)
        app.staticTexts[name].tap()
        reveal(app.buttons["Add date"], in: app)
        app.buttons["Add date"].tap()
        let save = app.buttons["deadline.save"]
        XCTAssertTrue(save.waitForExistence(timeout: 5)); XCTAssertFalse(save.isEnabled)
        let confirmationSwitch = app.switches["deadline.confirm"]
        reveal(confirmationSwitch, in: app)
        confirmationSwitch.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        XCTAssertEqual(confirmationSwitch.value as? String, "1")
        let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: save)
        XCTAssertEqual(XCTWaiter.wait(for: [enabled], timeout: 5), .completed)
        let confirmation = XCTAttachment(screenshot: app.screenshot()); confirmation.name = "Date after confirmation"; confirmation.lifetime = .keepAlways; add(confirmation)
        save.tap()
        XCTAssertTrue(save.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Return deadline"].waitForExistence(timeout: 5))
        app.staticTexts["Return deadline"].tap()
        reveal(app.buttons["Add to Calendar"], in: app)
        app.buttons["Add to Calendar"].tap()
        let calendarTitle = app.textFields.matching(NSPredicate(format: "identifier == %@ OR label == %@", "title-field", "Title")).firstMatch
        XCTAssertTrue(calendarTitle.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertEqual(calendarTitle.value as? String, "Localiser: Return deadline")
        let calendar = XCTAttachment(screenshot: app.screenshot()); calendar.name = "Calendar event preview"; calendar.lifetime = .keepAlways; add(calendar)
        app.buttons["Cancel"].tap()
        let discard = app.buttons["Discard Changes"]
        if discard.waitForExistence(timeout: 2) { discard.tap() }
        XCTAssertTrue(app.navigationBars["New Event"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.navigationBars["Return deadline"].exists)
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
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-library", UUID().uuidString]
        app.launch()
        app.tabBars.buttons["Packing"].tap()
        reveal(app.buttons["New kit"], in: app)
        app.buttons["New kit"].tap()
        let kitName = "Travel kit \(UUID().uuidString.prefix(6))"
        app.textFields["kit.name"].tap(); app.textFields["kit.name"].typeText(kitName)
        app.buttons["kit.save"].tap()
        reveal(app.staticTexts[kitName], in: app)
        app.staticTexts[kitName].tap()
        reveal(app.buttons["Add packing row"], in: app)
        app.buttons["Add packing row"].tap()
        let rowName = "Clothes \(UUID().uuidString.prefix(6))"
        app.textFields["kit.entry.name"].tap(); app.textFields["kit.entry.name"].typeText(rowName)
        app.buttons["kit.entry.save"].tap()
        reveal(app.buttons["Create trip from this kit"], in: app)
        app.buttons["Create trip from this kit"].tap()
        let tripName = "Trip \(UUID().uuidString.prefix(6))"
        app.textFields["trip.name"].tap(); app.textFields["trip.name"].typeText(tripName)
        app.buttons["trip.save"].tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        reveal(app.staticTexts[tripName], in: app)
        app.staticTexts[tripName].tap()
        reveal(app.staticTexts[rowName], in: app)
        app.staticTexts[rowName].tap()
        reveal(app.buttons["Pack all"], in: app)
        app.buttons["Pack all"].tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        for title in ["Check appliances", "Lock doors", "Take keys"] {
            let toggle = app.switches[title]
            reveal(toggle, in: app)
            toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
            XCTAssertEqual(toggle.value as? String, "1")
        }
        reveal(app.buttons["Mark away"], in: app)
        app.buttons["Mark away"].tap()
        XCTAssertFalse(app.alerts["Could not update trip"].exists)
        reveal(app.staticTexts["Status: away"], in: app)
        XCTAssertTrue(app.staticTexts["Status: away"].exists)
        reveal(app.buttons["Start coming home"], in: app)
        app.buttons["Start coming home"].tap()
        reveal(app.staticTexts[rowName], in: app)
        app.staticTexts[rowName].tap()
        reveal(app.buttons["Confirm unpacked"], in: app)
        app.buttons["Confirm unpacked"].tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        reveal(app.buttons["Finish coming home"], in: app)
        app.buttons["Finish coming home"].tap()
        XCTAssertTrue(app.staticTexts["Status: finished"].waitForExistence(timeout: 5))
        let screenshot = XCTAttachment(screenshot: app.screenshot()); screenshot.name = "Completed packing cycle"; screenshot.lifetime = .keepAlways; add(screenshot)
    }

    func testPhotoScanNeedsConfirmationAndKeepsDateOnlyRecord() throws {
        #if targetEnvironment(simulator)
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-library", UUID().uuidString]
        app.launch()
        app.buttons["Scan"].tap()
        let choose = app.buttons["Choose a photo"]
        XCTAssertTrue(choose.waitForExistence(timeout: 5)); choose.tap()
        XCTAssertTrue(app.staticTexts["Loading..."].firstMatch.waitForNonExistence(timeout: 20))
        let picker = app.navigationBars["Photos"]
        XCTAssertTrue(picker.waitForExistence(timeout: 10))
        let onboardingClose = app.buttons["Close"].firstMatch
        if onboardingClose.exists { onboardingClose.tap() }
        // Seed Printed-expiry.png last, as documented in README. The picker lists newest first.
        let fixture = app.images["PXGGridLayout-Info"].firstMatch
        XCTAssertTrue(fixture.waitForExistence(timeout: 10))
        fixture.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(picker.waitForNonExistence(timeout: 10))
        let candidate = app.buttons.containing(.staticText, identifier: "2028-07-14").firstMatch
        reveal(candidate, in: app)
        XCTAssertTrue(candidate.waitForExistence(timeout: 5), app.debugDescription); candidate.tap()
        let name = "Expiry document \(UUID().uuidString.prefix(6))"
        let nameField = app.textFields["Or name a new item"]
        reveal(nameField, in: app); nameField.tap(); nameField.typeText(name + "\n")
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
        reveal(app.buttons["Create item"], in: app); app.buttons["Create item"].tap()
        reveal(app.buttons["Review and confirm date"], in: app)
        app.buttons["Review and confirm date"].tap()
        let save = app.buttons["deadline.save"]
        XCTAssertTrue(save.waitForExistence(timeout: 5)); XCTAssertFalse(save.isEnabled)
        let original = app.switches["Keep original document"]
        reveal(original, in: app); XCTAssertEqual(original.value as? String, "0")
        let confirmation = app.switches["deadline.confirm"]
        reveal(confirmation, in: app)
        confirmation.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        XCTAssertEqual(confirmation.value as? String, "1"); XCTAssertTrue(save.isEnabled)
        save.tap()
        XCTAssertTrue(app.navigationBars["Localiser"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 5)); app.staticTexts[name].tap()
        reveal(app.staticTexts["Expiry"], in: app)
        XCTAssertTrue(app.staticTexts["Expiry"].exists)
        XCTAssertTrue(app.staticTexts["Expiry, Jul 14, 2028"].exists, app.debugDescription)
        reveal(app.staticTexts["Date-only scan"], in: app); app.staticTexts["Date-only scan"].tap()
        XCTAssertTrue(app.staticTexts["The original is not retained. Your saved dates remain with the item."].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Remove original document"].exists)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Confirmed date-only photo scan"; screenshot.lifetime = .keepAlways; add(screenshot)
        #else
        throw XCTSkip("This automated photo workflow uses the documented synthetic simulator fixture. Physical camera/photo verification requires owner interaction.")
        #endif
    }

    func testPDFImportNeedsConfirmationAndRetainsOriginal() throws {
        #if targetEnvironment(simulator)
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-library", UUID().uuidString]
        app.launch()
        app.buttons["Scan"].tap()
        app.buttons["Import PDF or image"].tap()
        let browse = app.buttons["Browse"].firstMatch
        if browse.waitForExistence(timeout: 5) { browse.tap() }
        let local = app.staticTexts["On My iPhone"].firstMatch
        if local.waitForExistence(timeout: 5) { local.tap() }
        let document = app.cells["Localiser-test-expiry, pdf"].firstMatch
        XCTAssertTrue(document.waitForExistence(timeout: 10), app.debugDescription)
        document.tap()
        let candidate = app.buttons.containing(.staticText, identifier: "2028-07-14").firstMatch
        reveal(candidate, in: app); candidate.tap()
        let name = "PDF expiry \(UUID().uuidString.prefix(6))"
        let field = app.textFields["Or name a new item"]
        reveal(field, in: app); field.tap(); field.typeText(name + "\n")
        reveal(app.buttons["Create item"], in: app); app.buttons["Create item"].tap()
        reveal(app.buttons["Review and confirm date"], in: app); app.buttons["Review and confirm date"].tap()
        let save = app.buttons["deadline.save"]
        XCTAssertTrue(save.waitForExistence(timeout: 5)); XCTAssertFalse(save.isEnabled)
        let retain = app.switches["Keep original document"]
        reveal(retain, in: app); XCTAssertEqual(retain.value as? String, "0")
        retain.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        XCTAssertEqual(retain.value as? String, "1")
        let confirm = app.switches["deadline.confirm"]
        reveal(confirm, in: app); confirm.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        XCTAssertEqual(confirm.value as? String, "1"); XCTAssertTrue(save.isEnabled); save.tap()
        XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 10)); app.staticTexts[name].tap()
        reveal(app.staticTexts["Expiry, Jul 14, 2028"], in: app)
        XCTAssertTrue(app.staticTexts["Expiry, Jul 14, 2028"].exists)
        let retained = app.staticTexts["Localiser-test-expiry.pdf"]
        reveal(retained, in: app); retained.tap()
        XCTAssertTrue(app.buttons["Remove original document"].waitForExistence(timeout: 5))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Retained imported PDF"; screenshot.lifetime = .keepAlways; add(screenshot)
        #else
        throw XCTSkip("This import check uses the documented synthetic simulator PDF. Physical Files-provider verification requires owner interaction.")
        #endif
    }

    func testBackupExportsAndRestoresIntoFreshLibrary() throws {
        #if targetEnvironment(simulator)
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-library", UUID().uuidString]
        app.launch()
        app.buttons["Add item"].tap()
        let name = "Recovery item \(UUID().uuidString.prefix(8))"
        let field = app.textFields["item.name"]
        XCTAssertTrue(field.waitForExistence(timeout: 5)); field.tap(); field.typeText(name)
        app.buttons["item.save"].tap()
        XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 5))
        app.buttons["Find options"].tap(); app.buttons["Settings and backup"].tap()
        let export = app.buttons["Export restorable backup"]
        reveal(export, in: app); export.tap()
        XCTAssertTrue(app.buttons["Save"].waitForExistence(timeout: 10), app.debugDescription)
        // A dedicated folder keeps repeated recovery checks from replacing an earlier export.
        app.buttons["More"].tap(); app.buttons["New Folder"].tap()
        let folder = app.textViews["DOC.inlineRenameField"]
        XCTAssertTrue(folder.waitForExistence(timeout: 5), app.debugDescription)
        let folderName = "Recovery-\(UUID().uuidString.prefix(8))"
        folder.typeText(folderName)
        app.keyboards.buttons["Done"].tap()
        let destination = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", folderName)).firstMatch
        XCTAssertTrue(destination.waitForExistence(timeout: 5), app.debugDescription)
        let backupName = "Localiser-backup"
        app.buttons["Save"].tap()
        XCTAssertTrue(app.buttons["Save"].waitForNonExistence(timeout: 10), app.debugDescription)
        app.terminate()
        app.launchArguments = ["--ui-test-library", UUID().uuidString]
        app.launch()
        XCTAssertFalse(app.staticTexts[name].exists)
        app.buttons["Find options"].tap(); app.buttons["Settings and backup"].tap()
        let chooseBackup = app.buttons["Choose Localiser backup"]
        reveal(chooseBackup, in: app); chooseBackup.tap()
        let savedFile = app.cells["\(backupName).json, json"].firstMatch
        XCTAssertTrue(savedFile.waitForExistence(timeout: 10), app.debugDescription); savedFile.tap()
        let confirmation = app.alerts["Restore backup?"]
        XCTAssertTrue(confirmation.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(confirmation.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "1 records from")).firstMatch.exists)
        confirmation.buttons["Restore"].tap()
        app.buttons["Done"].tap()
        XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 5), app.debugDescription)
        app.terminate(); app.launch()
        XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 5))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Backup restored into fresh library"; screenshot.lifetime = .keepAlways; add(screenshot)
        #else
        throw XCTSkip("This recovery UI test writes synthetic data only in a dedicated simulator. Physical file-provider verification requires owner interaction.")
        #endif
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        for _ in 0..<16 {
            XCTAssertFalse(app.alerts.firstMatch.exists, "An unexpected alert prevents this workflow.", file: file, line: line)
            let bounds = app.frame
            let tabBar = app.tabBars.firstMatch
            let bottom = tabBar.isHittable ? tabBar.frame.minY : bounds.maxY - 20
            if element.exists {
                let middle = element.frame.midY
                if element.isHittable && middle > bounds.minY + 100 && middle < bottom - 10 { return }
                let moveDown = middle <= bounds.minY + 100
                let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6))
                let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: moveDown ? 0.8 : 0.4))
                start.press(forDuration: 0.05, thenDragTo: end)
                continue
            }
            app.swipeUp()
        }
        for _ in 0..<16 {
            if element.isHittable && element.frame.midY > app.frame.minY + 100 && element.frame.midY < app.frame.maxY - 40 { return }
            app.swipeDown()
        }
        XCTFail("Could not reach \(element)\n\(app.debugDescription)", file: file, line: line)
    }

}
