import XCTest
import StoreKit
import StoreKitTest
@testable import Localiser

@MainActor
final class SubscriptionTests: XCTestCase {
    private func session() throws -> SKTestSession {
        if #unavailable(iOS 27) { throw XCTSkip("iOS 26.5's local StoreKit test service rejects configuration (SKInternalErrorDomain 3). Verify on iOS 27.") }
        let file = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "Localiser", withExtension: "storekit"))
        let session = try SKTestSession(contentsOf: file)
        session.resetToDefaultState(); session.disableDialogs = true; session.clearTransactions()
        return session
    }

    /// StoreKit's test service applies changes a moment later, so check again until it has.
    private func eventually(_ pro: ProAccess, _ condition: () -> Bool) async throws {
        // Up to 15 seconds: after a long suite the test store can be slow to report a purchase.
        for _ in 0..<150 {
            await pro.refresh()
            if condition() { return }
            try await Task.sleep(for: .milliseconds(100))
        }
    }

    /// StoreKit remembers that an Apple Account used its intro offer for about 15 seconds after `clearTransactions()`
    /// and `resetToDefaultState()` (measured on iOS 27; eligibility flipped back at 15.0 s every time). A trial test that runs
    /// after a purchase test would otherwise see "no trial", so wait here until the plan with a trial reports eligible again.
    private func waitForTrialEligibility() async throws {
        for _ in 0..<400 {
            let products = try await Product.products(for: ProPlan.allCases.map(\.productID))
            var eligible = !products.isEmpty
            for product in products {
                if let subscription = product.subscription, subscription.introductoryOffer != nil, await !subscription.isEligibleForIntroOffer { eligible = false }
            }
            if eligible { return }
            try await Task.sleep(for: .milliseconds(100))
        }
    }

    func testTrialStartsThenLapseKeepsTheNotebook() async throws {
        let session = try session()
        defer { session.clearTransactions(); session.resetToDefaultState() }
        try await waitForTrialEligibility()
        let pro = ProAccess()
        await pro.loadProduct(); await pro.refresh()
        XCTAssertEqual(Set(pro.products.keys), Set(ProPlan.allCases))
        XCTAssertEqual(pro.trial(.yearly), "1 week", "Only the yearly plan has a free trial (owner, 10 Nov)")
        XCTAssertNil(pro.trial(.monthly), "Each plan is asked about its own trial, and monthly has none")
        XCTAssertNil(pro.trial(.lifetime))

        await pro.purchase(.yearly)
        XCTAssertTrue(pro.unlocked, pro.message ?? "No purchase message")
        XCTAssertEqual(pro.standing?.plan, .yearly)
        XCTAssertEqual(pro.standing?.inTrial, true)
        XCTAssertTrue(pro.message?.hasPrefix("Your free trial has started.") == true, pro.message ?? "")
        try await eventually(pro) { !pro.trialEligible }
        XCTAssertFalse(pro.trialEligible, "The trial is once per Apple Account")
        XCTAssertNil(pro.trial(.yearly), "Used once, so yearly no longer offers it")

        let store = try LocaliserStore(inMemory: true)
        for index in 0..<(CreationKind.item.freeLimit + 2) {
            XCTAssertTrue(pro.allows(.item, count: store.activeItemCount))
            try store.addItem(name: "Thing \(index)")
        }

        // The local test store's expiry doesn't reach StoreKit's status in unit tests; a refund ends it the same way.
        let trial = try XCTUnwrap(session.allTransactions().first { $0.productIdentifier == ProPlan.yearly.productID })
        try session.refundTransaction(identifier: trial.identifier)
        try await eventually(pro) { !pro.unlocked }
        XCTAssertFalse(pro.unlocked)
        XCTAssertNil(pro.standing)
        XCTAssertTrue(pro.lapsed)
        XCTAssertFalse(pro.allows(.item, count: store.activeItemCount))
        XCTAssertEqual(store.items.count, CreationKind.item.freeLimit + 2)
        let first = try XCTUnwrap(store.items.first)
        try store.editItem(first, name: "Still editable", place: nil, notes: "", aliases: "", photo: nil)
        XCTAssertEqual(first.name, "Still editable")
        XCTAssertEqual(try store.backup().records.filter { $0.entity != "Home" }.count, CreationKind.item.freeLimit + 2)
    }

    func testRefundLocks() async throws {
        let session = try session()
        defer { session.clearTransactions(); session.resetToDefaultState() }
        let pro = ProAccess()
        await pro.loadProduct()

        let yearly = try await session.buyProduct(identifier: ProPlan.yearly.productID)
        try await eventually(pro) { pro.unlocked }
        XCTAssertEqual(pro.standing?.plan, .yearly)
        try session.refundTransaction(identifier: UInt(yearly.id))
        try await eventually(pro) { !pro.unlocked }
        XCTAssertFalse(pro.unlocked)
    }

    func testLifetimeOutlastsASubscription() async throws {
        let session = try session()
        defer { session.clearTransactions(); session.resetToDefaultState() }
        let pro = ProAccess()
        await pro.loadProduct()
        _ = try await session.buyProduct(identifier: ProPlan.monthly.productID)
        _ = try await session.buyProduct(identifier: ProPlan.lifetime.productID)
        try await eventually(pro) { pro.standing?.plan == .lifetime }
        XCTAssertEqual(pro.standing?.plan, .lifetime)
        await pro.checkRenewingSubscription()
        XCTAssertTrue(pro.subscribedAlongsideLifetime, "Someone paying twice is told to cancel")
        try session.expireSubscription(productIdentifier: ProPlan.monthly.productID)
        try await Task.sleep(for: .milliseconds(500))
        await pro.refresh()
        XCTAssertTrue(pro.unlocked)
        XCTAssertEqual(pro.standing?.plan, .lifetime)
    }

    func testFailedRenewalInGracePeriodStaysUnlocked() async throws {
        let session = try session()
        defer { session.clearTransactions(); session.resetToDefaultState() }
        session.billingGracePeriodIsEnabled = true
        session.shouldEnterBillingRetryOnRenewal = true
        let pro = ProAccess()
        await pro.loadProduct()
        _ = try await session.buyProduct(identifier: ProPlan.monthly.productID)
        try await eventually(pro) { pro.unlocked }
        try session.forceRenewalOfSubscription(productIdentifier: ProPlan.monthly.productID)
        try await Task.sleep(for: .milliseconds(500))
        await pro.refresh()
        XCTAssertTrue(pro.unlocked, "A card problem during the grace period doesn't take Pro away")
    }

    func testPricingSentences() {
        XCTAssertEqual(ProPricing.saving(yearly: Decimal(string: "19.99")!, monthly: Decimal(string: "2.99")!), 44)
        XCTAssertNil(ProPricing.saving(yearly: 40, monthly: 2.99))
        XCTAssertEqual(ProPricing.monthly(Decimal(string: "19.99")!), Decimal(string: "1.67")!)
        XCTAssertEqual(ProPricing.terms(plan: .yearly, price: "$19.99", period: "a year", trial: "1 week"),
                       "Free for 1 week, then $19.99 a year. Renews automatically until you cancel. Cancel in Settings at least a day before it renews.")
        XCTAssertEqual(ProPricing.terms(plan: .monthly, price: "$2.99", period: "a month", trial: nil),
                       "$2.99 a month. Renews automatically until you cancel. Cancel in Settings at least a day before it renews.")
        XCTAssertEqual(ProPricing.terms(plan: .monthly, price: "$2.99", period: "a month", trial: "1 month"),
                       "Free for 1 month, then $2.99 a month. Renews automatically until you cancel. Cancel in Settings at least a day before it renews.")
        XCTAssertEqual(ProPricing.trialLength(value: 1, unit: .week), "1 week")
        XCTAssertEqual(ProPricing.trialLength(value: 2, unit: .week), "2 weeks")
        XCTAssertEqual(ProPricing.trialLength(value: 1, unit: .month), "1 month")
        XCTAssertEqual(ProPricing.trialLength(value: 3, unit: .day), "3 days")
        XCTAssertEqual(ProPricing.trialLength(value: 14, unit: .day), "2 weeks", "A two-week trial reads the same on every iOS version")
        XCTAssertEqual(ProPricing.trialLength(value: 7, unit: .day), "1 week")
        XCTAssertEqual(ProPricing.trialLength(value: 10, unit: .day), "10 days")
        XCTAssertEqual(ProPricing.terms(plan: .lifetime, price: "$49.99", period: "", trial: "2 weeks"), "Pay once. Share with your family. No renewal.")
    }

    func testStandingSummaries() throws {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = .current
        let end = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 11, day: 12, hour: 12)))
        let day = end.formatted(.dateTime.day().month(.abbreviated))
        XCTAssertEqual(ProStanding(plan: .lifetime).summary, "Lifetime Pro.")
        XCTAssertEqual(ProStanding(plan: .lifetime, familyShared: true).summary, "Lifetime Pro. Shared by your family.")
        XCTAssertEqual(ProStanding(plan: .yearly, periodEnd: end).summary, "Pro, renews \(day)")
        XCTAssertEqual(ProStanding(plan: .yearly, periodEnd: end, willRenew: false).summary, "Pro until \(day). It won't renew.")
        XCTAssertEqual(ProStanding(plan: .monthly, periodEnd: end, inTrial: true).summary, "Free trial, ends \(day)")
    }

    /// The "Your plan" card on the Pro screen: which plan, and its facts one to a line (owner, 10 Nov).
    func testPlanCard() throws {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = .current
        let end = try XCTUnwrap(calendar.date(from: DateComponents(year: 2027, month: 11, day: 12, hour: 12)))
        let day = PlanCard.date(end)
        let things = CreationKind.item.freeLimit

        let free = PlanCard.make(standing: nil, lapsed: false, counts: .init(things: 9, kits: 1, homes: 1), price: nil)
        XCTAssertEqual(free.title, "Free")
        XCTAssertEqual(free.facts.map(\.name), ["Things", "Packing kits", "Homes"])
        XCTAssertEqual(free.facts.map(\.value), ["9 of \(things)", "1 of 1", "1 of 2"])
        XCTAssertEqual(free.facts.map(\.warning), [false, false, false], "At a limit isn't over it")
        XCTAssertNil(free.note)

        let lapsed = PlanCard.make(standing: nil, lapsed: true, counts: .init(things: things + 8, kits: 3, homes: 2), price: nil)
        XCTAssertEqual(lapsed.title, "Free")
        XCTAssertEqual(lapsed.facts.map(\.warning), [true, true, false])
        XCTAssertEqual(lapsed.note, "Your subscription ended. Everything you saved is still here. You can still find, edit and export it.")

        let yearly = PlanCard.make(standing: ProStanding(plan: .yearly, periodEnd: end), lapsed: false, counts: .init(), price: "$19.99 a year")
        XCTAssertEqual(yearly.title, "Pro")
        XCTAssertEqual(yearly.facts.map(\.name), ["Paid", "Renews", "Price"])
        XCTAssertEqual(yearly.facts.map(\.value), ["Yearly", day, "$19.99 a year"])
        XCTAssertNil(yearly.note)

        let trial = PlanCard.make(standing: ProStanding(plan: .yearly, periodEnd: end, inTrial: true), lapsed: false, counts: .init(), price: "$19.99 a year")
        XCTAssertEqual(trial.title, "Pro, free trial")
        XCTAssertEqual(trial.facts.map(\.name), ["Trial ends", "Then"])
        XCTAssertEqual(trial.facts.map(\.value), [day, "$19.99 a year"])
        XCTAssertEqual(trial.note, "Cancel at least a day before it ends and you pay nothing.")

        let cancelledTrial = PlanCard.make(standing: ProStanding(plan: .yearly, periodEnd: end, inTrial: true, willRenew: false), lapsed: false, counts: .init(), price: "$19.99 a year")
        XCTAssertEqual(cancelledTrial.facts.map(\.name), ["Trial ends"], "Nothing follows a trial that won't renew")
        XCTAssertEqual(cancelledTrial.note, "It won't renew. After that you're on Free, and everything you've saved stays.")

        let ending = PlanCard.make(standing: ProStanding(plan: .monthly, periodEnd: end, willRenew: false), lapsed: false, counts: .init(), price: "$2.99 a month")
        XCTAssertEqual(ending.facts.map(\.name), ["Paid", "Ends"])
        XCTAssertEqual(ending.facts.map(\.value), ["Monthly", day])
        XCTAssertEqual(ending.facts.map(\.warning), [false, true])
        XCTAssertEqual(ending.note, "It won't renew. After that you're on Free, and everything you've saved stays.")

        let lifetime = PlanCard.make(standing: ProStanding(plan: .lifetime), lapsed: false, counts: .init(), price: nil)
        XCTAssertEqual(lifetime.title, "Pro")
        XCTAssertEqual(lifetime.facts.map(\.value), ["Lifetime, once", "Never"])
        XCTAssertNil(lifetime.note)

        let family = PlanCard.make(standing: ProStanding(plan: .yearly, periodEnd: end, familyShared: true), lapsed: false, counts: .init(), price: "$19.99 a year")
        XCTAssertEqual(family.facts.map(\.name), ["Shared by", "Paid", "Renews"], "The family organizer pays, so no price")
        XCTAssertEqual(family.facts.first?.value, "Your family")
        let familyTrial = PlanCard.make(standing: ProStanding(plan: .yearly, periodEnd: end, inTrial: true, familyShared: true), lapsed: false, counts: .init(), price: "$19.99 a year")
        XCTAssertNil(familyTrial.note, "Only the organizer can cancel")

        for card in [free, lapsed, yearly, trial, cancelledTrial, ending, lifetime, family, familyTrial] {
            let text = ([card.title, card.note ?? ""] + card.facts.flatMap { [$0.name, $0.value] }).joined(separator: "\n")
            XCTAssertFalse(text.contains("·"), "No middle dots on the card (owner, 10 Nov): \(text)")
        }
    }

    func testPlansAndTrialReminder() throws {
        XCTAssertEqual(ProPlan(productID: "dev.hereabouts.pro.yearly"), .yearly)
        XCTAssertNil(ProPlan(productID: "dev.hereabouts.pro.weekly"))
        XCTAssertNil(ProPlan(productID: "other.pro.yearly"))
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 10, day: 12, hour: 9)))
        let end = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 10, day: 26, hour: 15)))
        let fire = try XCTUnwrap(TrialReminder.fireDate(trialEnd: end, now: now, calendar: calendar))
        XCTAssertEqual(calendar.dateComponents([.month, .day, .hour], from: fire), DateComponents(month: 10, day: 24, hour: 10))
        XCTAssertNil(TrialReminder.fireDate(trialEnd: calendar.date(byAdding: .day, value: 1, to: now)!, now: now, calendar: calendar))
    }
}
