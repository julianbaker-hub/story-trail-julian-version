import CoreLocation
import Foundation
import SwiftUI

struct TourStop: Identifiable, Hashable, Codable {
    let id: String
    let number: Int
    let title: String
    let summary: String
    let transcript: String
    let imageName: String?
    let coordinate: CLLocationCoordinate2D
    let triggerRadiusMeters: CLLocationDistance
    let audioURL: URL?
    let audioFile: String?

    enum CodingKeys: String, CodingKey {
        case id, number, title, summary, transcript, latitude, longitude
        case imageName = "image_name"
        case triggerRadiusMeters = "trigger_radius_meters"
        case audioURL = "audio_url"
        case audioFile = "audio_file"
    }

    init(
        id: String,
        number: Int,
        title: String,
        summary: String,
        transcript: String,
        imageName: String? = nil,
        coordinate: CLLocationCoordinate2D,
        triggerRadiusMeters: CLLocationDistance = 20,
        audioURL: URL? = nil,
        audioFile: String? = nil,
    ) {
        self.id = id
        self.number = number
        self.title = title
        self.summary = summary
        self.transcript = transcript
        self.imageName = imageName
        self.coordinate = coordinate
        self.triggerRadiusMeters = min(max(triggerRadiusMeters, 5), 100)
        self.audioURL = audioURL
        self.audioFile = audioFile
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(String.self, forKey: .id)
        number = try values.decode(Int.self, forKey: .number)
        title = try values.decode(String.self, forKey: .title)
        summary = try values.decode(String.self, forKey: .summary)
        transcript = try values.decode(String.self, forKey: .transcript)
        imageName = try values.decodeIfPresent(String.self, forKey: .imageName)
        coordinate = CLLocationCoordinate2D(
            latitude: try values.decode(Double.self, forKey: .latitude),
            longitude: try values.decode(Double.self, forKey: .longitude),
        )
        let decodedRadius = try values.decodeIfPresent(CLLocationDistance.self, forKey: .triggerRadiusMeters) ?? 20
        triggerRadiusMeters = min(max(decodedRadius, 5), 100)
        audioURL = try values.decodeIfPresent(URL.self, forKey: .audioURL)
        audioFile = try values.decodeIfPresent(String.self, forKey: .audioFile)
    }

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(id, forKey: .id)
        try values.encode(number, forKey: .number)
        try values.encode(title, forKey: .title)
        try values.encode(summary, forKey: .summary)
        try values.encode(transcript, forKey: .transcript)
        try values.encodeIfPresent(imageName, forKey: .imageName)
        try values.encode(coordinate.latitude, forKey: .latitude)
        try values.encode(coordinate.longitude, forKey: .longitude)
        try values.encode(triggerRadiusMeters, forKey: .triggerRadiusMeters)
        try values.encodeIfPresent(audioURL, forKey: .audioURL)
        try values.encodeIfPresent(audioFile, forKey: .audioFile)
    }

    static func == (lhs: TourStop, rhs: TourStop) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct TourRoutePoint: Hashable, Codable {
    let latitude: Double
    let longitude: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct TourAudioTrigger: Identifiable, Hashable, Codable {
    let id: String
    let label: String
    let latitude: Double
    let longitude: Double
    let triggerRadiusMeters: CLLocationDistance
    let audioFile: String?

    enum CodingKeys: String, CodingKey {
        case id, label, latitude, longitude
        case triggerRadiusMeters = "trigger_radius_meters"
        case audioFile = "audio_file"
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    init(
        id: String,
        label: String,
        latitude: Double,
        longitude: Double,
        triggerRadiusMeters: CLLocationDistance = 20,
        audioFile: String? = nil
    ) {
        self.id = id
        self.label = label
        self.latitude = latitude
        self.longitude = longitude
        self.triggerRadiusMeters = min(max(triggerRadiusMeters, 5), 100)
        self.audioFile = audioFile
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(String.self, forKey: .id)
        label = try values.decode(String.self, forKey: .label)
        latitude = try values.decode(Double.self, forKey: .latitude)
        longitude = try values.decode(Double.self, forKey: .longitude)
        let decodedRadius = try values.decodeIfPresent(CLLocationDistance.self, forKey: .triggerRadiusMeters) ?? 20
        triggerRadiusMeters = min(max(decodedRadius, 5), 100)
        audioFile = try values.decodeIfPresent(String.self, forKey: .audioFile)
    }
}

struct TourRouteArrow: Identifiable {
    let id: Int
    let coordinate: CLLocationCoordinate2D
    let bearing: CLLocationDirection
}

struct Tour: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    let subtitle: String
    let about: String
    let minutes: Int
    let distance: Double
    let stops: [TourStop]
    let route: [TourRoutePoint]?
    let audioTriggers: [TourAudioTrigger]?
    let mapPin: TourRoutePoint?
    let imageName: String
    let palette: TourPalette

    enum CodingKeys: String, CodingKey {
        case id, title, subtitle, about, minutes, distance, stops, route, palette
        case audioTriggers = "audio_triggers"
        case mapPin = "map_pin"
        case imageName = "image_name"
    }

    init(
        id: String,
        title: String,
        subtitle: String,
        about: String,
        minutes: Int,
        distance: Double,
        stops: [TourStop],
        route: [TourRoutePoint]? = nil,
        audioTriggers: [TourAudioTrigger]? = nil,
        mapPin: TourRoutePoint? = nil,
        imageName: String,
        palette: TourPalette,
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.about = about
        self.minutes = minutes
        self.distance = distance
        self.stops = stops
        self.route = route
        self.audioTriggers = audioTriggers
        self.mapPin = mapPin
        self.imageName = imageName
        self.palette = palette
    }

    var routeCoordinates: [CLLocationCoordinate2D] {
        guard let route, !route.isEmpty else { return stops.map(\.coordinate) }
        return route.map(\.coordinate)
    }

    var mapPinCoordinate: CLLocationCoordinate2D? {
        mapPin?.coordinate ?? stops.first?.coordinate
    }

    var playbackStops: [TourStop] {
        guard let audioTriggers, !audioTriggers.isEmpty else { return stops }

        return audioTriggers.compactMap { trigger in
            if let stop = stops.first(where: { $0.coordinate.distance(to: trigger.coordinate) < 2 }) {
                return TourStop(
                    id: stop.id,
                    number: stop.number,
                    title: stop.title,
                    summary: stop.summary,
                    transcript: stop.transcript,
                    imageName: stop.imageName,
                    coordinate: trigger.coordinate,
                    triggerRadiusMeters: trigger.triggerRadiusMeters,
                    audioURL: stop.audioURL,
                    audioFile: trigger.audioFile ?? stop.audioFile
                )
            }

            guard let audioFile = trigger.audioFile else { return nil }
            let numberText = trigger.label.prefix { $0.isNumber }
            return TourStop(
                id: trigger.id,
                number: Int(numberText) ?? 0,
                title: trigger.label,
                summary: "",
                transcript: "",
                coordinate: trigger.coordinate,
                triggerRadiusMeters: trigger.triggerRadiusMeters,
                audioFile: audioFile
            )
        }
    }

    var routeArrows: [TourRouteArrow] {
        let coordinates = routeCoordinates
        guard coordinates.count > 1, stops.count > 1 else { return [] }

        return zip(stops.indices, stops.indices.dropFirst()).compactMap { startStopIndex, endStopIndex in
            guard
                let startIndex = coordinates.firstIndex(where: { $0.isNear(stops[startStopIndex].coordinate) }),
                let endIndex = coordinates[startIndex...].firstIndex(where: {
                    $0.isNear(stops[endStopIndex].coordinate)
                }),
                startIndex < endIndex
            else { return nil }

            let segmentIndex = min((startIndex + endIndex) / 2, endIndex - 1)
            let start = coordinates[segmentIndex]
            let end = coordinates[segmentIndex + 1]
            return TourRouteArrow(
                id: startStopIndex,
                coordinate: CLLocationCoordinate2D(
                    latitude: (start.latitude + end.latitude) / 2,
                    longitude: (start.longitude + end.longitude) / 2,
                ),
                bearing: NavigationMath.bearing(from: start, to: end),
            )
        }
    }

    static func == (lhs: Tour, rhs: Tour) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

extension CLLocationCoordinate2D {
    fileprivate func distance(to other: CLLocationCoordinate2D) -> CLLocationDistance {
        CLLocation(latitude: latitude, longitude: longitude)
            .distance(from: CLLocation(latitude: other.latitude, longitude: other.longitude))
    }

    fileprivate func isNear(_ other: CLLocationCoordinate2D) -> Bool {
        abs(latitude - other.latitude) < 0.000_001 && abs(longitude - other.longitude) < 0.000_001
    }
}

enum TourPalette: String, Codable {
    case harbour, oldTown, jamesBay, beaconHill

    var colors: [Color] {
        switch self {
        case .harbour: return [Color(red: 0.86, green: 0.95, blue: 0.90), Color(red: 0.63, green: 0.82, blue: 0.69)]
        case .oldTown: return [Color(red: 1.0, green: 0.88, blue: 0.80), Color(red: 0.91, green: 0.61, blue: 0.43)]
        case .jamesBay: return [Color(red: 0.90, green: 0.95, blue: 0.98), Color(red: 0.54, green: 0.76, blue: 0.86)]
        case .beaconHill:
            return [Color(red: 0.92, green: 0.94, blue: 0.82), Color(red: 0.55, green: 0.72, blue: 0.45)]
        }
    }
}

enum TourProgress {
    static func visitedStopIDs(for tourID: String) -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: key(for: tourID)) ?? [])
    }

    static func markVisited(stopID: String, in tourID: String) {
        var visited = visitedStopIDs(for: tourID)
        visited.insert(stopID)
        UserDefaults.standard.set(Array(visited), forKey: key(for: tourID))
    }

    static func clearVisitedStopIDs(for tourID: String) {
        UserDefaults.standard.removeObject(forKey: key(for: tourID))
    }

    static func startState(for tour: Tour) -> TourStartState {
        let visited = visitedStopIDs(for: tour.id)
        let visitedTourStops = tour.stops.filter { visited.contains($0.id) }
        guard !visitedTourStops.isEmpty else { return .notStarted }
        guard let firstIncomplete = tour.stops.first(where: { !visited.contains($0.id) }) else {
            return .completed
        }
        return .partiallyCompleted(firstIncompleteStopID: firstIncomplete.id)
    }

    private static func key(for tourID: String) -> String {
        "visited-stop-ids.\(tourID)"
    }
}

enum TourStartState: Equatable {
    case notStarted
    case partiallyCompleted(firstIncompleteStopID: String)
    case completed
}
