import Foundation
import OSLog

struct WidgetTour: Codable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let minutes: Int
    let visitedCount: Int
    let stopCount: Int
    let nextStopTitle: String?
}

struct WidgetSnapshot: Codable, Equatable {
    let activeTour: WidgetTour?
    let savedTour: WidgetTour?
}

enum WidgetSnapshotStore {
    static let groupID = "group.com.storytrail.app"
    private static let key = "widget-snapshot-v1"
    private static let logger = Logger(subsystem: "com.storytrail.app", category: "Widgets")

    static func load(from defaults: UserDefaults? = UserDefaults(suiteName: groupID)) -> WidgetSnapshot? {
        guard let data = defaults?.data(forKey: key) else { return nil }
        do {
            return try JSONDecoder().decode(WidgetSnapshot.self, from: data)
        } catch {
            logger.error("Unable to decode the shared widget snapshot")
            return nil
        }
    }

    @discardableResult
    static func save(_ snapshot: WidgetSnapshot, to defaults: UserDefaults? = UserDefaults(suiteName: groupID))
        -> Bool
    {
        guard let defaults, load(from: defaults) != snapshot else { return false }
        do {
            defaults.set(try JSONEncoder().encode(snapshot), forKey: key)
            return true
        } catch {
            logger.error("Unable to encode the shared widget snapshot")
            return false
        }
    }
}

enum WidgetTourLink {
    static func url(for tourID: String) -> URL? {
        var components = URLComponents()
        components.scheme = "storytrail"
        components.host = "tour"
        components.path = "/\(tourID)"
        return components.url
    }

    static func tourID(from url: URL) -> String? {
        guard url.scheme == "storytrail", url.host == "tour" else { return nil }
        let parts = url.pathComponents.filter { $0 != "/" }
        guard parts.count == 1, !parts[0].isEmpty else { return nil }
        return parts[0]
    }
}
