import CoreLocation
import XCTest

@testable import StoryTrail

final class NavigationAndProximityTests: XCTestCase {
    private let origin = CLLocationCoordinate2D(latitude: 48.42272, longitude: -123.36902)

    func testDirectionsTargetCurrentStopUntilArrival() {
        let first = makeStop(number: 1, coordinate: origin)
        let second = makeStop(number: 2, coordinate: origin)
        let stops = [first, second]
        XCTAssertEqual(TourNavigation.destination(stops: stops, activeStop: first, arrivedStopIDs: []), first)
        XCTAssertEqual(
            TourNavigation.destination(stops: stops, activeStop: first, arrivedStopIDs: [first.id]), second)
        XCTAssertEqual(
            TourNavigation.destination(stops: stops, activeStop: second, arrivedStopIDs: [first.id]), second)
        XCTAssertNil(
            TourNavigation.destination(stops: stops, activeStop: second, arrivedStopIDs: [first.id, second.id]))
    }

    func testProximityTriggersOnlyAfterCrossingThirtyMetres() {
        var engine = ProximityEngine()
        let stop = makeStop(number: 1, coordinate: origin)

        XCTAssertNil(engine.update(location: location(northMetres: 31), stops: [stop]))
        let event = engine.update(location: location(northMetres: 29), stops: [stop])

        XCTAssertEqual(event?.stop.id, stop.id)
        XCTAssertEqual(event?.sequence, 1)
        XCTAssertLessThanOrEqual(event?.distance ?? 100, 30)
    }

    func testProximityUsesHysteresisToPreventGPSBounce() {
        var engine = ProximityEngine()
        let stop = makeStop(number: 1, coordinate: origin)

        XCTAssertNotNil(engine.update(location: location(northMetres: 10), stops: [stop]))
        XCTAssertNil(engine.update(location: location(northMetres: 32), stops: [stop]))
        XCTAssertNil(engine.update(location: location(northMetres: 12), stops: [stop]))
        XCTAssertNil(engine.update(location: location(northMetres: 50), stops: [stop]))
        XCTAssertEqual(engine.update(location: location(northMetres: 15), stops: [stop])?.sequence, 2)
    }

    func testProximityRejectsInaccurateLocations() {
        var engine = ProximityEngine()
        let stop = makeStop(number: 1, coordinate: origin)
        let inaccurate = CLLocation(
            coordinate: origin,
            altitude: 0,
            horizontalAccuracy: 100,
            verticalAccuracy: 5,
            timestamp: Date(),
        )

        XCTAssertNil(engine.update(location: inaccurate, stops: [stop]))
    }

    func testStopCanOverrideTriggerRadius() {
        var engine = ProximityEngine()
        let stop = TourStop(
            id: "wide-stop",
            number: 1,
            title: "Wide Stop",
            summary: "Summary",
            transcript: "Transcript",
            coordinate: origin,
            triggerRadiusMeters: 50,
        )

        XCTAssertNotNil(engine.update(location: location(northMetres: 49), stops: [stop]))
    }

    func testStopDecodesProductionAudioFields() throws {
        let data = Data(
            """
            {
              "id": "audio-stop",
              "number": 3,
              "title": "Audio Stop",
              "summary": "Summary",
              "transcript": "Transcript",
              "latitude": 48.42,
              "longitude": -123.36,
              "trigger_radius_meters": 42,
              "audio_url": "https://example.com/story.mp3",
              "audio_file": "offline-story.mp3"
            }
            """.utf8)

        let stop = try JSONDecoder().decode(TourStop.self, from: data)

        XCTAssertEqual(stop.triggerRadiusMeters, 42)
        XCTAssertEqual(stop.audioURL?.absoluteString, "https://example.com/story.mp3")
        XCTAssertEqual(stop.audioFile, "offline-story.mp3")
    }

    func testInnerHarbourStopsHaveDistinctBundledAudio() async throws {
        let tours = try await BundledTourRepository().fetchTours()
        let tour = try XCTUnwrap(tours.first { $0.id == "inner-harbour" })
        XCTAssertEqual(tour.stops.count, 8)

        let files = try tour.stops.map { stop in
            let file = try XCTUnwrap(stop.audioFile, "Missing audio for \(stop.id)")
            let name = (file as NSString).deletingPathExtension
            XCTAssertTrue(file.hasPrefix(String(format: "inner-harbour-%02d-", stop.number)))
            XCTAssertNotNil(Bundle.main.url(forResource: name, withExtension: "mp3"), "Unbundled audio: \(file)")
            return file
        }
        XCTAssertEqual(Set(files).count, tour.stops.count)
    }

    func testNearestStopWinsWhenTriggerAreasOverlap() {
        var engine = ProximityEngine()
        let first = makeStop(number: 1, coordinate: origin)
        let secondCoordinate = CLLocationCoordinate2D(
            latitude: origin.latitude + 10 / 111_111, longitude: origin.longitude)
        let second = makeStop(number: 2, coordinate: secondCoordinate)

        let event = engine.update(location: location(northMetres: 9), stops: [first, second])

        XCTAssertEqual(event?.stop.id, second.id)
    }

    func testBearingAndCardinalDirections() {
        let north = CLLocationCoordinate2D(latitude: origin.latitude + 0.01, longitude: origin.longitude)
        let east = CLLocationCoordinate2D(latitude: origin.latitude, longitude: origin.longitude + 0.01)

        XCTAssertEqual(NavigationMath.bearing(from: origin, to: north), 0, accuracy: 0.1)
        XCTAssertEqual(NavigationMath.bearing(from: origin, to: east), 90, accuracy: 0.1)
        XCTAssertEqual(NavigationMath.cardinalDirection(for: 89), "E")
        XCTAssertEqual(NavigationMath.normalizedDegrees(-15), 345)
    }

    private func makeStop(number: Int, coordinate: CLLocationCoordinate2D) -> TourStop {
        TourStop(
            id: "stop-\(number)",
            number: number,
            title: "Stop \(number)",
            summary: "Summary",
            transcript: "Transcript",
            coordinate: coordinate,
        )
    }

    private func location(northMetres: Double) -> CLLocation {
        CLLocation(
            coordinate: CLLocationCoordinate2D(
                latitude: origin.latitude + northMetres / 111_111,
                longitude: origin.longitude,
            ),
            altitude: 0,
            horizontalAccuracy: 5,
            verticalAccuracy: 5,
            timestamp: Date(),
        )
    }
}
