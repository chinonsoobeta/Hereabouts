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

    func testTrialStartsThenLapseKeepsTheNotebook() async throws {
        let session = try session()
        defer { session.clearTransactions(); session.resetToDefaultState() }
        let pro = ProAccess()
        await pro.loadProduct(); await pro.refresh()
        XCTAssertEqual(Set(pro.products.keys), Set(ProPlan.allCases))
        XCTAssertEqual(pro.trial(.monthly), "2 weeks", "Each plan is asked about its own trial")
        XCTAssertEqual(pro.trial(.yearly), "2 weeks")
        XCTAssertNil(pro.trial(.lifetime))

        await pro.purchase(.monthly)
        XCTAssertTrue(pro.unlocked, pro.message ?? "No purchase message")
        XCTAssertEqual(pro.standing?.plan, .monthly)
        XCTAssertEqual(pro.standing?.inTrial, true)
        XCTAssertTrue(pro.message?.hasPrefix("Your free trial has started.") == true, pro.message ?? "")
        try await eventually(pro) { !pro.trialEligible }
        XCTAssertFalse(pro.trialEligible, "The trial is once per Apple Account")
        XCTAssertNil(pro.trial(.yearly), "Used on monthly, so yearly no longer offers it either")

        let store = try LocaliserStore(inMemory: true)
        for index in 0..<(CreationKind.item.freeLimit + 2) {
            XCTAssertTrue(pro.allows(.item, count: store.activeItemCount))
            try store.addItem(name: "Thing \(index)")
        }

        // The local test store's expiry doesn't reach StoreKit's status in unit tests; a refund ends it the same way.
        let trial = try XCTUnwrap(session.allTransactions().first { $0.productIdentifier == ProPlan.monthly.productID })
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
        XCTAssertEqual(ProPricing.terms(plan: .yearly, price: "$19.99", period: "a year", trial: "2 weeks"),
                       "Free for 2 weeks, then $19.99 a year. Renews automatically until you cancel. Cancel any time in Settings, at least a day before it renews.")
        XCTAssertEqual(ProPricing.terms(plan: .monthly, price: "$2.99", period: "a month", trial: nil),
                       "$2.99 a month. Renews automatically until you cancel. Cancel any time in Settings, at least a day before it renews.")
        XCTAssertEqual(ProPricing.terms(plan: .monthly, price: "$2.99", period: "a month", trial: "1 month"),
                       "Free for 1 month, then $2.99 a month. Renews automatically until you cancel. Cancel any time in Settings, at least a day before it renews.")
        XCTAssertEqual(ProPricing.trialLength(value: 2, unit: .week), "2 weeks")
        XCTAssertEqual(ProPricing.trialLength(value: 1, unit: .month), "1 month")
        XCTAssertEqual(ProPricing.trialLength(value: 3, unit: .day), "3 days")
        XCTAssertEqual(ProPricing.terms(plan: .lifetime, price: "$49.99", period: "", trial: "2 weeks"), "One payment, shared with your family. Nothing renews.")
    }

    func testStandingSummaries() throws {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = .current
        let end = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 11, day: 12, hour: 12)))
        let day = end.formatted(.dateTime.day().month(.abbreviated))
        XCTAssertEqual(ProStanding(plan: .lifetime).summary, "Lifetime. Thank you.")
        XCTAssertEqual(ProStanding(plan: .lifetime, familyShared: true).summary, "Lifetime. Thank you. Shared by your family.")
        XCTAssertEqual(ProStanding(plan: .yearly, periodEnd: end).summary, "Pro, renews \(day)")
        XCTAssertEqual(ProStanding(plan: .yearly, periodEnd: end, willRenew: false).summary, "Pro until \(day). It won't renew.")
        XCTAssertEqual(ProStanding(plan: .monthly, periodEnd: end, inTrial: true).summary, "Free trial, ends \(day)")
    }

    func testPlansAndTrialReminder() throws {
        XCTAssertEqual(ProPlan(productID: "dev.localiser.pro.yearly"), .yearly)
        XCTAssertNil(ProPlan(productID: "dev.localiser.pro.weekly"))
        XCTAssertNil(ProPlan(productID: "other.pro.yearly"))
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 10, day: 12, hour: 9)))
        let end = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 10, day: 26, hour: 15)))
        let fire = try XCTUnwrap(TrialReminder.fireDate(trialEnd: end, now: now, calendar: calendar))
        XCTAssertEqual(calendar.dateComponents([.month, .day, .hour], from: fire), DateComponents(month: 10, day: 24, hour: 10))
        XCTAssertNil(TrialReminder.fireDate(trialEnd: calendar.date(byAdding: .day, value: 1, to: now)!, now: now, calendar: calendar))
    }
}
