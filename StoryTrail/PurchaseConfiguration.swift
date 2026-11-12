import Foundation

enum TourAvailability {
    static let launchTourIDs: Set<String> = ["inner-harbour", "old-town"]

    static func isLaunchTour(_ tourID: String) -> Bool {
        launchTourIDs.contains(tourID)
    }

    static func launchTours(from tours: [Tour]) -> [Tour] {
        tours.filter { isLaunchTour($0.id) }
    }
}

enum PurchaseConfiguration {
    static let allToursProductID = "com.storytrailguide.app.alltours"

    static let tourProductIDs: [String: String] = [
        "inner-harbour": "com.storytrailguide.app.innerharbour",
        "old-town": "com.storytrailguide.app.oldtown",
        "james-bay": "com.storytrailguide.app.tour.jamesbay",
        "beacon-hill": "com.storytrailguide.app.tour.beaconhill",
    ]

    static let fallbackCanadianPrices: [String: String] = [
        "inner-harbour": "$9.99",
        "old-town": "$12.99",
        "james-bay": "$12.99",
        "beacon-hill": "$9.99",
    ]

    static var productIDs: Set<String> {
        Set(tourProductIDs.values)
    }

    static var launchProductIDs: Set<String> {
        Set(launchTourIDs.compactMap { tourProductIDs[$0] })
    }

    static var recognizedEntitlementProductIDs: Set<String> {
        productIDs.union([allToursProductID])
    }

    static func productID(for tourID: String) -> String? {
        tourProductIDs[tourID]
    }

    static func fallbackCanadianPrice(for tourID: String) -> String? {
        fallbackCanadianPrices[tourID]
    }

    private static var launchTourIDs: Set<String> {
        TourAvailability.launchTourIDs
    }
}

struct TourAccessPolicy {
    let availableTourIDs: Set<String>
    let allToursProductID: String
    let tourProductIDs: [String: String]

    init(
        availableTourIDs: Set<String> = TourAvailability.launchTourIDs,
        allToursProductID: String = PurchaseConfiguration.allToursProductID,
        tourProductIDs: [String: String] = PurchaseConfiguration.tourProductIDs,
    ) {
        self.availableTourIDs = availableTourIDs
        self.allToursProductID = allToursProductID
        self.tourProductIDs = tourProductIDs
    }

    func hasAccess(to tourID: String, purchasedProductIDs: Set<String>) -> Bool {
        guard availableTourIDs.contains(tourID) else {
            return false
        }

        if purchasedProductIDs.contains(allToursProductID) {
            return true
        }

        guard let productID = tourProductIDs[tourID] else {
            return false
        }
        return purchasedProductIDs.contains(productID)
    }
}
