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

    func testProximityTriggersOnlyAfterCrossingTwentyMetres() {
        var engine = ProximityEngine()
        let stop = makeStop(number: 1, coordinate: origin)

        XCTAssertNil(engine.update(location: location(northMetres: 21), stops: [stop]))
        let event = engine.update(location: location(northMetres: 19), stops: [stop])

        XCTAssertEqual(event?.stop.id, stop.id)
        XCTAssertEqual(event?.sequence, 1)
        XCTAssertLessThanOrEqual(event?.distance ?? 100, 20)
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

    func testBundledToursUseTwentyMetreTriggerRadius() async throws {
        let tours = try await BundledTourRepository().fetchTours()

        XCTAssertTrue(tours.flatMap(\.stops).allSatisfy { $0.triggerRadiusMeters == 20 })
    }

    func testInnerHarbourUsesDetailedRouteAndUpdatedStops() async throws {
        let tours = try await BundledTourRepository().fetchTours()
        let tour = try XCTUnwrap(tours.first { $0.id == "inner-harbour" })
        let mapPin = try XCTUnwrap(tour.mapPin)
        XCTAssertEqual(mapPin.latitude, 48.421464, accuracy: 0.000_001)
        XCTAssertEqual(mapPin.longitude, -123.368864, accuracy: 0.000_001)
        let expectedStopCoordinates = [
            CLLocationCoordinate2D(latitude: 48.422732, longitude: -123.368861),
            CLLocationCoordinate2D(latitude: 48.421744, longitude: -123.368806),
            CLLocationCoordinate2D(latitude: 48.420883, longitude: -123.369476),
            CLLocationCoordinate2D(latitude: 48.420939, longitude: -123.370996),
            CLLocationCoordinate2D(latitude: 48.420663, longitude: -123.370137),
            CLLocationCoordinate2D(latitude: 48.420529, longitude: -123.369870),
            CLLocationCoordinate2D(latitude: 48.420156, longitude: -123.366460),
            CLLocationCoordinate2D(latitude: 48.420776, longitude: -123.368596),
        ]

        XCTAssertEqual(tour.routeCoordinates.count, 27)
        XCTAssertEqual(tour.routeArrows.count, 7)
        XCTAssertEqual(tour.stops.map(\.coordinate.latitude), expectedStopCoordinates.map(\.latitude))
        XCTAssertEqual(tour.stops.map(\.coordinate.longitude), expectedStopCoordinates.map(\.longitude))
    }

    func testOldTownUsesDetailedRouteVisibleStopsAndPreparedAudioTriggers() async throws {
        let tours = try await BundledTourRepository().fetchTours()
        let tour = try XCTUnwrap(tours.first { $0.id == "old-town" })
        let triggers = try XCTUnwrap(tour.audioTriggers)
        let expectedStopCoordinates = [
            CLLocationCoordinate2D(latitude: 48.423056, longitude: -123.368299),
            CLLocationCoordinate2D(latitude: 48.423923, longitude: -123.368076),
            CLLocationCoordinate2D(latitude: 48.424189, longitude: -123.368158),
            CLLocationCoordinate2D(latitude: 48.424426, longitude: -123.368086),
            CLLocationCoordinate2D(latitude: 48.425194, longitude: -123.367915),
            CLLocationCoordinate2D(latitude: 48.425664, longitude: -123.367812),
            CLLocationCoordinate2D(latitude: 48.425679, longitude: -123.367870),
            CLLocationCoordinate2D(latitude: 48.426973, longitude: -123.369619),
            CLLocationCoordinate2D(latitude: 48.427658, longitude: -123.369444),
            CLLocationCoordinate2D(latitude: 48.427993, longitude: -123.368495),
            CLLocationCoordinate2D(latitude: 48.428602, longitude: -123.367902),
        ]

        XCTAssertEqual(tour.routeCoordinates.count, 20)
        XCTAssertEqual(tour.routeArrows.count, 10)
        XCTAssertEqual(tour.stops.count, 11)
        XCTAssertEqual(tour.stops.map(\.coordinate.latitude), expectedStopCoordinates.map(\.latitude))
        XCTAssertEqual(tour.stops.map(\.coordinate.longitude), expectedStopCoordinates.map(\.longitude))
        XCTAssertEqual(
            triggers.map(\.label),
            ["1", "2", "3", "4", "5", "6", "7", "7.5 navigation prompt", "8", "9", "9.5 continued", "10", "11", "12"])
        XCTAssertTrue(triggers.allSatisfy { $0.triggerRadiusMeters == 20 })
        XCTAssertTrue(triggers.allSatisfy { $0.audioFile == nil })
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

    func testOverlappingStopsEachProduceAnArrival() {
        var engine = ProximityEngine()
        let first = makeStop(number: 1, coordinate: origin)
        let secondCoordinate = CLLocationCoordinate2D(
            latitude: origin.latitude + 10 / 111_111, longitude: origin.longitude)
        let second = makeStop(number: 2, coordinate: secondCoordinate)
        let currentLocation = location(northMetres: 9)

        let firstEvent = engine.update(location: currentLocation, stops: [first, second])
        let secondEvent = engine.update(location: currentLocation, stops: [first, second])

        XCTAssertEqual(Set([firstEvent?.stop.id, secondEvent?.stop.id].compactMap { $0 }), [first.id, second.id])
    }

    func testPlaybackQueueKeepsEveryUniqueArrivalInOrder() {
        var queue = TourStopPlaybackQueue()
        let first = makeStop(number: 5, coordinate: origin)
        let second = makeStop(number: 6, coordinate: origin)
        let tour = makeTour(stops: [first, second])

        queue.enqueue(tour: tour, stop: first)
        queue.enqueue(tour: tour, stop: second)
        queue.enqueue(tour: tour, stop: second)

        XCTAssertEqual(queue.items.map(\.stop.id), [first.id, second.id])
        XCTAssertEqual(queue.popFirst()?.stop.id, first.id)
        XCTAssertEqual(queue.popFirst()?.stop.id, second.id)
        XCTAssertNil(queue.popFirst())
    }

    func testPlaybackStopsIncludeConfiguredHiddenAudioTriggers() {
        let visible = makeStop(number: 7, coordinate: origin)
        let hiddenCoordinate = CLLocationCoordinate2D(latitude: origin.latitude + 0.001, longitude: origin.longitude)
        let hiddenTrigger = TourAudioTrigger(
            id: "hidden-7-5",
            label: "7.5 navigation prompt",
            latitude: hiddenCoordinate.latitude,
            longitude: hiddenCoordinate.longitude,
            triggerRadiusMeters: 20,
            audioFile: "hidden-prompt.mp3"
        )
        let tour = makeTour(stops: [visible], audioTriggers: [hiddenTrigger])

        XCTAssertEqual(tour.playbackStops.count, 1)
        XCTAssertEqual(tour.playbackStops.first?.id, hiddenTrigger.id)
        XCTAssertEqual(tour.playbackStops.first?.audioFile, hiddenTrigger.audioFile)
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

    private func makeTour(stops: [TourStop], audioTriggers: [TourAudioTrigger]? = nil) -> Tour {
        Tour(
            id: "test-tour",
            title: "Test Tour",
            subtitle: "Subtitle",
            about: "About",
            minutes: 10,
            distance: 1,
            stops: stops,
            audioTriggers: audioTriggers,
            imageName: "Test",
            palette: .harbour
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
