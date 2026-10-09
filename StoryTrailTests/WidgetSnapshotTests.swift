import CoreLocation
import XCTest

@testable import StoryTrail

final class WidgetSnapshotTests: XCTestCase {
    func testWidgetProgressUsesOnlyStopsInTourAndFindsNextStop() {
        let stops = (1...3).map { number in
            TourStop(
                id: "stop-\(number)", number: number, title: "Stop \(number)", summary: "",
                transcript: "", coordinate: CLLocationCoordinate2D(latitude: 48.42, longitude: -123.36)
            )
        }
        let tour = Tour(
            id: "walk", title: "Walk", subtitle: "A walk", about: "", minutes: 30,
            distance: 1, stops: stops, imageURL: nil, palette: .harbour
        )

        let partial = WidgetSnapshotPublisher.makeWidgetTour(tour, visitedIDs: ["stop-1", "unknown"])
        XCTAssertEqual(partial.visitedCount, 1)
        XCTAssertEqual(partial.stopCount, 3)
        XCTAssertEqual(partial.nextStopTitle, "Stop 2")

        let complete = WidgetSnapshotPublisher.makeWidgetTour(
            tour, visitedIDs: ["stop-1", "stop-2", "stop-3"])
        XCTAssertEqual(complete.visitedCount, 3)
        XCTAssertNil(complete.nextStopTitle)
    }

    func testSharedSnapshotRoundTripAndChangeDetection() {
        let suite = "WidgetSnapshotTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            XCTFail("Unable to create isolated defaults suite")
            return
        }
        defer { defaults.removePersistentDomain(forName: suite) }

        let tour = WidgetTour(
            id: "walk", title: "Walk", subtitle: "A walk", minutes: 30,
            visitedCount: 1, stopCount: 3, nextStopTitle: "Stop 2")
        let snapshot = WidgetSnapshot(activeTour: tour, savedTour: nil)
        XCTAssertTrue(WidgetSnapshotStore.save(snapshot, to: defaults))
        XCTAssertEqual(WidgetSnapshotStore.load(from: defaults), snapshot)
        XCTAssertFalse(WidgetSnapshotStore.save(snapshot, to: defaults))
    }

    func testWidgetTourLinkRoundTripAndRejectsOtherRoutes() {
        let url = WidgetTourLink.url(for: "inner-harbour")
        XCTAssertEqual(url.flatMap(WidgetTourLink.tourID), "inner-harbour")
        XCTAssertNil(URL(string: "https://example.com/tour/inner-harbour").flatMap(WidgetTourLink.tourID))
        XCTAssertNil(URL(string: "storytrail://tour/a/b").flatMap(WidgetTourLink.tourID))
    }
}
