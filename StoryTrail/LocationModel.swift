@preconcurrency import CoreLocation
import MapKit
import Network
import OSLog

enum ConnectivityStatus: Equatable {
    case checking
    case online
    case offline
}

@MainActor
final class ConnectivityModel: ObservableObject {
    @Published private(set) var status: ConnectivityStatus = .checking

    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "com.storytrailguide.connectivity")

    init(monitor: NWPathMonitor = NWPathMonitor()) {
        self.monitor = monitor
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                self?.status = path.status == .satisfied ? .online : .offline
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }

    var isOffline: Bool { status == .offline }
}

struct ProximityEvent: Equatable {
    let sequence: Int
    let stop: TourStop
    let distance: CLLocationDistance
}

struct ProximityEngine {
    let enterRadius: CLLocationDistance
    let exitRadius: CLLocationDistance
    let maximumAccuracy: CLLocationAccuracy

    private(set) var insideStopIDs: Set<String> = []
    private var sequence = 0

    init(
        enterRadius: CLLocationDistance = 20, exitRadius: CLLocationDistance = 35,
        maximumAccuracy: CLLocationAccuracy = 65,
    ) {
        precondition(exitRadius > enterRadius)
        self.enterRadius = enterRadius
        self.exitRadius = exitRadius
        self.maximumAccuracy = maximumAccuracy
    }

    mutating func update(location: CLLocation, stops: [TourStop]) -> ProximityEvent? {
        guard location.horizontalAccuracy >= 0, location.horizontalAccuracy <= maximumAccuracy else { return nil }

        let measured = stops.map { stop in
            (
                stop,
                location.distance(
                    from: CLLocation(latitude: stop.coordinate.latitude, longitude: stop.coordinate.longitude)),
            )
        }

        for (stop, distance) in measured where distance > max(exitRadius, stop.triggerRadiusMeters + 15) {
            insideStopIDs.remove(stop.id)
        }

        let entered =
            measured
            .filter { stop, distance in
                distance <= max(1, stop.triggerRadiusMeters) && !insideStopIDs.contains(stop.id)
            }
            .sorted { $0.1 < $1.1 }

        guard let nearest = entered.first else { return nil }
        // Treat overlapping trigger circles as one arrival so GPS jitter cannot
        // rapidly start several tracks at the same physical location.
        for (stop, _) in entered {
            insideStopIDs.insert(stop.id)
        }
        sequence += 1
        return ProximityEvent(sequence: sequence, stop: nearest.0, distance: nearest.1)
    }
}

@MainActor
final class LocationModel: NSObject, ObservableObject, @preconcurrency CLLocationManagerDelegate {
    @Published private(set) var location: CLLocation?
    @Published private(set) var authorization: CLAuthorizationStatus = .notDetermined
    @Published private(set) var proximityEvent: ProximityEvent?
    @Published private(set) var headingDegrees: CLLocationDirection?
    @Published private(set) var headingAccuracy: CLLocationDirection = -1
    @Published private(set) var lastError: String?

    private let manager = CLLocationManager()
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "StoryTrail", category: "Location")
    private var stops: [TourStop] = []
    private var proximity = ProximityEngine()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.distanceFilter = 3
        manager.activityType = .fitness
        manager.pausesLocationUpdatesAutomatically = false
        manager.allowsBackgroundLocationUpdates = true
        manager.showsBackgroundLocationIndicator = true
        authorization = manager.authorizationStatus
    }

    func begin(for stops: [TourStop]) {
        self.stops = stops
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        } else if isAuthorized {
            startSensors()
        }
    }

    func stop() {
        manager.stopUpdatingLocation()
        manager.stopUpdatingHeading()
    }

    func requestLocation() {
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        } else if isAuthorized {
            manager.requestLocation()
        }
    }

    func distance(to stop: TourStop) -> CLLocationDistance? {
        location?.distance(from: CLLocation(latitude: stop.coordinate.latitude, longitude: stop.coordinate.longitude))
    }

    func bearing(to stop: TourStop) -> CLLocationDirection? {
        guard let coordinate = location?.coordinate else { return nil }
        return NavigationMath.bearing(from: coordinate, to: stop.coordinate)
    }

    func relativeBearing(to stop: TourStop) -> CLLocationDirection? {
        guard let bearing = bearing(to: stop), let headingDegrees else { return nil }
        return NavigationMath.normalizedDegrees(bearing - headingDegrees)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorization = manager.authorizationStatus
        if isAuthorized { startSensors() } else if authorization == .denied || authorization == .restricted { stop() }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        location = latest
        if let nearestDistance = stops.map({
            latest.distance(from: CLLocation(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude))
        }).min() {
            logger.debug(
                "Location update: accuracy=\(latest.horizontalAccuracy, format: .fixed(precision: 1))m nearestStop=\(nearestDistance, format: .fixed(precision: 1))m"
            )
        }
        if let event = proximity.update(location: latest, stops: stops) {
            proximityEvent = event
            logger.notice(
                "Entered trigger radius for \(event.stop.id, privacy: .public) at \(event.distance, format: .fixed(precision: 1))m"
            )
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        guard newHeading.headingAccuracy >= 0 else { return }
        headingAccuracy = newHeading.headingAccuracy
        headingDegrees = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
    }

    func locationManagerShouldDisplayHeadingCalibration(_ manager: CLLocationManager) -> Bool {
        headingAccuracy < 0 || headingAccuracy > 25
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard (error as? CLError)?.code != .locationUnknown else { return }
        lastError = error.localizedDescription
        logger.error("Location failed: \(error.localizedDescription, privacy: .public)")
    }

    private var isAuthorized: Bool {
        authorization == .authorizedWhenInUse || authorization == .authorizedAlways
    }

    private func startSensors() {
        manager.startUpdatingLocation()
        if CLLocationManager.headingAvailable() {
            manager.headingFilter = 1
            manager.headingOrientation = .portrait
            manager.startUpdatingHeading()
        }
    }
}
