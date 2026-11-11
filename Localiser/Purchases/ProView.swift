import SwiftUI
import StoreKit

struct ProView: View {
    @Environment(ProAccess.self) private var pro
    @Environment(LocaliserStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var showsClose = true
    @State private var plan: ProPlan = .yearly
    @State private var managing = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Hereabouts Pro").font(.wbDisplay).foregroundStyle(Theme.ink).accessibilityAddTraits(.isHeader)
                    Text("Write down as many things as you need.").font(.wbBody).foregroundStyle(Theme.pencil)
                }
                VStack(spacing: 14) {
                    PlanCardView(card: PlanCard.make(standing: pro.standing, lapsed: pro.lapsed, counts: counts, price: currentPrice))
                    if let standing = pro.standing { owned(standing) }
                }
                ProComparison(onPro: pro.standing != nil)
                if pro.standing == nil { choosing }
                VStack(alignment: .leading, spacing: 16) {
                    Button("Restore purchases") { Task { await pro.restorePurchases() } }.buttonStyle(SoftButtonStyle()).disabled(pro.busy)
                    if pro.busy { ProgressView().frame(maxWidth: .infinity) }
                    if let message = pro.message { Text(message).font(.wbCaption).foregroundStyle(Theme.ink).fixedSize(horizontal: false, vertical: true) }
                    Text("Limits only apply when you add things. If Pro ends or you get a refund, you can still see, edit and export everything you've saved.")
                        .font(.wbCaption).foregroundStyle(Theme.pencil).fixedSize(horizontal: false, vertical: true)
                    FlowLayout(spacing: 18) {
                        Link("Privacy Policy", destination: Support.privacy).frame(minWidth: 44, minHeight: 44)
                        Link("Terms of Use", destination: Support.terms).frame(minWidth: 44, minHeight: 44)
                        NavigationLink("Export anytime") { LeavingView() }.frame(minWidth: 44, minHeight: 44)
                    }.font(.wbBody).foregroundStyle(Theme.purpleInk)
                }
            }
            .padding(20)
            // A readable column on the iPad and the Duo's inner screen.
            .frame(maxWidth: 640, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.paper).navigationTitle("Pro").navigationBarTitleDisplayMode(.inline)
        .scrollEdgeEffectStyle(.hard, for: .top)
        .toolbar {
            if showsClose { ToolbarItem(placement: .cancellationAction) { Button("Close", systemImage: "xmark") { dismiss() }.labelStyle(.iconOnly) } }
        }
        .manageSubscriptionsSheet(isPresented: $managing)
        .task { await pro.loadProduct(); await pro.refresh(); await pro.checkRenewingSubscription() }
    }

    private var counts: PlanCard.Counts {
        PlanCard.Counts(things: store.activeItemCount, kits: store.kits.count, homes: store.homes.count)
    }

    /// What the plan you're on costs, as "$19.99 a year". Nil for Lifetime and the free plan.
    private var currentPrice: String? {
        guard let standing = pro.standing, standing.plan.isSubscription, let product = pro.product(standing.plan) else { return nil }
        return ProPricing.price(product)
    }

    @ViewBuilder private var choosing: some View {
        let available = ProPlan.allCases.filter { pro.product($0) != nil }
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                SectionHeading(title: available.count == ProPlan.allCases.count ? String(localized: "Three ways to pay for Pro") : String(localized: "Ways to pay for Pro"))
                Text("The same Pro in each. Only the billing differs.").font(.wbCaption).foregroundStyle(Theme.pencil).fixedSize(horizontal: false, vertical: true)
            }
            if available.isEmpty {
                if pro.productChecked { Text("Pro isn't available to buy right now. Try again later.").font(.wbBody).foregroundStyle(Theme.pencil) }
                else { ProgressView().frame(maxWidth: .infinity) }
            } else {
                ForEach(available) { option in planRow(option) }
                if let product = pro.product(plan) {
                    Button(buttonTitle(product)) { Task { await pro.purchase(plan) } }.buttonStyle(PrimaryButtonStyle()).disabled(pro.busy).padding(.top, 8)
                    Text(ProPricing.terms(plan: plan, price: product.displayPrice, period: ProPricing.period(product), trial: pro.trial(plan)))
                        .font(.wbCaption).foregroundStyle(Theme.pencil).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func planRow(_ option: ProPlan) -> some View {
        let selected = option == plan
        let lines = detail(option)
        return Button { plan = option } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle").font(.title3).foregroundStyle(Theme.purpleInk).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    // At the largest text sizes the stamp wraps below the name instead of squeezing it.
                    FlowLayout(spacing: 8) {
                        Text(option.name).font(.wbItem).foregroundStyle(Theme.ink)
                        if let trial = pro.trial(option) { Stamp(text: String(localized: "\(trial) free"), tone: .purple) }
                    }
                    // Each fact on its own line: the price first, then what it works out to.
                    ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                        Text(line).font(index == 0 ? .wbCaption.weight(.bold) : .wbCaption).foregroundStyle(Theme.pencil)
                            .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                    }
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

    /// The lines under a plan's name: "$19.99 a year", then "$1.67 a month, 44% less than Monthly".
    private func detail(_ option: ProPlan) -> [String] {
        guard let product = pro.product(option) else { return [] }
        switch option {
        case .yearly:
            let perMonth = ProPricing.monthly(product.price).formatted(product.priceFormatStyle)
            if let monthly = pro.product(.monthly), let saving = ProPricing.saving(yearly: product.price, monthly: monthly.price) {
                return [ProPricing.price(product), String(localized: "\(perMonth) a month, \(saving)% less than Monthly")]
            }
            return [ProPricing.price(product), String(localized: "\(perMonth) a month")]
        case .monthly: return [ProPricing.price(product)]
        case .lifetime: return [String(localized: "\(product.displayPrice) once"), String(localized: "Never renews.")]
        }
    }

    private func buttonTitle(_ product: Product) -> String {
        switch plan {
        case .lifetime: String(localized: "Buy once for \(product.displayPrice)")
        default: pro.trial(plan).map { String(localized: "Try free for \($0)") } ?? String(localized: "Subscribe for \(product.displayPrice) \(ProPricing.period(product))")
        }
    }

    @ViewBuilder private func owned(_ standing: ProStanding) -> some View {
        if pro.subscribedAlongsideLifetime {
            StickyNote { Text("You have lifetime Pro, and a subscription that's still renewing. Cancel the subscription so you aren't charged again.").font(.wbBody).foregroundStyle(Theme.ink) }
        }
        if (standing.plan.isSubscription && !standing.familyShared) || pro.subscribedAlongsideLifetime {
            Button("Manage subscription") { managing = true }.buttonStyle(SoftButtonStyle())
        }
    }
}

/// What the "Your plan" card says, kept apart from the view so it can be tested. Each fact is a line of its own
/// (name, leader, value), never joined with dots (owner, 10 Nov).
struct PlanCard: Equatable {
    struct Counts: Equatable { var things = 0, kits = 0, homes = 0 }
    struct Fact: Equatable, Identifiable {
        var name: String
        var value: String
        /// Over a free limit, or a subscription that is ending.
        var warning = false
        var id: String { name }
    }
    var title: String
    var facts: [Fact]
    var note: String?

    static func date(_ date: Date) -> String { date.formatted(.dateTime.day().month(.abbreviated).year()) }

    static func make(standing: ProStanding?, lapsed: Bool, counts: Counts, price: String?) -> PlanCard {
        guard let standing else {
            let facts = [allowance(String(localized: "Things"), counts.things, .item),
                         allowance(String(localized: "Packing kits"), counts.kits, .kit),
                         allowance(String(localized: "Homes"), counts.homes, .home)]
            let note = lapsed ? String(localized: "Your subscription ended. Everything you saved is still here. You can still find, edit and export it.") : nil
            return PlanCard(title: String(localized: "Free"), facts: facts, note: note)
        }
        var facts: [Fact] = []
        if standing.familyShared { facts.append(Fact(name: String(localized: "Shared by"), value: String(localized: "Your family"))) }
        guard standing.plan.isSubscription else {
            facts.append(Fact(name: String(localized: "Paid"), value: String(localized: "Lifetime, once")))
            facts.append(Fact(name: String(localized: "Renews"), value: String(localized: "Never")))
            return PlanCard(title: String(localized: "Pro"), facts: facts)
        }
        let ending = String(localized: "It won't renew. After that you're on Free, and everything you've saved stays.")
        let end = standing.periodEnd.map(date)
        if standing.inTrial {
            if let end { facts.append(Fact(name: String(localized: "Trial ends"), value: end)) }
            if standing.willRenew, let price { facts.append(Fact(name: String(localized: "Then"), value: price)) }
            // Someone in the family can't cancel the organizer's trial, so they aren't told to.
            let note = !standing.willRenew ? ending : standing.familyShared ? nil : String(localized: "Cancel at least a day before it ends and you pay nothing.")
            return PlanCard(title: String(localized: "Pro, free trial"), facts: facts, note: note)
        }
        facts.append(Fact(name: String(localized: "Paid"), value: standing.plan.name))
        if let end {
            facts.append(standing.willRenew ? Fact(name: String(localized: "Renews"), value: end) : Fact(name: String(localized: "Ends"), value: end, warning: true))
        }
        if standing.willRenew, !standing.familyShared, let price { facts.append(Fact(name: String(localized: "Price"), value: price)) }
        return PlanCard(title: String(localized: "Pro"), facts: facts, note: standing.willRenew ? nil : ending)
    }

    private static func allowance(_ name: String, _ count: Int, _ kind: CreationKind) -> Fact {
        Fact(name: name, value: String(localized: "\(count) of \(kind.freeLimit)"), warning: count > kind.freeLimit)
    }
}

/// The plan you're on, at the top of the Pro screen.
struct PlanCardView: View {
    let card: PlanCard
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Your plan").font(.wbLabel).textCase(.uppercase).tracking(1.54).foregroundStyle(Theme.pencil)
                Text(card.title).font(.wbTitle).foregroundStyle(Theme.ink).fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine).accessibilityAddTraits(.isHeader)
            .padding(.bottom, 10)
            ForEach(card.facts) { fact in
                NotebookLine(name: fact.name, detail: fact.value, strongDetail: true, detailColor: fact.warning ? Theme.amber : nil)
                    .padding(.vertical, 10)
                    .overlay(alignment: .top) { Rectangle().fill(Theme.rule).frame(height: 1) }
                    .accessibilityElement(children: .combine)
            }
            if let note = card.note {
                Text(note).font(.wbCaption).foregroundStyle(Theme.pencil).fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10).frame(maxWidth: .infinity, alignment: .leading)
                    .overlay(alignment: .top) { Rectangle().fill(Theme.rule).frame(height: 1) }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.lilacPaper, in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .contain)
    }
}

/// Free and Pro side by side, with the column for the plan you're on shaded and labelled.
/// At the accessibility text sizes each row reads as a line of text instead of a table.
struct ProComparison: View {
    let onPro: Bool
    @Environment(\.dynamicTypeSize) private var textSize
    @ScaledMetric(relativeTo: .body) private var freeWidth: CGFloat = 76
    @ScaledMetric(relativeTo: .body) private var proWidth: CGFloat = 96

    private enum Mark: Equatable { case text(String), included, notIncluded }
    private struct Row: Identifiable {
        let name: String
        var caption: String?
        let free: Mark
        let pro: Mark
        var id: String { name }
    }

    private var rows: [Row] {
        let noLimit = String(localized: "No limit")
        return [
            Row(name: String(localized: "Things"), free: .text(CreationKind.item.freeLimit.formatted()), pro: .text(noLimit)),
            Row(name: String(localized: "Packing kits"), free: .text(CreationKind.kit.freeLimit.formatted()), pro: .text(noLimit)),
            Row(name: String(localized: "Homes"), free: .text(CreationKind.home.freeLimit.formatted()), pro: .text(noLimit)),
            Row(name: String(localized: "Weekly automatic backups"), free: .notIncluded, pro: .included),
            Row(name: String(localized: "Share Pro with your family"), free: .notIncluded, pro: .included),
            Row(name: String(localized: "Everything else"),
                caption: String(localized: "Voice memos, lending, trips, reminders, Siri, Spotlight, the widget, manual backups and export"),
                free: .included, pro: .included),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeading(title: String(localized: "Free and Pro"))
            if textSize.isAccessibilitySize { lines } else { table }
            Text("Sharing one notebook with your household is coming later.").font(.wbCaption).foregroundStyle(Theme.pencil).fixedSize(horizontal: false, vertical: true)
        }
    }

    private var table: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                Spacer(minLength: 0)
                header(String(localized: "Free"), current: !onPro, ink: Theme.ink).frame(width: freeWidth)
                header(String(localized: "Pro"), current: onPro, ink: Theme.purpleInk).frame(width: proWidth)
            }
            .overlay(alignment: .bottom) { rule }
            ForEach(rows) { row in
                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(row.name).font(.wbItem).foregroundStyle(Theme.ink).fixedSize(horizontal: false, vertical: true)
                        if let caption = row.caption { Text(caption).font(.wbCaption).foregroundStyle(Theme.pencil).fixedSize(horizontal: false, vertical: true) }
                    }
                    .padding(.vertical, 12).padding(.trailing, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    mark(row.free).frame(width: freeWidth)
                    mark(row.pro).frame(width: proWidth)
                }
                .overlay(alignment: .bottom) { if row.id != rows.last?.id { rule } }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(row.caption.map { "\(row.name). \($0)" } ?? row.name)
                .accessibilityValue(spoken(row))
            }
        }
        // The shaded column runs the table's full height, with rounded ends.
        .background(alignment: .trailing) {
            RoundedRectangle(cornerRadius: 12).fill(Theme.lilacPaper)
                .frame(width: onPro ? proWidth : freeWidth)
                .padding(.trailing, onPro ? 0 : proWidth)
        }
    }

    private var lines: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(rows) { row in
                VStack(alignment: .leading, spacing: 6) {
                    Text(row.name).font(.wbItem).foregroundStyle(Theme.ink)
                    if let caption = row.caption { Text(caption).font(.wbCaption).foregroundStyle(Theme.pencil) }
                    Text(spoken(row)).font(.wbBody).foregroundStyle(Theme.ink)
                }
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, 12).frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .bottom) { rule }
                .accessibilityElement(children: .combine)
            }
        }
    }

    private var rule: some View { Rectangle().fill(Theme.rule).frame(height: 1) }

    private func header(_ title: String, current: Bool, ink: Color) -> some View {
        VStack(spacing: 2) {
            Text(title).font(.wbItem).foregroundStyle(ink)
            if current {
                Text("Your plan").font(.wbLabel).textCase(.uppercase).tracking(1).foregroundStyle(Theme.purpleInk)
            }
        }
        .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
        .padding(.vertical, 12).padding(.horizontal, 4)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private func mark(_ mark: Mark) -> some View {
        switch mark {
        case .text(let text):
            Text(text).font(.wbBody.weight(.bold)).foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true).padding(.horizontal, 4)
        case .included:
            Image(systemName: "checkmark").font(.body.weight(.bold)).foregroundStyle(Theme.green)
        case .notIncluded:
            Image(systemName: "minus").font(.body.weight(.bold)).foregroundStyle(Theme.pencil)
        }
    }

    private func said(_ mark: Mark) -> String {
        switch mark {
        case .text(let text): text
        case .included: String(localized: "Included")
        case .notIncluded: String(localized: "Not included")
        }
    }

    private func spoken(_ row: Row) -> String { String(localized: "Free: \(said(row.free)). Pro: \(said(row.pro)).") }
}

/// Pricing sentences, kept apart from the view so they can be tested.
enum ProPricing {
    /// "$19.99 a year" or "$2.99 a month", for a subscription.
    static func price(_ product: Product) -> String {
        product.subscription?.subscriptionPeriod.unit == .month ? String(localized: "\(product.displayPrice) a month") : String(localized: "\(product.displayPrice) a year")
    }
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
