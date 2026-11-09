import SwiftUI
import StoreKit

struct ProView: View {
    @Environment(ProAccess.self) private var pro
    @Environment(\.dismiss) private var dismiss
    var showsClose = true
    @State private var plan: ProPlan = .yearly
    @State private var managing = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("Hereabouts Pro").font(.wbDisplay).foregroundStyle(Theme.ink).accessibilityAddTraits(.isHeader)
                Text("Write down as many things as you need.").font(.wbBody).foregroundStyle(Theme.pencil)
                VStack(spacing: 0) {
                    allowance(String(localized: "Things you can write down"), free: CreationKind.item.freeLimit.description)
                    allowance(String(localized: "Packing kits"), free: CreationKind.kit.freeLimit.description)
                    allowance(String(localized: "Homes"), free: CreationKind.home.freeLimit.description)
                    NotebookLine(name: String(localized: "Share Pro with your family"), detail: String(localized: "Included"), strongDetail: true).card()
                    NotebookLine(name: String(localized: "Share with your household"), detail: String(localized: "Coming later"), strongDetail: true).card()
                    NotebookLine(name: String(localized: "Everything else"), detail: String(localized: "Already free"), strongDetail: true).card()
                }
                if let standing = pro.standing {
                    owned(standing)
                } else {
                    if pro.lapsed {
                        StickyNote { Text("Your subscription ended. Everything you saved is still here. You can still find, edit and export it.").font(.wbBody).foregroundStyle(Theme.ink) }
                    }
                    choosing
                }
                Button("Restore purchases") { Task { await pro.restorePurchases() } }.buttonStyle(SoftButtonStyle()).disabled(pro.busy)
                if pro.busy { ProgressView() }
                if let message = pro.message { Text(message).font(.wbCaption).foregroundStyle(Theme.ink) }
                StickyNote {
                    Text("Manual backups, reminders, Siri and Spotlight are free. Pro removes the limits and adds weekly backups.")
                        .font(.wbBody).foregroundStyle(Theme.ink)
                }
                Text("Limits only apply when you add things. If Pro ends or you get a refund, you can still see, edit and export everything you've saved.").font(.wbCaption).foregroundStyle(Theme.pencil)
                FlowLayout(spacing: 18) {
                    Link("Privacy Policy", destination: Support.privacy).frame(minWidth: 44, minHeight: 44)
                    Link("Terms of Use", destination: Support.terms).frame(minWidth: 44, minHeight: 44)
                    NavigationLink("Export anytime") { LeavingView() }.frame(minWidth: 44, minHeight: 44)
                }.font(.wbBody).foregroundStyle(Theme.purpleInk)
            }.padding(20)
        }
        .background(Theme.paper).navigationTitle("Pro").navigationBarTitleDisplayMode(.inline)
        .scrollEdgeEffectStyle(.hard, for: .top)
        .toolbar {
            if showsClose { ToolbarItem(placement: .cancellationAction) { Button("Close", systemImage: "xmark") { dismiss() }.labelStyle(.iconOnly) } }
        }
        .manageSubscriptionsSheet(isPresented: $managing)
        .task { await pro.loadProduct(); await pro.refresh(); await pro.checkRenewingSubscription() }
    }

    @ViewBuilder private var choosing: some View {
        let available = ProPlan.allCases.filter { pro.product($0) != nil }
        if available.isEmpty {
            if pro.productChecked { Text("Pro isn't available to buy right now. Try again later.").font(.wbBody).foregroundStyle(Theme.pencil) }
            else { ProgressView().frame(maxWidth: .infinity) }
        } else {
            VStack(spacing: 10) {
                ForEach(available) { option in planRow(option) }
            }
            if let product = pro.product(plan) {
                Button(buttonTitle(product)) { Task { await pro.purchase(plan) } }.buttonStyle(PrimaryButtonStyle()).disabled(pro.busy)
                Text(ProPricing.terms(plan: plan, price: product.displayPrice, period: ProPricing.period(product), trial: pro.trial(plan)))
                    .font(.wbCaption).foregroundStyle(Theme.pencil)
            }
        }
    }

    private func planRow(_ option: ProPlan) -> some View {
        let selected = option == plan
        return Button { plan = option } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle").font(.title3).foregroundStyle(Theme.purpleInk).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    // At the largest text sizes the stamp wraps below the name instead of squeezing it.
                    FlowLayout(spacing: 8) {
                        Text(option.name).font(.wbItem).foregroundStyle(Theme.ink)
                        if let trial = pro.trial(option) { Stamp(text: String(localized: "\(trial) free"), tone: .purple) }
                    }
                    Text(detail(option)).font(.wbCaption).foregroundStyle(Theme.pencil).multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
            .card()
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(selected ? Theme.purpleInk : .clear, lineWidth: 2))
        }
        .buttonStyle(.plain).hoverEffect()
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    private func detail(_ option: ProPlan) -> String {
        guard let product = pro.product(option) else { return "" }
        switch option {
        case .yearly:
            var parts = [String(localized: "\(product.displayPrice) a year")]
            parts.append(String(localized: "\(ProPricing.monthly(product.price).formatted(product.priceFormatStyle)) a month"))
            if let monthly = pro.product(.monthly), let saving = ProPricing.saving(yearly: product.price, monthly: monthly.price) { parts.append(String(localized: "Save \(saving)%")) }
            return parts.joined(separator: " · ")
        case .monthly: return String(localized: "\(product.displayPrice) a month")
        case .lifetime: return String(localized: "\(product.displayPrice) once. Never renews.")
        }
    }

    private func buttonTitle(_ product: Product) -> String {
        switch plan {
        case .lifetime: String(localized: "Buy once for \(product.displayPrice)")
        default: pro.trial(plan).map { String(localized: "Try free for \($0)") } ?? String(localized: "Subscribe for \(product.displayPrice) \(ProPricing.period(product))")
        }
    }

    @ViewBuilder private func owned(_ standing: ProStanding) -> some View {
        Label(standing.summary, systemImage: "checkmark.seal").font(.wbBody.weight(.bold)).foregroundStyle(Theme.green)
        if pro.subscribedAlongsideLifetime {
            StickyNote { Text("You have lifetime Pro, and a subscription that's still renewing. Cancel the subscription so you aren't charged again.").font(.wbBody).foregroundStyle(Theme.ink) }
        }
        if (standing.plan.isSubscription && !standing.familyShared) || pro.subscribedAlongsideLifetime {
            Button("Manage subscription") { managing = true }.buttonStyle(SoftButtonStyle())
        }
    }

    private func allowance(_ name: String, free: String) -> some View {
        NotebookLine(name: name, detail: String(localized: "\(free) → No limit"), strongDetail: true).card()
    }
}

/// Pricing sentences, kept apart from the view so they can be tested.
enum ProPricing {
    static func period(_ product: Product) -> String {
        product.subscription?.subscriptionPeriod.unit == .month ? String(localized: "a month") : String(localized: "a year")
    }
    /// "3 days", "2 weeks", "1 month": how long a free trial lasts.
    static func trialLength(value: Int, unit: Product.SubscriptionPeriod.Unit) -> String {
        switch unit {
        // Some iOS versions report a two-week trial as 14 days; say weeks, as the listing does.
        case .day where value >= 7 && value % 7 == 0: return String(localized: "\(value / 7) weeks")
        case .day: return String(localized: "\(value) days")
        case .week: return String(localized: "\(value) weeks")
        case .month: return String(localized: "\(value) months")
        case .year: return String(localized: "\(value) years")
        @unknown default: return String(localized: "\(value) periods")
        }
    }
    static func monthly(_ yearly: Decimal) -> Decimal {
        var result = Decimal(), value = yearly / 12
        NSDecimalRound(&result, &value, 2, .plain)
        return result
    }
    /// Whole-percent saving of yearly over twelve months, rounded down so it never overstates.
    static func saving(yearly: Decimal, monthly: Decimal) -> Int? {
        let year = NSDecimalNumber(decimal: monthly * 12).doubleValue
        guard year > 0 else { return nil }
        let percent = Int(((1 - NSDecimalNumber(decimal: yearly).doubleValue / year) * 100).rounded(.down))
        return percent > 0 ? percent : nil
    }
    static func terms(plan: ProPlan, price: String, period: String, trial: String?) -> String {
        guard plan.isSubscription else { return String(localized: "Pay once. Share with your family. No renewal.") }
        let start = trial.map { String(localized: "Free for \($0), then \(price) \(period).") } ?? "\(price) \(period)."
        return start + String(localized: " Renews automatically until you cancel. Cancel in Settings at least a day before it renews.")
    }
}

extension ProStanding {
    /// "Pro, renews 12 Nov", "Free trial, ends 26 Oct", "Lifetime. Thank you."
    var summary: String {
        let shared = familyShared ? String(localized: " Shared by your family.") : ""
        guard plan.isSubscription, let end = periodEnd else { return String(localized: "Lifetime Pro.") + shared }
        let day = end.formatted(.dateTime.day().month(.abbreviated))
        if inTrial { return (willRenew ? String(localized: "Free trial, ends \(day)") : String(localized: "Free trial until \(day). It won't renew.")) + shared }
        return (willRenew ? String(localized: "Pro, renews \(day)") : String(localized: "Pro until \(day). It won't renew.")) + shared
    }
}
