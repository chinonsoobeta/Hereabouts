import StoreKit
import Observation

enum CreationKind { case item, kit, scan }

@MainActor @Observable final class ProAccess {
    static let productID = "dev.localiser.pro.lifetime"
    private(set) var unlocked = false
    private(set) var product: Product?
    private(set) var busy = false
    var message: String?

    func allows(_ kind: CreationKind, count: Int) -> Bool {
        let limit = switch kind { case .item: 50; case .kit: 1; case .scan: 3 }
        return unlocked || count < limit
    }

    func refresh() async {
        var entitled = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result, transaction.productID == Self.productID,
               transaction.revocationDate == nil, transaction.productType == .nonConsumable { entitled = true }
        }
        unlocked = entitled
    }

    func observeTransactions() async {
        await refresh()
        for await result in Transaction.updates {
            guard !Task.isCancelled else { return }
            if case .verified(let transaction) = result, transaction.productID == Self.productID {
                unlocked = transaction.revocationDate == nil && transaction.productType == .nonConsumable
                await transaction.finish()
            }
        }
    }

    func loadProduct() async {
        do {
            product = try await Product.products(for: [Self.productID]).first { $0.type == .nonConsumable }
            if product == nil { message = "The lifetime product is unavailable. You can keep using the free features and export your library." }
        } catch { message = error.localizedDescription }
    }

    func purchase() async {
        guard !busy, let product else { return }
        busy = true; message = nil
        defer { busy = false }
        do {
            switch try await product.purchase() {
            case .success(let result):
                guard case .verified(let transaction) = result else { message = "The purchase could not be verified. Restore purchases or try again."; return }
                await refresh(); await transaction.finish()
                message = unlocked ? "Localiser Pro is unlocked." : "The purchase is not currently entitled. Try restoring purchases."
            case .userCancelled: message = "Purchase canceled. Your library is unchanged."
            case .pending: message = "Purchase awaiting approval. Free features remain available."
            @unknown default: message = "Purchase status is unavailable. Try restoring purchases."
            }
        } catch { message = error.localizedDescription }
    }

    func restorePurchases() async {
        guard !busy else { return }
        busy = true; message = nil
        defer { busy = false }
        do { try await AppStore.sync(); await refresh(); message = unlocked ? "Localiser Pro restored." : "No current lifetime purchase was found for this Apple account." }
        catch { message = error.localizedDescription }
    }
}
