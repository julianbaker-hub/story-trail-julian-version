import Foundation
import StoreKit

@MainActor
final class PurchaseStore: ObservableObject {
    @Published private(set) var products: [Product] = []
    @Published private(set) var purchasedProductIDs: Set<String>
    @Published private(set) var isLoading = false
    @Published private(set) var purchasingProductID: String?
    @Published private(set) var errorMessage: String?

    private let accessPolicy: TourAccessPolicy
    private let defaults: UserDefaults
    private let cachedEntitlementsKey = "verified-purchase-product-ids"
    private var transactionUpdatesTask: Task<Void, Never>?

    init(
        accessPolicy: TourAccessPolicy = TourAccessPolicy(),
        defaults: UserDefaults = .standard,
        startsStoreTasks: Bool = true,
    ) {
        self.accessPolicy = accessPolicy
        self.defaults = defaults
        purchasedProductIDs = Set(defaults.stringArray(forKey: cachedEntitlementsKey) ?? [])

        guard startsStoreTasks else { return }
        transactionUpdatesTask = observeTransactionUpdates()
        Task { await prepareStore() }
    }

    deinit {
        transactionUpdatesTask?.cancel()
    }

    func hasAccess(to tour: Tour) -> Bool {
        accessPolicy.hasAccess(to: tour.id, purchasedProductIDs: purchasedProductIDs)
    }

    func product(for tour: Tour) -> Product? {
        guard let productID = PurchaseConfiguration.productID(for: tour.id) else { return nil }
        return products.first { $0.id == productID }
    }

    var allToursProduct: Product? {
        products.first { $0.id == PurchaseConfiguration.allToursProductID }
    }

    func accessLabel(for tour: Tour) -> String {
        if tour.id == PurchaseConfiguration.demoTourID {
            return "FREE DEMO"
        }
        if hasAccess(to: tour) {
            return "OWNED"
        }
        return product(for: tour)?.displayPrice.uppercased() ?? "PAID TOUR"
    }

    func purchaseTour(_ tour: Tour) async {
        guard let product = product(for: tour) else {
            errorMessage = "This tour is not available for purchase right now. Please try again later."
            return
        }
        await purchase(product)
    }

    func purchaseAllTours() async {
        guard let product = allToursProduct else {
            errorMessage = "The all-tours bundle is not available right now. Please try again later."
            return
        }
        await purchase(product)
    }

    func restorePurchases() async {
        isLoading = true
        errorMessage = nil
        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            errorMessage = "We couldn't restore purchases. Check your connection and try again."
        }
        isLoading = false
    }

    func clearError() {
        errorMessage = nil
    }

    private func prepareStore() async {
        isLoading = true
        async let loadedProducts: Void = loadProducts()
        async let loadedEntitlements: Void = refreshEntitlements()
        _ = await (loadedProducts, loadedEntitlements)
        isLoading = false
    }

    private func loadProducts() async {
        do {
            products = try await Product.products(for: PurchaseConfiguration.productIDs)
                .sorted { lhs, rhs in
                    if lhs.id == PurchaseConfiguration.allToursProductID { return true }
                    if rhs.id == PurchaseConfiguration.allToursProductID { return false }
                    return lhs.price < rhs.price
                }
        } catch {
            errorMessage = "Prices couldn't be loaded. Your free tour is still available."
        }
    }

    private func purchase(_ product: Product) async {
        purchasingProductID = product.id
        errorMessage = nil
        defer { purchasingProductID = nil }

        do {
            switch try await product.purchase() {
            case .success(let verificationResult):
                let transaction = try verified(verificationResult)
                purchasedProductIDs.insert(transaction.productID)
                cacheEntitlements()
                await transaction.finish()
            case .pending, .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            errorMessage = "The purchase couldn't be completed. You haven't been charged."
        }
    }

    private func refreshEntitlements() async {
        var verifiedProductIDs = Set<String>()
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard transaction.revocationDate == nil else { continue }
            verifiedProductIDs.insert(transaction.productID)
        }
        purchasedProductIDs = verifiedProductIDs
        cacheEntitlements()
    }

    private func observeTransactionUpdates() -> Task<Void, Never> {
        Task { [weak self] in
            for await result in Transaction.updates {
                guard !Task.isCancelled else { return }
                guard case .verified(let transaction) = result else { continue }
                await self?.refreshEntitlements()
                await transaction.finish()
            }
        }
    }

    private func cacheEntitlements() {
        defaults.set(Array(purchasedProductIDs).sorted(), forKey: cachedEntitlementsKey)
    }

    private func verified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value): return value
        case .unverified: throw PurchaseError.failedVerification
        }
    }
}

private enum PurchaseError: Error {
    case failedVerification
}
