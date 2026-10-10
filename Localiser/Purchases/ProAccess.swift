import StoreKit
import Observation

enum CreationKind {
    case item, kit, scan
    /// Free-tier allowance. Pro removes every limit; nothing else is gated.
    var freeLimit: Int { switch self { case .item: 200; case .kit: 2; case .scan: 5 } }
}

@MainActor @Observable final class ProAccess {
    static let productID = "dev.localiser.pro.lifetime"
    private(set) var unlocked = false
    private(set) var product: Product?
    private(set) var busy = false
    var message: String?

    func allows(_ kind: CreationKind, count: Int) -> Bool {
        unlocked || count < kind.freeLimit
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
            // When the product is missing, the Pro screen says so itself.
            product = try await Product.products(for: [Self.productID]).first { $0.type == .nonConsumable }
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
                message = unlocked ? "Hereabouts Pro is unlocked." : "The purchase is not currently entitled. Try restoring purchases."
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
        do { try await AppStore.sync(); await refresh(); message = unlocked ? "Hereabouts Pro restored." : "No current lifetime purchase was found for this Apple account." }
        catch { message = error.localizedDescription }
    }
}
