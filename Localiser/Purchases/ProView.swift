import SwiftUI

struct ProView: View {
    @Environment(ProAccess.self) private var pro
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        Form {
            Section {
                Label("Localiser Pro", systemImage: "sparkles").font(.title2.bold())
                Text("Save more belongings, reusable kits and successful scans with one lifetime purchase.")
                Text("Free: 50 saved items, 1 kit and 3 successful scans. Trips, manual dates, existing records and export stay available.").font(.footnote).foregroundStyle(Theme.secondary)
            }
            Section {
                if pro.unlocked { Label("Pro is unlocked", systemImage: "checkmark.circle") }
                else if let product = pro.product {
                    Button("Unlock lifetime Pro · \(product.displayPrice)") { Task { await pro.purchase() } }.disabled(pro.busy)
                    Text("One purchase. No subscription.").font(.footnote)
                } else { Text("Purchase unavailable in this build or storefront.").foregroundStyle(Theme.secondary) }
                Button("Restore purchases") { Task { await pro.restorePurchases() } }.disabled(pro.busy)
                if pro.busy { ProgressView() }
                if let message = pro.message { Text(message).font(.footnote) }
            }
            Section { Text("If a purchase is refunded or becomes unavailable, your saved records remain visible and editable. You can always export them. Limits apply to new records and successful scans.").font(.footnote) }
        }
        .groundBackground().navigationTitle("Localiser Pro").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close", systemImage: "xmark") { dismiss() }.labelStyle(.iconOnly) } }
        .task { await pro.loadProduct(); await pro.refresh() }
    }
}
