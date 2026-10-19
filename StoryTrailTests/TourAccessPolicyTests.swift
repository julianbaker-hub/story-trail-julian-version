import XCTest

@testable import StoryTrail

final class TourAccessPolicyTests: XCTestCase {
    private let policy = TourAccessPolicy(
        allToursUnlockedForTesting: false,
        demoTourID: "demo",
        allToursProductID: "all",
        tourProductIDs: ["paid-one": "one", "paid-two": "two"],
    )

    func testTemporaryTestingAccessUnlocksEveryTour() {
        let testingPolicy = TourAccessPolicy(
            allToursUnlockedForTesting: true,
            demoTourID: "demo",
            allToursProductID: "all",
            tourProductIDs: [:]
        )

        XCTAssertTrue(testingPolicy.hasAccess(to: "future-tour", purchasedProductIDs: []))
    }

    func testDemoTourIsAlwaysAvailable() {
        XCTAssertTrue(policy.hasAccess(to: "demo", purchasedProductIDs: []))
    }

    func testIndividualPurchaseUnlocksOnlyItsTour() {
        XCTAssertTrue(policy.hasAccess(to: "paid-one", purchasedProductIDs: ["one"]))
        XCTAssertFalse(policy.hasAccess(to: "paid-two", purchasedProductIDs: ["one"]))
    }

    func testBundleUnlocksEveryKnownTour() {
        XCTAssertTrue(policy.hasAccess(to: "paid-one", purchasedProductIDs: ["all"]))
        XCTAssertTrue(policy.hasAccess(to: "paid-two", purchasedProductIDs: ["all"]))
    }

    func testUnknownTourIsLocked() {
        XCTAssertFalse(policy.hasAccess(to: "future-tour", purchasedProductIDs: []))
    }
}
