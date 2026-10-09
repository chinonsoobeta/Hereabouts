import SwiftUI
import StoreKit

struct ProView: View {
    @Environment(ProAccess.self) private var pro
    @Environment(LocaliserStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    /// False when pushed from Settings, where the back button already closes it.
    var showsClose = true

    /// During the Founder's launch window the store price is half the regular price.
    private var foundersPricing: Bool { (Bundle.main.object(forInfoDictionaryKey: "HereaboutsFoundersPricing") as? Bool) ?? false }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    IconTile(systemImage: "sparkles", size: 56)
                    Text("Hereabouts Pro").font(.wbDisplay).foregroundStyle(Theme.ink).accessibilityAddTraits(.isHeader)
                    Text("Pay once. Keep it forever. No subscription, ever.").font(.wbBody).foregroundStyle(Theme.secondary)
                }
                VStack(alignment: .leading, spacing: 14) {
                    benefit("infinity", "Unlimited items", "Free covers \(CreationKind.item.freeLimit). You're using \(store.activeItemCount). Archived items never count.")
                    benefit("suitcase", "Unlimited packing kits", "Free covers \(CreationKind.kit.freeLimit).")
                    benefit("doc.text.viewfinder", "Unlimited receipt scans", "Free covers \(CreationKind.scan.freeLimit) a month. You've used \(store.completedScans) this month.")
                    benefit("person.2", "Shared with your family", "Family Sharing is on, so up to six people get Pro.")
                }
                .card()
                VStack(spacing: 12) {
                    if pro.unlocked {
                        Label("Pro is unlocked. Thank you.", systemImage: "checkmark.seal.fill").font(.wbItem).foregroundStyle(Theme.sageInk)
                            .frame(maxWidth: .infinity, minHeight: 52).background(Theme.sage, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    } else if let product = pro.product {
                        if foundersPricing {
                            HStack(spacing: 8) {
                                Pill(text: "Founder's price", tone: .due)
                                Text((product.price * 2).formatted(product.priceFormatStyle)).strikethrough().foregroundStyle(Theme.secondary)
                                    .accessibilityLabel("Usually \((product.price * 2).formatted(product.priceFormatStyle))")
                            }
                        }
                        Button("Unlock lifetime Pro · \(product.displayPrice)") { Task { await pro.purchase() } }
                            .buttonStyle(PrimaryButtonStyle()).disabled(pro.busy)
                        Text("One payment. No subscription, ever. Your library is never locked, even on the free plan.").font(.wbCaption).foregroundStyle(Theme.secondary).multilineTextAlignment(.center)
                    } else {
                        Text("Pro isn't available to buy right now. Everything you've saved stays available.").font(.wbBody).foregroundStyle(Theme.secondary)
                    }
                    Button("Restore purchases") { Task { await pro.restorePurchases() } }
                        .buttonStyle(SoftButtonStyle()).disabled(pro.busy)
                    if pro.busy { ProgressView() }
                    if let message = pro.message { Text(message).font(.wbCaption).foregroundStyle(Theme.ink).multilineTextAlignment(.center) }
                }
                Text("Limits only apply to adding new things. If a purchase is refunded, everything you've saved stays visible, editable and exportable.").font(.wbCaption).foregroundStyle(Theme.secondary)
                HStack(spacing: 8) {
                    Link("Privacy policy", destination: Support.privacy).frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
                    Link("Terms of use", destination: Support.terms).frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
                }
                .font(.wbBody)
            }
            .padding(20)
        }
        .background(Theme.ground)
        .navigationTitle("Pro").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showsClose { ToolbarItem(placement: .cancellationAction) { Button("Close", systemImage: "xmark") { dismiss() }.labelStyle(.iconOnly) } }
        }
        .task { await pro.loadProduct(); await pro.refresh() }
    }

    private func benefit(_ symbol: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol).font(.system(size: 18, weight: .semibold)).foregroundStyle(Theme.purpleInk).frame(width: 28).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.wbItem).foregroundStyle(Theme.ink)
                Text(detail).font(.wbCaption).foregroundStyle(Theme.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
