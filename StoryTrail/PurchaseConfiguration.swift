import Foundation

enum PurchaseConfiguration {
    static let demoTourID = "inner-harbour"
    static let allToursProductID = "com.storytrailguide.app.alltours"

    static let tourProductIDs: [String: String] = [
        "old-town": "com.storytrailguide.app.tour.oldtown",
        "james-bay": "com.storytrailguide.app.tour.jamesbay",
        "beacon-hill": "com.storytrailguide.app.tour.beaconhill",
    ]

    static var productIDs: Set<String> {
        Set(tourProductIDs.values).union([allToursProductID])
    }

    static func productID(for tourID: String) -> String? {
        tourProductIDs[tourID]
    }
}

struct TourAccessPolicy {
    let demoTourID: String
    let allToursProductID: String
    let tourProductIDs: [String: String]

    init(
        demoTourID: String = PurchaseConfiguration.demoTourID,
        allToursProductID: String = PurchaseConfiguration.allToursProductID,
        tourProductIDs: [String: String] = PurchaseConfiguration.tourProductIDs,
    ) {
        self.demoTourID = demoTourID
        self.allToursProductID = allToursProductID
        self.tourProductIDs = tourProductIDs
    }

    func hasAccess(to tourID: String, purchasedProductIDs: Set<String>) -> Bool {
        if tourID == demoTourID || purchasedProductIDs.contains(allToursProductID) {
            return true
        }

        guard let productID = tourProductIDs[tourID] else {
            return false
        }
        return purchasedProductIDs.contains(productID)
    }
}
