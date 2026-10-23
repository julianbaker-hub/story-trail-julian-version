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

    func testBundledToursUseConfiguredTriggerRadii() async throws {
        let tours = try await BundledTourRepository().fetchTours()

        let innerHarbour = try XCTUnwrap(tours.first { $0.id == "inner-harbour" })
        let stop5 = try XCTUnwrap(innerHarbour.stops.first { $0.id == "inner-harbour-5" })

        XCTAssertEqual(stop5.coordinate.latitude, 48.420663, accuracy: 0.000_001)
        XCTAssertEqual(stop5.coordinate.longitude, -123.370137, accuracy: 0.000_001)
        XCTAssertEqual(stop5.triggerRadiusMeters, 15)

        let otherStops = tours.flatMap(\.stops).filter { $0.id != stop5.id }
        XCTAssertTrue(otherStops.allSatisfy { $0.triggerRadiusMeters == 20 })
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
            CLLocationCoordinate2D(latitude: 48.420234, longitude: -123.366827),
            CLLocationCoordinate2D(latitude: 48.420776, longitude: -123.368596),
        ]

        XCTAssertEqual(tour.routeCoordinates.count, 28)
        XCTAssertEqual(tour.routeArrows.count, 7)
        XCTAssertEqual(tour.stops.map(\.coordinate.latitude), expectedStopCoordinates.map(\.latitude))
        XCTAssertEqual(tour.stops.map(\.coordinate.longitude), expectedStopCoordinates.map(\.longitude))
        XCTAssertEqual(
            tour.stops.map(\.imageName),
            [
                "InnerHarbourStop01", "InnerHarbourStop02", "InnerHarbourStop03", "InnerHarbourStop04",
                "InnerHarbourStop05", "InnerHarbourStop06", "InnerHarbourStop07", "InnerHarbourStop08",
            ]
        )
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

        XCTAssertEqual(tour.routeCoordinates.count, 21)
        XCTAssertEqual(tour.routeArrows.count, 10)
        XCTAssertEqual(tour.stops.count, 11)
        XCTAssertEqual(
            tour.stops.map(\.imageName),
            [
                "OldTownStop01", "OldTownStop02", "OldTownStop03", nil, "OldTownStop05", "OldTownStop06",
                "OldTownStop07", "OldTownStop08", "OldTownStop09", "OldTownStop10", "OldTownStop11",
            ]
        )
        XCTAssertEqual(tour.stops.map(\.coordinate.latitude), expectedStopCoordinates.map(\.latitude))
        XCTAssertEqual(tour.stops.map(\.coordinate.longitude), expectedStopCoordinates.map(\.longitude))
        XCTAssertEqual(
            triggers.map(\.label),
            ["1", "2", "3", "4", "5", "6", "7", "7.5 navigation prompt", "8", "9", "9.5 continued", "10", "11", "12"])
        XCTAssertTrue(triggers.allSatisfy { $0.triggerRadiusMeters == 20 })
        XCTAssertEqual(
            triggers.compactMap(\.audioFile),
            [
                "old-town-01-introduction-old-victoria-hotel.mp3",
                "old-town-02-rogers-chocolates.mp3",
                "old-town-03-customs-house.mp3",
                "old-town-04-fort-victoria.mp3",
                "old-town-05-munros-murchies-morris.mp3",
                "old-town-06-bank-of-montreal.mp3",
                "old-town-07-bastion-square-black-pioneers.mp3",
                "old-town-07-5-navigation.mp3",
                "old-town-08-waddington-alley.mp3",
                "old-town-09-lower-johnson-street.mp3",
                "old-town-09-5-continued.mp3",
                "old-town-10-market-square.mp3",
                "old-town-11-fan-tan-alley.mp3",
                "old-town-12.mp3",
            ])
        XCTAssertEqual(tour.playbackStops.count, 14)
        for stop in tour.playbackStops {
            let file = try XCTUnwrap(stop.audioFile, "Missing audio for \(stop.id)")
            let name = (file as NSString).deletingPathExtension
            XCTAssertNotNil(Bundle.main.url(forResource: name, withExtension: "mp3"), "Unbundled audio: \(file)")
        }
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

    func testAutomaticPlaybackAcceptsOnlyTheNextExpectedStop() {
        let third = makeStop(number: 3, coordinate: origin)
        let fourth = makeStop(number: 4, coordinate: origin)
        let fifth = makeStop(number: 5, coordinate: origin)
        let tour = makeTour(stops: [third, fourth, fifth])

        XCTAssertTrue(TourPlaybackSequence.acceptsAutomaticArrival(fourth, in: tour, after: third))
        XCTAssertFalse(TourPlaybackSequence.acceptsAutomaticArrival(fifth, in: tour, after: third))
    }

    func testOldTownAutomaticSequenceIncludesHiddenAudioCues() async throws {
        let tours = try await BundledTourRepository().fetchTours()
        let tour = try XCTUnwrap(tours.first { $0.id == "old-town" })
        let playbackStops = tour.playbackStops
        let stop7 = try XCTUnwrap(playbackStops.first { $0.id == "old-town-7" })
        let stop75 = try XCTUnwrap(playbackStops.first { $0.id == "old-town-trigger-7-5" })
        let stop8 = try XCTUnwrap(playbackStops.first { $0.id == "old-town-8" })
        let stop9 = try XCTUnwrap(playbackStops.first { $0.id == "old-town-9" })
        let stop95 = try XCTUnwrap(playbackStops.first { $0.id == "old-town-trigger-9-5" })

        XCTAssertEqual(TourPlaybackSequence.nextExpectedStop(in: tour, after: stop7)?.id, stop75.id)
        XCTAssertEqual(TourPlaybackSequence.nextExpectedStop(in: tour, after: stop75)?.id, stop8.id)
        XCTAssertEqual(TourPlaybackSequence.nextExpectedStop(in: tour, after: stop9)?.id, stop95.id)
    }

    func testManualSelectionResetsTheExpectedAutomaticStop() {
        let third = makeStop(number: 3, coordinate: origin)
        let fourth = makeStop(number: 4, coordinate: origin)
        let fifth = makeStop(number: 5, coordinate: origin)
        let tour = makeTour(stops: [third, fourth, fifth])

        XCTAssertNil(TourPlaybackSequence.nextExpectedStop(in: tour, after: fifth))
        XCTAssertEqual(TourPlaybackSequence.nextExpectedStop(in: tour, after: fourth)?.id, fifth.id)
    }

    func testTourStartStateUsesFirstIncompleteStop() {
        let stops = (1...3).map { makeStop(number: $0, coordinate: origin) }
        let tour = makeTour(stops: stops)
        defer { TourProgress.clearVisitedStopIDs(for: tour.id) }

        TourProgress.clearVisitedStopIDs(for: tour.id)
        XCTAssertEqual(TourProgress.startState(for: tour), .notStarted)

        TourProgress.markVisited(stopID: stops[0].id, in: tour.id)
        XCTAssertEqual(
            TourProgress.startState(for: tour),
            .partiallyCompleted(firstIncompleteStopID: stops[1].id)
        )
    }

    func testTourStartStateRecognizesCompletionAndCanBeCleared() {
        let stops = (1...2).map { makeStop(number: $0, coordinate: origin) }
        let tour = makeTour(stops: stops)
        defer { TourProgress.clearVisitedStopIDs(for: tour.id) }

        for stop in stops {
            TourProgress.markVisited(stopID: stop.id, in: tour.id)
        }
        XCTAssertEqual(TourProgress.startState(for: tour), .completed)

        TourProgress.clearVisitedStopIDs(for: tour.id)
        XCTAssertEqual(TourProgress.startState(for: tour), .notStarted)
    }

    func testTourStartLocationGateRequiresPermissionAndAccurateLocation() {
        let stop = makeStop(number: 1, coordinate: origin)

        XCTAssertEqual(
            TourStartLocationGate.state(authorization: .denied, location: nil, stop: stop),
            .denied
        )
        XCTAssertEqual(
            TourStartLocationGate.state(authorization: .authorizedWhenInUse, location: nil, stop: stop),
            .locating
        )

        let inaccurateLocation = CLLocation(
            coordinate: origin,
            altitude: 0,
            horizontalAccuracy: TourStartLocationGate.maximumAccuracy + 1,
            verticalAccuracy: 1,
            timestamp: Date()
        )
        XCTAssertEqual(
            TourStartLocationGate.state(
                authorization: .authorizedWhenInUse,
                location: inaccurateLocation,
                stop: stop
            ),
            .inaccurate
        )
    }

    func testTourStartLocationGateUsesTwentyFiveMetreThreshold() {
        let stop = makeStop(number: 1, coordinate: origin)
        let nearby = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: origin.latitude + 0.000_1, longitude: origin.longitude),
            altitude: 0,
            horizontalAccuracy: 5,
            verticalAccuracy: 5,
            timestamp: Date()
        )
        let fartherAway = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: origin.latitude + 0.000_4, longitude: origin.longitude),
            altitude: 0,
            horizontalAccuracy: 5,
            verticalAccuracy: 5,
            timestamp: Date()
        )

        XCTAssertEqual(
            TourStartLocationGate.state(authorization: .authorizedWhenInUse, location: nearby, stop: stop),
            .arrived
        )
        guard
            case .outside(let distance) = TourStartLocationGate.state(
                authorization: .authorizedWhenInUse,
                location: fartherAway,
                stop: stop
            )
        else {
            return XCTFail("A location beyond 25 metres should remain outside the tour start.")
        }
        XCTAssertGreaterThan(distance, TourStartLocationGate.radius)
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
