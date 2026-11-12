import XCTest

@testable import StoryTrail

final class TourAccessPolicyTests: XCTestCase {
    private let policy = TourAccessPolicy(
        availableTourIDs: ["inner-harbour", "old-town"],
        allToursProductID: "all",
        tourProductIDs: [
            "inner-harbour": "inner",
            "old-town": "old",
            "james-bay": "james",
            "beacon-hill": "beacon",
        ],
    )

    func testEveryLaunchTourIsLockedWithoutOwnership() {
        for tourID in ["inner-harbour", "old-town", "james-bay", "beacon-hill"] {
            XCTAssertFalse(policy.hasAccess(to: tourID, purchasedProductIDs: []))
        }
    }

    func testIndividualPurchaseUnlocksOnlyItsTour() {
        XCTAssertTrue(policy.hasAccess(to: "inner-harbour", purchasedProductIDs: ["inner"]))
        XCTAssertFalse(policy.hasAccess(to: "old-town", purchasedProductIDs: ["inner"]))
        XCTAssertFalse(policy.hasAccess(to: "james-bay", purchasedProductIDs: ["inner"]))
        XCTAssertFalse(policy.hasAccess(to: "beacon-hill", purchasedProductIDs: ["inner"]))
    }

    func testVerifiedPromotionUsesTheSameIndividualEntitlement() {
        XCTAssertTrue(policy.hasAccess(to: "old-town", purchasedProductIDs: ["old"]))
        XCTAssertFalse(policy.hasAccess(to: "inner-harbour", purchasedProductIDs: ["old"]))
        XCTAssertFalse(policy.hasAccess(to: "james-bay", purchasedProductIDs: ["old"]))
        XCTAssertFalse(policy.hasAccess(to: "beacon-hill", purchasedProductIDs: ["old"]))
    }

    func testHistoricalBundleUnlocksOnlyAvailableTours() {
        XCTAssertTrue(policy.hasAccess(to: "inner-harbour", purchasedProductIDs: ["all"]))
        XCTAssertTrue(policy.hasAccess(to: "old-town", purchasedProductIDs: ["all"]))
        XCTAssertFalse(policy.hasAccess(to: "james-bay", purchasedProductIDs: ["all"]))
        XCTAssertFalse(policy.hasAccess(to: "beacon-hill", purchasedProductIDs: ["all"]))
    }

    func testUnfinishedTourPurchasesDoNotExposeToursBeforeLaunch() {
        XCTAssertFalse(policy.hasAccess(to: "james-bay", purchasedProductIDs: ["james"]))
        XCTAssertFalse(policy.hasAccess(to: "beacon-hill", purchasedProductIDs: ["beacon"]))
    }

    func testUnknownTourIsLocked() {
        XCTAssertFalse(policy.hasAccess(to: "future-tour", purchasedProductIDs: []))
    }

    func testConfirmedAndPreservedProductIdentifiers() {
        XCTAssertEqual(
            PurchaseConfiguration.tourProductIDs,
            [
                "inner-harbour": "com.storytrailguide.app.innerharbour",
                "old-town": "com.storytrailguide.app.oldtown",
                "james-bay": "com.storytrailguide.app.tour.jamesbay",
                "beacon-hill": "com.storytrailguide.app.tour.beaconhill",
            ]
        )
        XCTAssertEqual(
            PurchaseConfiguration.launchProductIDs,
            [
                "com.storytrailguide.app.innerharbour",
                "com.storytrailguide.app.oldtown",
            ]
        )
    }

    func testLocalStoreKitConfigurationPreservesAllProductsAndFreeOffers() throws {
        let repositoryURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let configurationURL = repositoryURL.appendingPathComponent("StoreKit/StoryTrail.storekit")
        let data = try Data(contentsOf: configurationURL)
        let configuration = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        let products = try XCTUnwrap(configuration["products"] as? [[String: Any]])
        let expectedPrices = [
            "com.storytrailguide.app.innerharbour": "9.99",
            "com.storytrailguide.app.oldtown": "12.99",
            "com.storytrailguide.app.tour.jamesbay": "12.99",
            "com.storytrailguide.app.tour.beaconhill": "9.99",
        ]

        XCTAssertEqual(Set(products.compactMap { $0["productID"] as? String }), Set(expectedPrices.keys))

        for product in products {
            let productID = try XCTUnwrap(product["productID"] as? String)
            XCTAssertEqual(product["type"] as? String, "NonConsumable")
            XCTAssertEqual(product["displayPrice"] as? String, expectedPrices[productID])

            let offerCodes = try XCTUnwrap(product["offerCodes"] as? [[String: Any]])
            XCTAssertEqual(offerCodes.count, 1)
            XCTAssertEqual(offerCodes.first?["paymentMode"] as? String, "free")
        }
    }

    @MainActor
    func testCachedPurchaseRemainsAvailableDuringNonAuthoritativeRefresh() throws {
        let suiteName = "TourAccessPolicyTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(["inner"], forKey: PurchaseStore.cachedEntitlementsKey)
        let store = PurchaseStore(accessPolicy: policy, defaults: defaults, startsStoreTasks: false)

        store.reconcileEntitlements(
            activeProductIDs: [],
            revokedProductIDs: [],
            replacingCachedEntitlements: false
        )

        XCTAssertTrue(policy.hasAccess(to: "inner-harbour", purchasedProductIDs: store.purchasedProductIDs))
    }

    @MainActor
    func testRevokedPurchaseIsRemovedDuringReconciliation() throws {
        let suiteName = "TourAccessPolicyTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(["old"], forKey: PurchaseStore.cachedEntitlementsKey)
        let store = PurchaseStore(accessPolicy: policy, defaults: defaults, startsStoreTasks: false)

        store.reconcileEntitlements(
            activeProductIDs: [],
            revokedProductIDs: ["old"],
            replacingCachedEntitlements: false
        )

        XCTAssertFalse(policy.hasAccess(to: "old-town", purchasedProductIDs: store.purchasedProductIDs))
    }

    @MainActor
    func testAuthoritativeRestoreReplacesStaleCachedEntitlements() throws {
        let suiteName = "TourAccessPolicyTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(["old"], forKey: PurchaseStore.cachedEntitlementsKey)
        let store = PurchaseStore(accessPolicy: policy, defaults: defaults, startsStoreTasks: false)

        store.reconcileEntitlements(
            activeProductIDs: ["inner"],
            revokedProductIDs: [],
            replacingCachedEntitlements: true
        )

        XCTAssertTrue(policy.hasAccess(to: "inner-harbour", purchasedProductIDs: store.purchasedProductIDs))
        XCTAssertFalse(policy.hasAccess(to: "old-town", purchasedProductIDs: store.purchasedProductIDs))
    }
}
