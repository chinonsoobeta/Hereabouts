import SwiftUI
import StoreKit

struct ProView: View {
    @Environment(ProAccess.self) private var pro
    @Environment(\.dismiss) private var dismiss
    var showsClose = true
    private var foundersPricing: Bool { (Bundle.main.object(forInfoDictionaryKey: "HereaboutsFoundersPricing") as? Bool) ?? false }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if foundersPricing { Stamp(text: "Founder's price", tone: .due) }
                Text("Pay once. Keep it forever.").font(.wbDisplay).foregroundStyle(Theme.ink).accessibilityAddTraits(.isHeader)
                if let product = pro.product {
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .firstTextBaseline, spacing: 14) { price(product); regularPrice(product) }
                        VStack(alignment: .leading, spacing: 8) { price(product); regularPrice(product) }
                    }
                }
                Text(foundersPricing ? "For the first eight weeks. One payment, shared with your family. No subscription, ever." : "One payment, shared with your family. No subscription, ever.")
                    .font(.wbBody).foregroundStyle(Theme.ink)
                VStack(spacing: 0) {
                    allowance("Things you can write down", free: CreationKind.item.freeLimit.description)
                    allowance("Packing kits", free: CreationKind.kit.freeLimit.description)
                    allowance("Receipt scans a month", free: CreationKind.scan.freeLimit.description)
                    NotebookLine(name: "Everything else", detail: "Already free").card()
                }
                StickyNote {
                    Text("Reminders, calendar, backups, Siri and the widget are free for everyone. Pro only takes the limits off. If you never hit them, you never need it.")
                        .font(.wbBody).foregroundStyle(Theme.ink)
                }
                if pro.unlocked {
                    Label("Pro is unlocked. Thank you.", systemImage: "checkmark.seal").font(.wbBody.weight(.bold)).foregroundStyle(Theme.green)
                } else if let product = pro.product {
                    Button("Buy once for \(product.displayPrice)") { Task { await pro.purchase() } }.buttonStyle(PrimaryButtonStyle()).disabled(pro.busy)
                } else {
                    Text("Pro isn't available to buy right now. Everything you've saved stays available.").font(.wbBody).foregroundStyle(Theme.pencil)
                }
                Button("Restore purchases") { Task { await pro.restorePurchases() } }.buttonStyle(SoftButtonStyle()).disabled(pro.busy)
                if pro.busy { ProgressView() }
                if let message = pro.message { Text(message).font(.wbCaption).foregroundStyle(Theme.ink) }
                Text("Limits only apply to adding new things. If a purchase is refunded, everything you've saved stays visible, editable and exportable.").font(.wbCaption).foregroundStyle(Theme.pencil)
                FlowLayout(spacing: 18) {
                    Link("Privacy", destination: Support.privacy).frame(minWidth: 44, minHeight: 44)
                    Link("Terms", destination: Support.terms).frame(minWidth: 44, minHeight: 44)
                    NavigationLink("Export anytime") { LeavingView() }.frame(minWidth: 44, minHeight: 44)
                }.font(.wbBody).foregroundStyle(Theme.purpleInk)
            }.padding(20)
        }
        .background(Theme.paper).navigationTitle("Pro").navigationBarTitleDisplayMode(.inline)
        .scrollEdgeEffectStyle(.hard, for: .top)
        .toolbar {
            if showsClose { ToolbarItem(placement: .cancellationAction) { Button("Close", systemImage: "xmark") { dismiss() }.labelStyle(.iconOnly) } }
        }
        .task { await pro.loadProduct(); await pro.refresh() }
    }
    private func price(_ product: Product) -> some View {
        Text(product.displayPrice).font(.wbPrice).foregroundStyle(Theme.ink)
    }
    @ViewBuilder private func regularPrice(_ product: Product) -> some View {
        // The decision record specifies USD; StoreKit does not provide a future regional price.
        if foundersPricing && product.priceFormatStyle.currencyCode == "USD" {
            let regular = Decimal(999) / 100
            Text(regular.formatted(product.priceFormatStyle)).font(.wbTitle).strikethrough().foregroundStyle(Theme.pencil)
                .accessibilityLabel("Usually \(regular.formatted(product.priceFormatStyle))")
        }
    }
    private func allowance(_ name: String, free: String) -> some View {
        NotebookLine(name: name, detail: "\(free) → No limit").card()
    }
}
