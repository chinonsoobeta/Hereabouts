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
                Text("No limit on what you write down.").font(.wbBody).foregroundStyle(Theme.pencil)
                VStack(spacing: 0) {
                    allowance("Things you can write down", free: CreationKind.item.freeLimit.description)
                    allowance("Packing kits", free: CreationKind.kit.freeLimit.description)
                    allowance("Homes", free: CreationKind.home.freeLimit.description)
                    NotebookLine(name: "Sharing with your household", detail: "Coming later", strongDetail: true).card()
                    NotebookLine(name: "Everything else", detail: "Already free", strongDetail: true).card()
                }
                if let standing = pro.standing {
                    owned(standing)
                } else {
                    if pro.lapsed {
                        StickyNote { Text("Your subscription ended. Everything you wrote down is still here, and you can still find, change and export it.").font(.wbBody).foregroundStyle(Theme.ink) }
                    }
                    choosing
                }
                Button("Restore purchases") { Task { await pro.restorePurchases() } }.buttonStyle(SoftButtonStyle()).disabled(pro.busy)
                if pro.busy { ProgressView() }
                if let message = pro.message { Text(message).font(.wbCaption).foregroundStyle(Theme.ink) }
                StickyNote {
                    Text("Reminders, backups, Siri and Spotlight are free for everyone. Pro only takes the limits off. If you never hit them, you never need it.")
                        .font(.wbBody).foregroundStyle(Theme.ink)
                }
                Text("Limits only apply to adding new things. If Pro ends or a purchase is refunded, everything you've saved stays visible, editable and exportable.").font(.wbCaption).foregroundStyle(Theme.pencil)
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
                Text(ProPricing.terms(plan: plan, price: product.displayPrice, period: ProPricing.period(product), trial: pro.trialEligible))
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
                    HStack(spacing: 8) {
                        Text(option.name).font(.wbItem).foregroundStyle(Theme.ink)
                        if option.isSubscription && pro.trialEligible { Stamp(text: "2 weeks free", tone: .purple) }
                    }
                    Text(detail(option)).font(.wbCaption).foregroundStyle(Theme.pencil).multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
            .card()
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(selected ? Theme.purpleInk : .clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    private func detail(_ option: ProPlan) -> String {
        guard let product = pro.product(option) else { return "" }
        switch option {
        case .yearly:
            var parts = ["\(product.displayPrice) a year"]
            parts.append("\(ProPricing.monthly(product.price).formatted(product.priceFormatStyle)) a month")
            if let monthly = pro.product(.monthly), let saving = ProPricing.saving(yearly: product.price, monthly: monthly.price) { parts.append("Save \(saving)%") }
            return parts.joined(separator: " · ")
        case .monthly: return "\(product.displayPrice) a month"
        case .lifetime: return "\(product.displayPrice) once. Never renews."
        }
    }

    private func buttonTitle(_ product: Product) -> String {
        switch plan {
        case .lifetime: "Buy once for \(product.displayPrice)"
        default: pro.trialEligible ? "Try free for 2 weeks" : "Subscribe for \(product.displayPrice) \(ProPricing.period(product))"
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
        NotebookLine(name: name, detail: "\(free) → No limit", strongDetail: true).card()
    }
}

/// Pricing sentences, kept apart from the view so they can be tested.
enum ProPricing {
    static func period(_ product: Product) -> String {
        product.subscription?.subscriptionPeriod.unit == .month ? "a month" : "a year"
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
    static func terms(plan: ProPlan, price: String, period: String, trial: Bool) -> String {
        guard plan.isSubscription else { return "One payment, shared with your family. Nothing renews." }
        let start = trial ? "Free for 2 weeks, then \(price) \(period)." : "\(price) \(period)."
        return start + " Renews automatically until you cancel. Cancel any time in Settings, at least a day before it renews."
    }
}

extension ProStanding {
    /// "Pro, renews 12 Nov", "Free trial, ends 26 Oct", "Lifetime. Thank you."
    var summary: String {
        let shared = familyShared ? " Shared by your family." : ""
        guard plan.isSubscription, let end = periodEnd else { return "Lifetime. Thank you." + shared }
        let day = end.formatted(.dateTime.day().month(.abbreviated))
        if inTrial { return (willRenew ? "Free trial, ends \(day)" : "Free trial until \(day). It won't renew.") + shared }
        return (willRenew ? "Pro, renews \(day)" : "Pro until \(day). It won't renew.") + shared
    }
}
