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
    static let cachedEntitlementsKey = "verified-purchase-product-ids"
    private var transactionUpdatesTask: Task<Void, Never>?

    init(
        accessPolicy: TourAccessPolicy = TourAccessPolicy(),
        defaults: UserDefaults = .standard,
        startsStoreTasks: Bool = true,
    ) {
        self.accessPolicy = accessPolicy
        self.defaults = defaults
        purchasedProductIDs = Set(defaults.stringArray(forKey: Self.cachedEntitlementsKey) ?? [])

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
        guard TourAvailability.isLaunchTour(tour.id) else { return nil }
        guard let productID = PurchaseConfiguration.productID(for: tour.id) else { return nil }
        return products.first { $0.id == productID }
    }

    func accessLabel(for tour: Tour) -> String {
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

    func restorePurchases() async {
        isLoading = true
        errorMessage = nil
        do {
            try await AppStore.sync()
            await refreshEntitlements(replacingCachedEntitlements: true)
        } catch {
            errorMessage = "We couldn't restore purchases. Check your connection and try again."
        }
        isLoading = false
    }

    func clearError() {
        errorMessage = nil
    }

    func processOfferCodeRedemption(
        _ result: Result<VerificationResult<Transaction>, Error>
    ) async {
        switch result {
        case .success(let verificationResult):
            do {
                let transaction = try verified(verificationResult)
                try await processVerified(transaction)
                await refreshEntitlements()
            } catch {
                errorMessage = "The promo code couldn't be verified. Your access has not changed."
            }
        case .failure(let error):
            guard !isCancellation(error) else { return }
            errorMessage = "The promo code couldn't be redeemed. Please check the code and try again."
        }
    }

    private func prepareStore() async {
        isLoading = true
        async let loadedProducts: Void = loadProducts()
        async let processedTransactions: Void = processUnfinishedTransactions()
        async let loadedEntitlements: Void = refreshEntitlements()
        _ = await (loadedProducts, processedTransactions, loadedEntitlements)
        isLoading = false
    }

    private func loadProducts() async {
        do {
            products = try await Product.products(for: PurchaseConfiguration.launchProductIDs)
                .sorted { $0.price < $1.price }
        } catch {
            errorMessage = "Prices couldn't be loaded. Free previews and unlocked tours are still available."
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
                try await processVerified(transaction)
            case .pending, .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            errorMessage = "The purchase couldn't be completed. You haven't been charged."
        }
    }

    private func refreshEntitlements(replacingCachedEntitlements: Bool = false) async {
        var verifiedProductIDs = Set<String>()
        var revokedProductIDs = Set<String>()
        var verificationFailed = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else {
                verificationFailed = true
                continue
            }
            guard PurchaseConfiguration.recognizedEntitlementProductIDs.contains(transaction.productID) else {
                continue
            }
            if transaction.revocationDate == nil {
                verifiedProductIDs.insert(transaction.productID)
            } else {
                revokedProductIDs.insert(transaction.productID)
            }
        }
        reconcileEntitlements(
            activeProductIDs: verifiedProductIDs,
            revokedProductIDs: revokedProductIDs,
            replacingCachedEntitlements: replacingCachedEntitlements && !verificationFailed
        )
    }

    private func processUnfinishedTransactions() async {
        for await result in Transaction.unfinished {
            guard case .verified(let transaction) = result else { continue }
            do {
                try await processVerified(transaction)
            } catch {
                errorMessage = "A previous purchase couldn't be verified. Please restore purchases and try again."
            }
        }
    }

    private func processVerified(_ transaction: Transaction) async throws {
        guard PurchaseConfiguration.recognizedEntitlementProductIDs.contains(transaction.productID) else {
            throw PurchaseError.unrecognizedProduct
        }
        if transaction.revocationDate == nil {
            purchasedProductIDs.insert(transaction.productID)
        } else {
            purchasedProductIDs.remove(transaction.productID)
        }
        cacheEntitlements()
        await transaction.finish()
    }

    private func observeTransactionUpdates() -> Task<Void, Never> {
        Task { [weak self] in
            for await result in Transaction.updates {
                guard !Task.isCancelled else { return }
                guard case .verified(let transaction) = result else { continue }
                do {
                    try await self?.processVerified(transaction)
                    await self?.refreshEntitlements()
                } catch {
                    self?.setTransactionError()
                }
            }
        }
    }

    func reconcileEntitlements(
        activeProductIDs: Set<String>,
        revokedProductIDs: Set<String>,
        replacingCachedEntitlements: Bool
    ) {
        if replacingCachedEntitlements {
            purchasedProductIDs = activeProductIDs
        } else {
            purchasedProductIDs.formUnion(activeProductIDs)
            purchasedProductIDs.subtract(revokedProductIDs)
        }
        cacheEntitlements()
    }

    private func setTransactionError() {
        errorMessage = "A StoreKit transaction couldn't be verified. Your access has not changed."
    }

    private func cacheEntitlements() {
        defaults.set(Array(purchasedProductIDs).sorted(), forKey: Self.cachedEntitlementsKey)
    }

    private func verified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value): return value
        case .unverified: throw PurchaseError.failedVerification
        }
    }

    private func isCancellation(_ error: Error) -> Bool {
        (error as? SKError)?.code == .paymentCancelled
    }
}

private enum PurchaseError: Error {
    case failedVerification
    case unrecognizedProduct
}
