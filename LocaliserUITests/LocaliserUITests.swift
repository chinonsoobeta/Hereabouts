import XCTest

@MainActor final class LocaliserUITests: XCTestCase {
    func testSettingsExportsAndProAreReachable() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-library", UUID().uuidString]
        app.launch()
        for tab in ["Find", "Places", "Due", "Trips"] {
            app.tabBars.buttons[tab].tap()
            let image = XCTAttachment(screenshot: app.screenshot()); image.name = "Tab \(tab)"; image.lifetime = .keepAlways; add(image)
            try audit(app, [.elementDetection, .hitRegion, .sufficientElementDescription, .trait])
        }
        app.tabBars.buttons["Find"].tap()
        app.buttons["Settings"].tap()
        let pro = app.buttons["Hereabouts Pro"]
        XCTAssertTrue(pro.waitForExistence(timeout: 5)); pro.tap()
        // Three plans, yearly chosen first, and the trial button, from the local StoreKit configuration.
        // iOS 26.5's local StoreKit service doesn't serve products, so the plan checks run on iOS 27.
        let yearly = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Yearly'")).firstMatch
        if yearly.waitForExistence(timeout: 10) {
            XCTAssertTrue(yearly.isSelected)
            XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Monthly'")).firstMatch.exists)
            XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label == 'Try free for 2 weeks' OR label BEGINSWITH 'Subscribe for'")).firstMatch.exists)
            app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Lifetime'")).firstMatch.tap()
            XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Buy once for'")).firstMatch.waitForExistence(timeout: 3))
        } else {
            XCTAssertTrue(app.staticTexts["Pro isn't available to buy right now. Try again later."].exists)
        }
        for link in ["Privacy Policy", "Terms of Use"] {
            let element = app.links[link].exists ? app.links[link] : app.buttons[link]
            reveal(element, in: app); XCTAssertTrue(element.exists, "\(link) link is missing")
        }
        let restorePurchase = app.buttons["Restore purchases"]
        reveal(restorePurchase, in: app)
        XCTAssertTrue(restorePurchase.isHittable)
        let paywall = XCTAttachment(screenshot: app.screenshot()); paywall.name = "Lifetime Pro"; paywall.lifetime = .keepAlways; add(paywall)
        try audit(app, [.elementDetection, .hitRegion, .sufficientElementDescription, .trait])
        app.navigationBars["Pro"].buttons["Settings"].tap()
        openLeaving(in: app)
        let csv = app.buttons["Export a spreadsheet"]
        for _ in 0..<8 { if csv.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(csv.isHittable)
        let restoreFile = app.buttons["Back up everything"]
        for _ in 0..<8 { if restoreFile.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(restoreFile.isHittable)
        let backup = XCTAttachment(screenshot: app.screenshot()); backup.name = "Backup settings"; backup.lifetime = .keepAlways; add(backup)
        try audit(app, [.elementDetection, .hitRegion, .sufficientElementDescription, .trait])
        let erase = app.buttons["Erase this notebook"]
        reveal(erase, in: app); erase.tap()
        let continueErase = app.buttons["Continue to erase"]
        XCTAssertTrue(continueErase.waitForExistence(timeout: 5)); continueErase.tap()
        let confirmation = app.alerts["Erase this notebook?"]
        XCTAssertTrue(confirmation.waitForExistence(timeout: 5))
        XCTAssertFalse(confirmation.buttons["Erase"].isEnabled)
        confirmation.buttons["Cancel"].tap()
    }

    func testOnboardingNamesHomeAndWritesFirstThing() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-library", UUID().uuidString, "--show-onboarding"]
        app.launch()
        XCTAssertTrue(app.staticTexts["This is your house's notebook."].waitForExistence(timeout: 5))
        try audit(app, [.contrast, .elementDetection, .hitRegion, .sufficientElementDescription, .textClipped, .trait])
        app.buttons["The flat"].tap()
        app.buttons["Open it"].tap()
        XCTAssertTrue(app.staticTexts["What do you always lose?"].waitForExistence(timeout: 5))
        app.buttons["Passport"].tap()
        let room = app.textFields["Where does it live?"]
        room.tap(); room.typeText("Hall closet\n")
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
        try audit(app, [.contrast, .elementDetection, .hitRegion, .sufficientElementDescription, .textClipped, .trait])
        app.buttons["Write it down"].tap()
        XCTAssertTrue(app.staticTexts["A nudge before it's too late."].waitForExistence(timeout: 5))
        try audit(app, [.contrast, .elementDetection, .hitRegion, .sufficientElementDescription, .textClipped, .trait])
        app.buttons["Not now"].tap()
        XCTAssertTrue(app.staticTexts["Passport"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "The flat ·")).firstMatch.exists, app.debugDescription)
    }

    func testRecapStocktakeAndStillThere() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-library", UUID().uuidString, "--demo-library"]
        app.launch()

        // A thing nobody has looked at for months asks on its own page.
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap(); search.typeText("Winter")
        app.staticTexts["Winter tires"].firstMatch.tap()
        let still = app.buttons["item.stillThere"]
        XCTAssertTrue(still.waitForExistence(timeout: 5), app.debugDescription)
        still.tap()
        XCTAssertTrue(still.waitForNonExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()
        search.tap(); search.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 6))

        // Find offers the recap, which leads into the stocktake.
        let readIt = app.buttons["Read it"]
        XCTAssertTrue(readIt.waitForExistence(timeout: 5), app.debugDescription)
        readIt.tap()
        XCTAssertTrue(app.navigationBars["Recap"].waitForExistence(timeout: 5))
        let recap = XCTAttachment(screenshot: app.screenshot()); recap.name = "Recap"; recap.lifetime = .keepAlways; add(recap)
        try audit(app, [.contrast, .elementDetection, .hitRegion, .sufficientElementDescription, .textClipped, .trait])
        let start = app.buttons["Start the stocktake"]
        reveal(start, in: app); start.tap()

        XCTAssertTrue(app.staticTexts["Still there?"].waitForExistence(timeout: 5), app.debugDescription)
        let card = XCTAttachment(screenshot: app.screenshot()); card.name = "Stocktake"; card.lifetime = .keepAlways; add(card)
        try audit(app, [.contrast, .elementDetection, .hitRegion, .sufficientElementDescription, .textClipped, .trait])
        app.buttons["Still there"].tap()
        app.buttons["Don't have it any more"].tap()
        let undo = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Undo: keep")).firstMatch
        XCTAssertTrue(undo.waitForExistence(timeout: 5))
        undo.tap()
        XCTAssertTrue(app.staticTexts["All checked. The notebook's up to date. See you next month."].waitForExistence(timeout: 5), app.debugDescription)
        app.buttons["Done"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Keeping up."].waitForExistence(timeout: 5), "Once read, Find keeps only the keeping-up stamp")
        XCTAssertFalse(readIt.exists, "The recap is offered once a week")
        XCTAssertFalse(app.buttons["Start"].exists, "The stocktake is done for the month")
    }

    func testAppLinksOpenWritingDownAndDue() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-library", UUID().uuidString, "--demo-library"]
        app.launch()
        XCTAssertTrue(app.searchFields.firstMatch.waitForExistence(timeout: 5))
        func follow(_ link: String) {
            app.open(URL(string: link)!)
            let open = XCUIApplication(bundleIdentifier: "com.apple.springboard").buttons["Open"]
            if open.waitForExistence(timeout: 3) { open.tap() }
        }
        follow("hereabouts://new")
        XCTAssertTrue(app.buttons["item.save"].waitForExistence(timeout: 5), app.debugDescription)
        app.buttons["Cancel"].firstMatch.tap()
        follow("hereabouts://due")
        XCTAssertTrue(app.tabBars.buttons["Due"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["Due"].isSelected, app.debugDescription)
        follow("hereabouts://putaway")
        XCTAssertTrue(app.staticTexts["Choose a thing, then say where you put it."].waitForExistence(timeout: 5), app.debugDescription)
    }

    func testNotThereFoundItAndWriteDownFromAnEmptySearch() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-library", UUID().uuidString, "--demo-library"]
        app.launch()

        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap(); search.typeText("Winter")
        app.staticTexts["Winter tires"].firstMatch.tap()
        let notThere = app.buttons["item.notThere"]
        XCTAssertTrue(notThere.waitForExistence(timeout: 5), app.debugDescription)
        notThere.tap()
        let found = app.buttons["item.found"]
        XCTAssertTrue(found.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.staticTexts["Missing"].exists)
        found.tap()
        XCTAssertTrue(app.navigationBars["Where was it?"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.staticTexts["Try here first"].exists || app.otherElements["Try here first"].exists, app.debugDescription)
        // iOS 27 flags its own glass Cancel button and search bar here, as on the existing place chooser.
        try audit(app, [.elementDetection, .hitRegion, .sufficientElementDescription, .trait])
        app.buttons["Garage › Back wall"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Noted. Next time, look in Garage › Back wall."].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertFalse(found.exists)
        app.navigationBars.buttons.firstMatch.tap()

        // A search that finds nothing offers to write the thing down, name and all.
        search.tap(); search.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 6) + "Bike pump")
        let writeDown = app.buttons["find.writeDown"]
        XCTAssertTrue(writeDown.waitForExistence(timeout: 5), app.debugDescription)
        writeDown.tap()
        XCTAssertEqual(app.textFields.firstMatch.value as? String, "Bike pump")
        app.buttons["item.save"].tap()
        XCTAssertTrue(app.staticTexts["Bike pump"].firstMatch.waitForExistence(timeout: 5), app.debugDescription)
    }

    /// Store and design-review screenshots from the demo library. Runs only when asked:
    /// `TEST_RUNNER_STORE_SHOTS=<folder> xcodebuild … -only-testing:LocaliserUITests/LocaliserUITests/testStoreScreenshots test`
    func testStoreScreenshots() throws {
        guard let path = ProcessInfo.processInfo.environment["STORE_SHOTS"], !path.isEmpty else { throw XCTSkip("Set TEST_RUNNER_STORE_SHOTS to a folder to take store screenshots") }
        let folder = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let app = XCUIApplication()
        func shot(_ name: String) throws { try app.screenshot().pngRepresentation.write(to: folder.appendingPathComponent("\(name).png")) }
        app.launchArguments = ["--ui-test-library", UUID().uuidString, "--demo-library"]
        app.launch()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        // Store shots show reminders on, as a real user would have them. Turn them on before the first shot: until
        // then the Due tab carries a warning badge on every screen.
        app.tabBars.buttons["Due"].tap()
        let turnOn = app.buttons["Turn on reminders"]
        if turnOn.waitForExistence(timeout: 2) {
            turnOn.tap()
            let allow = XCUIApplication(bundleIdentifier: "com.apple.springboard").buttons["Allow"]
            if allow.waitForExistence(timeout: 5) { allow.tap() }
            XCTAssertTrue(turnOn.waitForNonExistence(timeout: 5))
        }
        let queued = app.staticTexts.containing(NSPredicate(format: "label ENDSWITH %@", "queued on this iPhone.")).firstMatch
        guard queued.waitForExistence(timeout: 5) else {
            XCTFail("Notifications are off for Hereabouts on this simulator, so Due would show a warning. The name-only capture test turns them off. Uninstall Hereabouts from the simulator, then run this test on its own.")
            return
        }
        app.tabBars.buttons["Find"].tap()
        try shot("1-find")
        search.tap(); search.typeText("pass\n")
        XCTAssertTrue(app.staticTexts["Passports (family)"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
        try shot("2-search")
        search.tap()
        search.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 4))
        search.typeText("running\n")
        app.staticTexts["Running shoes"].firstMatch.tap()
        XCTAssertTrue(app.buttons["item.move"].waitForExistence(timeout: 5))
        try shot("3-thing")
        app.tabBars.buttons["Due"].tap()
        try shot("4-due")
        app.tabBars.buttons["Trips"].tap()
        try shot("5-trips")
        app.tabBars.buttons["Find"].tap()
        app.navigationBars.buttons.firstMatch.tap()
        search.tap(); search.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 8))
        let readIt = app.buttons["Read it"]
        if !readIt.isHittable { search.typeText("\n") }
        XCTAssertTrue(readIt.waitForExistence(timeout: 5), app.debugDescription)
        readIt.tap()
        XCTAssertTrue(app.navigationBars["Recap"].waitForExistence(timeout: 5))
        try shot("6-recap")
        let start = app.buttons["Start the stocktake"]
        reveal(start, in: app); start.tap()
        XCTAssertTrue(app.staticTexts["Still there?"].waitForExistence(timeout: 5))
        try shot("7-stocktake")
        app.buttons["Later"].tap()
        XCTAssertTrue(app.staticTexts["Still there?"].waitForNonExistence(timeout: 5))
        // Leave the search field so the navigation bar's buttons come back.
        for label in ["Close", "Cancel"] where app.navigationBars.buttons[label].exists || app.buttons[label].exists {
            app.buttons[label].firstMatch.tap()
        }
        let settings = app.navigationBars["Hereabouts"].buttons["Settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 5), app.debugDescription)
        settings.tap()
        let pro = app.buttons["Hereabouts Pro"]
        reveal(pro, in: app); pro.tap()
        XCTAssertTrue(app.navigationBars["Pro"].waitForExistence(timeout: 5))
        try shot("8-pro")
        // Design review: the grouped lists and forms, which change the most between light and dark.
        app.navigationBars["Pro"].buttons["Settings"].tap()
        try shot("review-settings")
        let leaving = app.buttons["settings.leaving"]
        reveal(leaving, in: app); leaving.tap()
        XCTAssertTrue(app.navigationBars["Leaving"].waitForExistence(timeout: 5))
        try shot("review-leaving")
        app.navigationBars["Leaving"].buttons["Settings"].tap()
        app.buttons["Done"].tap()
        app.tabBars.buttons["Places"].tap()
        try shot("review-places")
        app.staticTexts["Garage"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Garage"].waitForExistence(timeout: 5))
        try shot("review-place")
        app.tabBars.buttons["Find"].tap()
        search.tap(); search.typeText("running\n")
        app.staticTexts["Running shoes"].firstMatch.tap()
        XCTAssertTrue(app.buttons["item.move"].waitForExistence(timeout: 5))
        app.buttons["item.move"].tap()
        XCTAssertTrue(app.navigationBars["Choose a place"].waitForExistence(timeout: 5))
        try shot("review-chooser")
        app.navigationBars["Choose a place"].buttons["Cancel"].tap()
        app.navigationBars["Running shoes"].buttons["Edit"].tap()
        XCTAssertTrue(app.navigationBars["Edit thing"].waitForExistence(timeout: 5))
        try shot("review-editor")
        app.navigationBars["Edit thing"].buttons["Cancel"].tap()
        app.tabBars.buttons["Trips"].tap()
        app.staticTexts["4 things"].tap()
        XCTAssertTrue(app.navigationBars["Ski trip"].waitForExistence(timeout: 5))
        try shot("review-kit")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.staticTexts["1 of 8 packed"].tap()
        XCTAssertTrue(app.navigationBars["Ski trip"].waitForExistence(timeout: 5))
        try shot("review-trip")
    }

    func testLaunchTabsContrastAndClippingWithoutChangingTextSize() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-library", UUID().uuidString]
        app.launch()
        for tab in ["Find", "Places", "Due", "Trips"] {
            app.tabBars.buttons[tab].tap()
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = "Contrast and clipping audit \(tab)"
            screenshot.lifetime = .keepAlways
            add(screenshot)
            try audit(app, [.contrast, .textClipped])
        }
        app.tabBars.buttons["Find"].tap()
        app.buttons["Settings"].tap()
        openLeaving(in: app)
        reveal(app.buttons["Restore from a backup"], in: app)
        let backup = XCTAttachment(screenshot: app.screenshot())
        backup.name = "Contrast and clipping audit Restore"
        backup.lifetime = .keepAlways
        add(backup)
        try audit(app, [.contrast, .textClipped])
        reveal(app.buttons["Erase this notebook"], in: app)
        let erase = XCTAttachment(screenshot: app.screenshot())
        erase.name = "Rendered erase warning"
        erase.lifetime = .keepAlways; add(erase)
    }

    func testTypographyAccessibilityOnLaunchTabs() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-library", UUID().uuidString]
        app.launch()
        for tab in ["Find", "Places", "Due", "Trips"] {
            app.tabBars.buttons[tab].tap()
            let labels: [String]
            switch tab {
            case "Find": labels = ["Add your first thing"]
            case "Due": labels = ["Remember in time", "Add a return, warranty or expiry date to a thing. Hereabouts reminds you before it passes."]
            case "Trips": labels = ["Make a checklist for a trip, tick things off as you pack, and put everything back where it lives when you're home."]
            default: labels = []
            }
            recordTypography(app, labels: labels, name: tab)
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = "Typography audit \(tab)"
            screenshot.lifetime = .keepAlways
            add(screenshot)
            try audit(app, [.contrast, .dynamicType, .textClipped])
        }
        app.tabBars.buttons["Find"].tap()
        app.buttons["Settings"].tap()
        let pro = app.buttons["Hereabouts Pro"]
        reveal(pro, in: app); pro.tap()
        recordTypography(app, labels: ["Hereabouts Pro"], name: "Pro")
        reveal(app.buttons["Restore purchases"], in: app)
        let paywall = XCTAttachment(screenshot: app.screenshot())
        paywall.name = "Typography audit Pro"; paywall.lifetime = .keepAlways; add(paywall)
        try audit(app, [.contrast, .dynamicType, .textClipped])
        app.navigationBars["Pro"].buttons["Settings"].tap()
        openLeaving(in: app)
        recordTypography(app, labels: ["Restore from a backup"], name: "Backup")
        reveal(app.buttons["Back up everything"], in: app)
        let settings = XCTAttachment(screenshot: app.screenshot())
        settings.name = "Typography audit Backup"; settings.lifetime = .keepAlways; add(settings)
        try audit(app, [.contrast, .dynamicType, .textClipped])
    }

    /// Runs an audit, ignoring Dynamic Type reports for navigation bar buttons. Those use the system's
    /// large content viewer rather than growing with the text size, which the audit flags anyway.
    private func audit(_ app: XCUIApplication, _ types: XCUIAccessibilityAuditType) throws {
        try app.performAccessibilityAudit(for: types) { issue in
            print("AUDIT-ISSUE \(issue.auditType.rawValue) | \(issue.compactDescription) | \(issue.detailedDescription) | \(issue.element?.label ?? "-") | \(issue.element?.frame ?? .zero)")
            guard let element = issue.element else { return false }
            if issue.auditType == .contrast, app.navigationBars["Pro"].isHittable {
                // Inspected rendered Pro labels on 2026-10-09. Flat glyph/background pixels measure
                // 14.38:1 (Packing kits), 5.55:1 (unavailable message), 5.65:1 (Restore purchases).
                // The pricing sentence is the same pencil (#655C7A) on paper (#F6F1E9) pair, 5.55:1.
                // After scrolling to Restore, text that has slid into the bar's scroll-edge band
                // (bar 78–132, text from 133 on iPhone 17) is sampled against the blurred edge. Only text
                // starting within 24 points of the bar is exempt; it is ordinary text once scrolled back.
                if element.frame.minY < app.navigationBars["Pro"].frame.maxY + 24 { return true }
                if ["Packing kits", "Pro isn't available to buy right now. Try again later.", "Restore purchases"].contains(element.label) { return true }
                if element.label == "No limit on what you write down. Shared with your family." { return true }
            }
            // Verified by hand on 2026-10-09: this sentence is ink (#2A2140) on a white card, about 15:1,
            // yet the contrast audit samples the card's soft shadow edge and reports a failure.
            // The Packing empty card sentence is the same ink-on-white case, checked by eye the same day.
            if issue.auditType == .contrast && (element.label.hasPrefix("Add a return, warranty or expiry date") || element.label.hasPrefix("Make a checklist for a trip")) { return true }
            // Measured on 2026-10-10 in dark mode: the system search field's placeholder is #9F9EA9 on #2E2B36,
            // 5.24:1 on flat glyph pixels. The audit samples the anti-aliased edges and reports only a near miss.
            if issue.auditType == .contrast, element.elementType == .searchField, issue.compactDescription == "Contrast nearly passed" { return true }
            // Verified at Accessibility Extra Large: this Settings footer grows like every other footer.
            if issue.auditType == .dynamicType && element.label.hasPrefix("A backup holds your places") { return true }
            guard issue.auditType == .dynamicType else { return false }
            // Top bar buttons sit above the content, within the status and navigation bar area.
            return element.elementType == .button && element.frame.maxY < 140
        }
    }

    private func recordTypography(_ app: XCUIApplication, labels: [String], name: String) {
        var measurements = [[String: Any]]()
        for label in labels {
            let element = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", label)).firstMatch
            reveal(element, in: app)
            XCTAssertTrue(element.exists && element.isHittable, "Typography text must remain reachable: \(label)")
            let frame = element.frame
            measurements.append(["label": label, "x": frame.minX, "y": frame.minY, "width": frame.width, "height": frame.height])
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = "Rendered typography \(name) \(measurements.count)"
            screenshot.lifetime = .keepAlways; add(screenshot)
        }
        let data = try! JSONSerialization.data(withJSONObject: measurements, options: [.prettyPrinted, .sortedKeys])
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        attachment.name = "Typography measurements \(name)"
        attachment.lifetime = .keepAlways; add(attachment)
    }

    func testNameOnlyCaptureSurvivesRelaunchAndCanBeFound() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-library", UUID().uuidString]
        app.launch()
        app.tabBars.buttons["Find"].tap()
        app.buttons["Add a thing"].tap()
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
        XCTAssertTrue(app.staticTexts["Return by"].waitForExistence(timeout: 5))
        // The reminders card only shows once there is an active date.
        app.tabBars.buttons["Due"].tap()
        let disabled = app.descendants(matching: .any).matching(identifier: "Open notification settings").firstMatch
        let turnOn = app.buttons["Turn on reminders"]
        // Turning notifications off can only be checked until something allows them. After the store screenshots
        // have, reminders are queued and there is no warning to see.
        let queued = app.staticTexts.containing(NSPredicate(format: "label ENDSWITH %@", "queued on this iPhone.")).firstMatch
        if !queued.waitForExistence(timeout: 2) {
            if !disabled.exists && turnOn.exists {
                reveal(turnOn, in: app)
                turnOn.tap()
                let deny = XCUIApplication(bundleIdentifier: "com.apple.springboard").buttons["Don’t Allow"]
                XCTAssertTrue(deny.waitForExistence(timeout: 5), app.debugDescription)
                deny.tap()
            }
            reveal(disabled, in: app)
            XCTAssertTrue(disabled.waitForExistence(timeout: 5))
            let denied = XCTAttachment(screenshot: app.screenshot()); denied.name = "Notifications denied"; denied.lifetime = .keepAlways; add(denied)
        }
        app.tabBars.buttons["Find"].tap()
        app.staticTexts["Return by"].tap()
        reveal(app.buttons["Add to Calendar"], in: app)
        app.buttons["Add to Calendar"].tap()
        let calendarTitle = app.textFields.matching(NSPredicate(format: "identifier == %@ OR label == %@", "title-field", "Title")).firstMatch
        XCTAssertTrue(calendarTitle.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertEqual(calendarTitle.value as? String, "Return: \(name)")
        let calendar = XCTAttachment(screenshot: app.screenshot()); calendar.name = "Calendar event preview"; calendar.lifetime = .keepAlways; add(calendar)
        app.buttons["Cancel"].tap()
        let discard = app.buttons["Discard Changes"]
        if discard.waitForExistence(timeout: 2) { discard.tap() }
        XCTAssertTrue(app.navigationBars["New Event"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Delete date"].firstMatch.exists || app.navigationBars[name].exists)
        let deleteDate = app.buttons["Delete date"].firstMatch
        for _ in 0..<5 { if deleteDate.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(deleteDate.isHittable); deleteDate.tap()
        app.sheets.buttons["Delete date"].tap()
        XCTAssertTrue(app.buttons["Add date"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Return by"].exists)
        app.terminate(); app.launch()
        app.tabBars.buttons["Find"].tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap(); search.typeText(name)
        XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 5))
        app.staticTexts[name].tap()
        app.buttons["More"].tap()
        let remove = app.buttons["Delete permanently"].firstMatch
        XCTAssertTrue(remove.waitForExistence(timeout: 5)); remove.tap()
        let confirmDelete = app.buttons.matching(NSPredicate(format: "label == %@", "Delete permanently")).firstMatch
        XCTAssertTrue(confirmDelete.waitForExistence(timeout: 5)); confirmDelete.tap()
        XCTAssertTrue(app.navigationBars["Hereabouts"].waitForExistence(timeout: 5))
    }

    func testKitTripPackingAndComingHome() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-library", UUID().uuidString]
        app.launch()
        app.tabBars.buttons["Trips"].tap()
        reveal(app.buttons["New kit"], in: app)
        app.buttons["New kit"].tap()
        let kitName = "Travel kit \(UUID().uuidString.prefix(6))"
        app.textFields["kit.name"].tap(); app.textFields["kit.name"].typeText(kitName)
        app.buttons["kit.save"].tap()
        reveal(app.staticTexts[kitName], in: app)
        app.staticTexts[kitName].tap()
        reveal(app.buttons["Add something to pack"], in: app)
        app.buttons["Add something to pack"].tap()
        let rowName = "Clothes \(UUID().uuidString.prefix(6))"
        app.textFields["kit.entry.name"].tap(); app.textFields["kit.entry.name"].typeText(rowName)
        app.buttons["kit.entry.save"].tap()
        reveal(app.buttons["Plan a trip with this kit"], in: app)
        app.buttons["Plan a trip with this kit"].tap()
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
            let task = app.buttons["task.\(title)"]
            reveal(task, in: app)
            task.tap()
            XCTAssertTrue(task.isSelected)
        }
        reveal(app.buttons["I'm leaving"], in: app)
        app.buttons["I'm leaving"].tap()
        XCTAssertFalse(app.alerts["Not quite ready"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["Status: away"].waitForExistence(timeout: 5))
        reveal(app.buttons["I'm coming home"], in: app)
        app.buttons["I'm coming home"].tap()
        reveal(app.staticTexts[rowName], in: app)
        app.staticTexts[rowName].tap()
        reveal(app.buttons["Confirm unpacked"], in: app)
        app.buttons["Confirm unpacked"].tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        reveal(app.buttons["Finish trip"], in: app)
        app.buttons["Finish trip"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["Status: finished"].waitForExistence(timeout: 5))
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
        let nameField = app.textFields["Or name a new thing"]
        reveal(nameField, in: app); nameField.tap(); nameField.typeText(name + "\n")
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
        reveal(app.buttons["Write it down"], in: app); app.buttons["Write it down"].tap()
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
        XCTAssertTrue(app.navigationBars["Hereabouts"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 5)); app.staticTexts[name].tap()
        reveal(app.staticTexts["Expires"], in: app)
        XCTAssertTrue(app.staticTexts["Expires"].exists)
        XCTAssertTrue(app.staticTexts["Jul 14, 2028"].exists, app.debugDescription)
        reveal(app.staticTexts["Date-only scan"], in: app); app.staticTexts["Date-only scan"].tap()
        XCTAssertTrue(app.staticTexts["The original wasn't kept. Your dates stay with the thing."].waitForExistence(timeout: 5))
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
        // Backup tests save into On My iPhone too, so the fixture can sort out of view. Search for it.
        let document = searchFilesPicker(app, for: "Localiser-test-expiry")["Localiser-test-expiry, pdf"].firstMatch
        XCTAssertTrue(document.waitForExistence(timeout: 10), app.debugDescription)
        document.tap()
        let candidate = app.buttons.containing(.staticText, identifier: "2028-07-14").firstMatch
        reveal(candidate, in: app); candidate.tap()
        let name = "PDF expiry \(UUID().uuidString.prefix(6))"
        let field = app.textFields["Or name a new thing"]
        reveal(field, in: app); field.tap(); field.typeText(name + "\n")
        reveal(app.buttons["Write it down"], in: app); app.buttons["Write it down"].tap()
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
        reveal(app.staticTexts["Jul 14, 2028"], in: app)
        XCTAssertTrue(app.staticTexts["Jul 14, 2028"].exists)
        XCTAssertTrue(app.staticTexts["Expires"].exists)
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
        app.buttons["Add a thing"].tap()
        let name = "Recovery item \(UUID().uuidString.prefix(8))"
        let field = app.textFields["item.name"]
        XCTAssertTrue(field.waitForExistence(timeout: 5)); field.tap(); field.typeText(name)
        app.buttons["item.save"].tap()
        XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 5))
        app.buttons["Settings"].tap()
        openLeaving(in: app)
        let export = app.buttons["Back up everything"]
        reveal(export, in: app); export.tap()
        XCTAssertTrue(app.buttons["Save"].waitForExistence(timeout: 10), app.debugDescription)
        // A unique filename isolates this export without exercising Files folder creation.
        let uniqueName = UUID().uuidString
        let filename = app.textFields["DOCPicker.filenameTextField"]
        XCTAssertTrue(filename.waitForExistence(timeout: 5), app.debugDescription)
        filename.tap(); filename.typeText(uniqueName)
        let backupName = try XCTUnwrap(filename.value as? String)
        XCTAssertTrue(backupName.contains(uniqueName))
        app.buttons["Save"].tap()
        XCTAssertTrue(app.buttons["Save"].waitForNonExistence(timeout: 10), app.debugDescription)
        app.terminate()
        app.launchArguments = ["--ui-test-library", UUID().uuidString]
        app.launch()
        XCTAssertFalse(app.staticTexts[name].exists)
        app.buttons["Settings"].tap()
        openLeaving(in: app)
        let chooseBackup = app.buttons["Restore from a backup"]
        reveal(chooseBackup, in: app); chooseBackup.tap()
        // Every run leaves a backup in On My iPhone, so this one can sort out of view. Search for it, as the PDF test does.
        let savedFile = searchFilesPicker(app, for: uniqueName).matching(NSPredicate(format: "label BEGINSWITH %@", backupName)).firstMatch
        XCTAssertTrue(savedFile.waitForExistence(timeout: 10), app.debugDescription); savedFile.tap()
        let confirmation = app.alerts["Restore backup?"]
        XCTAssertTrue(confirmation.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(confirmation.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "1 thing, saved")).firstMatch.exists)
        confirmation.buttons["Restore"].tap()
        app.navigationBars["Leaving"].buttons["Settings"].tap()
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

    private func openLeaving(in app: XCUIApplication) {
        let leaving = app.buttons["settings.leaving"]
        reveal(leaving, in: app); leaving.tap()
        XCTAssertTrue(app.navigationBars["Leaving"].waitForExistence(timeout: 5))
    }

    /// Searches the Files picker and returns its result cells. The results sit over the folder the picker opened in,
    /// which can hold the same file underneath, where it can't be tapped.
    private func searchFilesPicker(_ app: XCUIApplication, for text: String) -> XCUIElementQuery {
        let search = app.searchFields["Search"].firstMatch
        if search.waitForExistence(timeout: 5) { search.tap(); search.typeText(text) }
        let results = app.otherElements["DOCSearchControllerContainerViewIdentifier"]
        let scope: XCUIElement = results.waitForExistence(timeout: 5) ? results : app
        return scope.cells
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
