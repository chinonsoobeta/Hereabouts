import StoreKit
import Observation
import UserNotifications

enum CreationKind {
    case item, kit, home
    /// Free-tier allowance. Pro removes every limit; nothing else is gated.
    var freeLimit: Int { switch self { case .item: Self.freeThings; case .kit: 1; case .home: 2 } }

    /// 15 in TestFlight and App Store builds. Builds installed straight onto a phone set `HEREABOUTS_FREE_THINGS=200`,
    /// because they can't buy Pro.
    static let freeThings: Int = {
        let raw = Bundle.main.object(forInfoDictionaryKey: "HereaboutsFreeThings") as? String ?? ""
        return Int(raw).flatMap { $0 > 0 ? $0 : nil } ?? 15
    }()
}

/// The three ways to have Pro. Monthly and yearly share one subscription group; lifetime is a one-off purchase.
enum ProPlan: String, CaseIterable, Identifiable, Sendable {
    case yearly, monthly, lifetime
    /// Product IDs start with the bundle ID. Change this one prefix if the bundle ID changes before launch.
    static let prefix = "dev.hereabouts.pro."
    var id: String { rawValue }
    var productID: String { Self.prefix + rawValue }
    init?(productID: String) {
        guard productID.hasPrefix(Self.prefix) else { return nil }
        self.init(rawValue: String(productID.dropFirst(Self.prefix.count)))
    }
    var name: String { switch self { case .yearly: String(localized: "Yearly"); case .monthly: String(localized: "Monthly"); case .lifetime: String(localized: "Lifetime") } }
    var isSubscription: Bool { self != .lifetime }
}

/// What the person has right now, as the Pro screen describes it.
struct ProStanding: Equatable, Sendable {
    var plan: ProPlan
    /// When the current period ends. Nil for lifetime.
    var periodEnd: Date?
    var inTrial = false
    var willRenew = true
    var familyShared = false
}

@MainActor @Observable final class ProAccess {
    static var productIDs: [String] { ProPlan.allCases.map(\.productID) }
    private(set) var unlocked = false
    private(set) var standing: ProStanding?
    /// A subscription that has ended, so the Pro screen can say nothing was lost.
    private(set) var lapsed = false
    /// The free trial each subscription plan offers this Apple Account, as "2 weeks". A plan with no
    /// trial, or one this account has used, is missing. Each plan is asked on its own.
    private(set) var trials: [ProPlan: String] = [:]
    /// Whether any plan still offers a trial.
    var trialEligible: Bool { !trials.isEmpty }
    func trial(_ plan: ProPlan) -> String? { trials[plan] }
    private(set) var products: [ProPlan: Product] = [:]
    /// Whether the App Store has answered at least once. Until then the Pro screen waits rather than saying Pro isn't for sale.
    private(set) var productChecked = false
    private(set) var busy = false
    var message: String?

    func allows(_ kind: CreationKind, count: Int) -> Bool {
        unlocked || count < kind.freeLimit
    }

    func product(_ plan: ProPlan) -> Product? { products[plan] }

    func refresh() async {
        var best: ProStanding?
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result, transaction.revocationDate == nil,
                  let plan = ProPlan(productID: transaction.productID) else { continue }
            var found = ProStanding(plan: plan, periodEnd: transaction.expirationDate, familyShared: transaction.ownershipType == .familyShared)
            if plan.isSubscription {
                let status = await status(of: transaction)
                // The entitlement list can lag behind an expiry; the subscription's own status is current.
                if let state = status?.state, ![.subscribed, .inGracePeriod].contains(state) { continue }
                found.inTrial = transaction.offer?.type == .introductory
                if case .verified(let renewal)? = status?.renewalInfo { found.willRenew = renewal.willAutoRenew }
            }
            // Lifetime outranks any subscription; otherwise keep the one that runs longest.
            if best?.plan != .lifetime, plan == .lifetime || (found.periodEnd ?? .distantFuture) > (best?.periodEnd ?? .distantPast) { best = found }
        }
        standing = best
        unlocked = best != nil
        NotebookFile.sharedDefaults()?.set(unlocked, forKey: NotebookFile.proUnlockedKey)
        if best == nil { lapsed = await hadSubscription() } else { lapsed = false }
        await checkTrials()
        TrialReminder.update(best)
    }

    private func checkTrials() async {
        var found: [ProPlan: String] = [:]
        for plan in ProPlan.allCases where plan.isSubscription {
            guard let subscription = products[plan]?.subscription, let offer = subscription.introductoryOffer,
                  offer.paymentMode == .freeTrial, await subscription.isEligibleForIntroOffer else { continue }
            found[plan] = ProPricing.trialLength(value: offer.period.value * max(offer.periodCount, 1), unit: offer.period.unit)
        }
        trials = found
    }

    private func status(of transaction: Transaction) async -> Product.SubscriptionInfo.Status? {
        guard let groupID = transaction.subscriptionGroupID, let statuses = try? await Product.SubscriptionInfo.status(for: groupID) else { return nil }
        return statuses.first { status in
            if case .verified(let renewal) = status.renewalInfo { return renewal.originalTransactionID == transaction.originalID }
            return false
        }
    }

    private func hadSubscription() async -> Bool {
        for await result in Transaction.all {
            if case .verified(let transaction) = result, ProPlan(productID: transaction.productID)?.isSubscription == true { return true }
        }
        return false
    }

    func observeTransactions() async {
        await refresh()
        for await result in Transaction.updates {
            guard !Task.isCancelled else { return }
            if case .verified(let transaction) = result, ProPlan(productID: transaction.productID) != nil {
                await refresh()
                await transaction.finish()
            }
        }
    }

    func loadProduct() async {
        defer { productChecked = true }
        do {
            // When the products are missing, the Pro screen says so itself.
            let loaded = try await Product.products(for: Self.productIDs)
            products = Dictionary(loaded.compactMap { product in ProPlan(productID: product.id).map { ($0, product) } }, uniquingKeysWith: { first, _ in first })
            await checkTrials()
        } catch { message = error.localizedDescription }
    }

    func purchase(_ plan: ProPlan = .yearly) async {
        guard !busy, let product = products[plan] else { return }
        busy = true; message = nil
        defer { busy = false }
        do {
            switch try await product.purchase() {
            case .success(let result):
                guard case .verified(let transaction) = result else { message = String(localized: "The App Store couldn't confirm that purchase. Try Restore purchases."); return }
                await refresh(); await transaction.finish()
                if !unlocked { message = String(localized: "The App Store hasn't confirmed Pro yet. Try Restore purchases in a moment.") }
                else if standing?.inTrial == true, let end = standing?.periodEnd { message = String(localized: "Your free trial has started. It ends on \(end.formatted(.dateTime.day().month(.wide))).") }
                else { message = String(localized: "You have Hereabouts Pro.") }
            case .userCancelled: message = String(localized: "Purchase canceled. You weren't charged.")
            case .pending: message = String(localized: "Waiting for approval. You can still use your free plan.")
            @unknown default: message = String(localized: "Couldn't confirm what happened. Try Restore purchases.")
            }
        } catch { message = error.localizedDescription }
    }

    func restorePurchases() async {
        guard !busy else { return }
        busy = true; message = nil
        defer { busy = false }
        do { try await AppStore.sync(); await refresh(); message = unlocked ? String(localized: "Hereabouts Pro restored.") : String(localized: "No Pro purchase was found for this Apple Account.") }
        catch { message = error.localizedDescription }
    }

    /// Someone with lifetime who still has a subscription renewing is paying twice.
    var subscribedAlongsideLifetime: Bool { standing?.plan == .lifetime && renewingSubscription }
    private(set) var renewingSubscription = false

    func checkRenewingSubscription() async {
        var renewing = false
        for plan in [ProPlan.monthly, .yearly] {
            for status in (try? await products[plan]?.subscription?.status) ?? [] {
                if case .verified(let renewal) = status.renewalInfo, renewal.willAutoRenew, [.subscribed, .inGracePeriod, .inBillingRetryPeriod].contains(status.state) { renewing = true }
            }
        }
        renewingSubscription = renewing
    }
}

/// A local reminder two days before a free trial turns into a paid plan. Only sent when reminders are allowed.
enum TrialReminder {
    static let id = "hereabouts.trial-ending"

    static func fireDate(trialEnd: Date, now: Date = .now, calendar: Calendar = .current) -> Date? {
        guard let twoDaysBefore = calendar.date(byAdding: .day, value: -2, to: trialEnd) else { return nil }
        let morning = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: twoDaysBefore) ?? twoDaysBefore
        return morning > now ? morning : nil
    }

    static func update(_ standing: ProStanding?) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [id])
        guard let standing, standing.inTrial, standing.willRenew, let end = standing.periodEnd, let fire = fireDate(trialEnd: end) else { return }
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Your free trial ends \(end.formatted(.dateTime.weekday(.wide)))")
        content.body = String(localized: "Your \(standing.plan.name.lowercased()) plan starts then. Cancel in Settings before then if you do not want to pay.")
        let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)))
    }
}
