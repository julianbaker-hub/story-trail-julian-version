import CoreLocation
import Foundation
import SwiftUI

struct TourStop: Identifiable, Hashable, Codable {
    let id: String
    let number: Int
    let title: String
    let summary: String
    let transcript: String
    let coordinate: CLLocationCoordinate2D
    let triggerRadiusMeters: CLLocationDistance
    let audioURL: URL?
    let audioFile: String?

    enum CodingKeys: String, CodingKey {
        case id, number, title, summary, transcript, latitude, longitude
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
        coordinate: CLLocationCoordinate2D,
        triggerRadiusMeters: CLLocationDistance = 30,
        audioURL: URL? = nil,
        audioFile: String? = nil,
    ) {
        self.id = id
        self.number = number
        self.title = title
        self.summary = summary
        self.transcript = transcript
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
        coordinate = CLLocationCoordinate2D(
            latitude: try values.decode(Double.self, forKey: .latitude),
            longitude: try values.decode(Double.self, forKey: .longitude),
        )
        let decodedRadius = try values.decodeIfPresent(CLLocationDistance.self, forKey: .triggerRadiusMeters) ?? 30
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
        try values.encode(coordinate.latitude, forKey: .latitude)
        try values.encode(coordinate.longitude, forKey: .longitude)
        try values.encode(triggerRadiusMeters, forKey: .triggerRadiusMeters)
        try values.encodeIfPresent(audioURL, forKey: .audioURL)
        try values.encodeIfPresent(audioFile, forKey: .audioFile)
    }

    static func == (lhs: TourStop, rhs: TourStop) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct Tour: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    let subtitle: String
    let about: String
    let minutes: Int
    let distance: Double
    let stops: [TourStop]
    let imageURL: URL?
    let palette: TourPalette

    enum CodingKeys: String, CodingKey {
        case id, title, subtitle, about, minutes, distance, stops, palette
        case imageURL = "image_url"
    }

    static func == (lhs: Tour, rhs: Tour) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
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

    private static func key(for tourID: String) -> String {
        "visited-stop-ids.\(tourID)"
    }
}
