import StoreKit
import Observation
import UserNotifications

enum CreationKind {
    case item, kit, scan, home
    /// Free-tier allowance. Pro removes every limit; nothing else is gated.
    var freeLimit: Int { switch self { case .item: Self.freeThings; case .kit: 2; case .scan: 5; case .home: 2 } }

    /// 20 in TestFlight and App Store builds. Builds installed straight onto a phone set `HEREABOUTS_FREE_THINGS=200`,
    /// because they can't buy Pro.
    static let freeThings: Int = {
        let raw = Bundle.main.object(forInfoDictionaryKey: "HereaboutsFreeThings") as? String ?? ""
        return Int(raw).flatMap { $0 > 0 ? $0 : nil } ?? 20
    }()
}

/// The three ways to have Pro. Monthly and yearly share one subscription group; lifetime is a one-off purchase.
enum ProPlan: String, CaseIterable, Identifiable, Sendable {
    case yearly, monthly, lifetime
    /// Product IDs start with the bundle ID. Change this one prefix if the bundle ID changes before launch.
    static let prefix = "dev.localiser.pro."
    var id: String { rawValue }
    var productID: String { Self.prefix + rawValue }
    init?(productID: String) {
        guard productID.hasPrefix(Self.prefix) else { return nil }
        self.init(rawValue: String(productID.dropFirst(Self.prefix.count)))
    }
    var name: String { switch self { case .yearly: "Yearly"; case .monthly: "Monthly"; case .lifetime: "Lifetime" } }
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
    /// Whether this Apple Account can still have the two-week trial.
    private(set) var trialEligible = false
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
        if let product = products[.yearly] ?? products[.monthly] { trialEligible = await product.subscription?.isEligibleForIntroOffer ?? false }
        TrialReminder.update(best)
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
            if let product = products[.yearly] ?? products[.monthly] { trialEligible = await product.subscription?.isEligibleForIntroOffer ?? false }
        } catch { message = error.localizedDescription }
    }

    func purchase(_ plan: ProPlan = .yearly) async {
        guard !busy, let product = products[plan] else { return }
        busy = true; message = nil
        defer { busy = false }
        do {
            switch try await product.purchase() {
            case .success(let result):
                guard case .verified(let transaction) = result else { message = "The App Store couldn't confirm that purchase. Try Restore purchases."; return }
                await refresh(); await transaction.finish()
                if !unlocked { message = "The App Store hasn't confirmed Pro yet. Try Restore purchases in a moment." }
                else if standing?.inTrial == true, let end = standing?.periodEnd { message = "Your free trial has started. It ends on \(end.formatted(.dateTime.day().month(.wide)))." }
                else { message = "Hereabouts Pro is unlocked." }
            case .userCancelled: message = "Purchase canceled. Nothing was charged."
            case .pending: message = "Waiting for approval. Everything free still works."
            @unknown default: message = "The App Store didn't say what happened. Try Restore purchases."
            }
        } catch { message = error.localizedDescription }
    }

    func restorePurchases() async {
        guard !busy else { return }
        busy = true; message = nil
        defer { busy = false }
        do { try await AppStore.sync(); await refresh(); message = unlocked ? "Hereabouts Pro restored." : "No Pro purchase was found for this Apple Account." }
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
        content.title = "Your free trial ends \(end.formatted(.dateTime.weekday(.wide)))"
        content.body = "Keep Pro and the \(standing.plan.name.lowercased()) plan starts then. To stop it, cancel in Settings before then."
        let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)))
    }
}
