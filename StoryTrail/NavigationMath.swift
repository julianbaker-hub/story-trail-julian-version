import CoreLocation
import Foundation

enum TourNavigation {
    static func destination(stops: [TourStop], activeStop: TourStop, arrivedStopIDs: Set<String>) -> TourStop? {
        guard arrivedStopIDs.contains(activeStop.id) else { return activeStop }
        guard let index = stops.firstIndex(of: activeStop), index + 1 < stops.count else { return nil }
        return stops[index + 1]
    }
}

enum NavigationMath {
    static func bearing(from source: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D)
        -> CLLocationDirection
    {
        let lat1 = source.latitude * .pi / 180
        let lat2 = destination.latitude * .pi / 180
        let deltaLongitude = (destination.longitude - source.longitude) * .pi / 180
        let y = sin(deltaLongitude) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(deltaLongitude)
        return normalizedDegrees(atan2(y, x) * 180 / .pi)
    }

    static func normalizedDegrees(_ degrees: CLLocationDirection) -> CLLocationDirection {
        let result = degrees.truncatingRemainder(dividingBy: 360)
        return result >= 0 ? result : result + 360
    }

    static func cardinalDirection(for bearing: CLLocationDirection) -> String {
        let points = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        let index = Int((normalizedDegrees(bearing) + 22.5) / 45).quotientAndRemainder(dividingBy: 8).remainder
        return points[index]
    }

    static func distanceText(_ metres: CLLocationDistance) -> String {
        if metres < 1_000 { return "\(Int(metres.rounded())) m" }
        return String(format: "%.1f km", metres / 1_000)
    }
}
