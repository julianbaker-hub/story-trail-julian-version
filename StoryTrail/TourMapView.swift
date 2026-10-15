import MapKit
import SwiftUI

struct TourMapView: View {
    let tour: Tour
    let startsPlayer: Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @EnvironmentObject private var player: AudioPlayerModel
    @EnvironmentObject private var library: TourLibrary
    @EnvironmentObject private var connectivity: ConnectivityModel
    @StateObject private var location = LocationModel()
    @State private var selectedStop: TourStop?
    @State private var position: MapCameraPosition
    @State private var directionTarget: TourStop?
    @State private var visitedStopIDs: Set<String> = []
    @State private var arrivedStopIDs: Set<String> = []
    @State private var arrivalMessage: String?
    @State private var showsPlayer = false
    @State private var playerDockHeight: CGFloat = 160
    @State private var opensDirectionsAfterPlayer = false
    @State private var stopSelectionHapticTrigger = 0

    init(tour: Tour, startsPlayer: Bool) {
        self.tour = tour
        self.startsPlayer = startsPlayer
        let points = tour.routeCoordinates
        _position = State(initialValue: .region(Self.region(for: points)))
        _visitedStopIDs = State(initialValue: TourProgress.visitedStopIDs(for: tour.id))
    }

    var body: some View {
        GeometryReader { geometry in
            mapContent
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    ScrollView {
                        MapPlayerDock(
                            tour: tour, stop: activeStop, nextStop: navigationStop,
                            onExpand: { showsPlayer = true }, onDirections: openDirections
                        )
                        .fixedSize(horizontal: false, vertical: true)
                        .background {
                            GeometryReader { dockGeometry in
                                Color.clear
                                    .onAppear { playerDockHeight = dockGeometry.size.height }
                                    .onChange(of: dockGeometry.size.height) { _, height in playerDockHeight = height }
                            }
                        }
                    }
                    .scrollBounceBehavior(.basedOnSize)
                    .frame(
                        height: min(
                            playerDockHeight, geometry.size.height * (typeSize.isAccessibilitySize ? 0.4 : 0.32))
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 8)
                }
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.visible, for: .tabBar)
        .sheet(isPresented: $showsPlayer, onDismiss: playerDidDismiss) {
            ScrollView {
                PlayerSheet(
                    tour: tour, stop: activeStop, nextStop: navigationStop,
                    onPrevious: previous, onNext: next,
                    onDirections: {
                        opensDirectionsAfterPlayer = true
                        showsPlayer = false
                    },
                )
            }
            .scrollBounceBehavior(.basedOnSize)
            .padding(.top, 20)
            .background(TrailColor.paper)
            .presentationDetents(typeSize.isAccessibilitySize ? [.large] : [.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(TrailShape.card)
        }
    }

    private var mapContent: some View {
        VStack(spacing: 0) {
            Map(position: $position, selection: selectedStopBinding) {
                MapPolyline(coordinates: tour.routeCoordinates)
                    .stroke(TrailColor.green, style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: [4, 9]))
                ForEach(tour.routeArrows) { arrow in
                    Annotation("Route direction", coordinate: arrow.coordinate, anchor: .center) {
                        Image(systemName: "arrowtriangle.up.fill")
                            .font(.system(size: 14, weight: .black))
                            .foregroundStyle(TrailColor.green)
                            .rotationEffect(.degrees(arrow.bearing))
                            .accessibilityHidden(true)
                    }
                }
                ForEach(tour.stops) { stop in
                    Annotation(stop.title, coordinate: stop.coordinate, anchor: .center) {
                        StopMapPin(
                            number: stop.number, active: activeStop.id == stop.id,
                            visited: visitedStopIDs.contains(stop.id))
                    }
                    .tag(stop)
                }
                UserAnnotation()
            }
            .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
            .overlay(alignment: .top) {
                VStack(spacing: 10) {
                    HStack {
                        RoundIconButton(systemName: "chevron.left") { dismiss() }
                            .accessibilityLabel("Back to tour")
                            .accessibilityHint("Returns to tour details")
                        Spacer()
                        RoundIconButton(systemName: "location") { recenter() }
                            .accessibilityLabel("Recenter map")
                            .accessibilityHint(
                                "Centers on your location, or shows the route if location is unavailable")
                    }

                    if let arrivalMessage {
                        Label(arrivalMessage, systemImage: "checkmark.circle.fill")
                            .font(.trailBody(14, weight: .bold))
                            .foregroundStyle(TrailColor.ink)
                            .padding(.horizontal, 16).padding(.vertical, 10)
                            .background(TrailColor.action, in: Capsule())
                            .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                    } else if connectivity.isOffline {
                        Button(action: openDirections) {
                            Label("Offline — GPS and compass still work", systemImage: "wifi.slash")
                                .font(.trailBody(13, weight: .bold))
                                .foregroundStyle(TrailColor.cream)
                                .padding(.horizontal, 14).padding(.vertical, 10)
                                .background(TrailColor.yellow, in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Opens compass directions to the next stop")
                    } else if location.authorization == .denied || location.authorization == .restricted {
                        Label(
                            "Location is off — stops can still be selected manually", systemImage: "location.slash.fill"
                        )
                        .font(.trailBody(13, weight: .semibold))
                        .foregroundStyle(TrailColor.cream)
                        .padding(.horizontal, 14).padding(.vertical, 9)
                        .background(TrailColor.yellow, in: Capsule())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 8)
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: stopSelectionHapticTrigger)
        .onAppear {
            WidgetSnapshotPublisher.activate(tour, in: library.tours, savedIDs: library.savedTourIDs)
            location.begin(for: tour.stops)
            if startsPlayer || player.currentTour?.id != tour.id {
                player.load(tour: tour, stop: resumeStop, autoplay: false)
            }
        }
        .onChange(of: selectedStop) { _, stop in
            guard let stop else { return }
            guard player.currentTour?.id != tour.id || player.currentStop?.id != stop.id else { return }
            player.load(tour: tour, stop: stop, autoplay: false)
        }
        .onChange(of: location.proximityEvent) { _, event in
            guard let event else { return }
            let isCurrentStop = player.currentTour?.id == tour.id && player.currentStop?.id == event.stop.id
            let shouldAutoplay = startsPlayer || player.isPlaying
            selectedStop = event.stop
            visitedStopIDs.insert(event.stop.id)
            arrivedStopIDs.insert(event.stop.id)
            TourProgress.markVisited(stopID: event.stop.id, in: tour.id)
            WidgetSnapshotPublisher.publish(tours: library.tours, savedIDs: library.savedTourIDs)
            if !isCurrentStop {
                player.load(tour: tour, stop: event.stop, autoplay: shouldAutoplay)
            }
            withAnimation(reduceMotion ? nil : .default) {
                arrivalMessage =
                    shouldAutoplay
                    ? "Playing Stop \(event.stop.number)"
                    : "Arrived at Stop \(event.stop.number)"
            }
            UIAccessibility.post(
                notification: .announcement,
                argument: shouldAutoplay
                    ? "Arrived at stop \(event.stop.number), \(event.stop.title). Audio playing."
                    : "Arrived at stop \(event.stop.number), \(event.stop.title).",
            )
            Task {
                try? await Task.sleep(for: .seconds(3))
                withAnimation(reduceMotion ? nil : .default) { arrivalMessage = nil }
            }
        }
        .onDisappear { location.stop() }
        .fullScreenCover(item: $directionTarget) { target in
            DirectionView(tour: tour, target: target, location: location)
        }
    }

    private var activeStop: TourStop {
        if player.currentTour?.id == tour.id, let current = player.currentStop { return current }
        return selectedStop ?? tour.stops[0]
    }

    private var selectedStopBinding: Binding<TourStop?> {
        Binding(
            get: { selectedStop },
            set: { stop in
                selectedStop = stop
                if stop != nil {
                    stopSelectionHapticTrigger += 1
                }
            }
        )
    }

    private var navigationStop: TourStop? {
        TourNavigation.destination(stops: tour.stops, activeStop: activeStop, arrivedStopIDs: arrivedStopIDs)
    }

    private var resumeStop: TourStop {
        if let unvisitedStop = tour.stops.first(where: { !visitedStopIDs.contains($0.id) }) {
            return unvisitedStop
        }
        guard let lastStop = tour.stops.last else {
            preconditionFailure("A tour must contain at least one stop")
        }
        return lastStop
    }

    private func previous() {
        guard let index = tour.stops.firstIndex(of: activeStop), index > 0 else { return }
        choose(tour.stops[index - 1])
    }

    private func next() {
        guard let index = tour.stops.firstIndex(of: activeStop), index < tour.stops.count - 1 else { return }
        choose(tour.stops[index + 1])
    }

    private func choose(_ stop: TourStop) {
        selectedStop = stop
        player.load(tour: tour, stop: stop, autoplay: false)
        position = .region(
            MKCoordinateRegion(center: stop.coordinate, latitudinalMeters: 700, longitudinalMeters: 700))
    }

    private func openDirections() {
        directionTarget = navigationStop ?? activeStop
    }

    private func playerDidDismiss() {
        if opensDirectionsAfterPlayer {
            opensDirectionsAfterPlayer = false
            openDirections()
        }
    }

    private func recenter() {
        location.requestLocation()
        if let coordinate = location.location?.coordinate {
            position = .region(MKCoordinateRegion(center: coordinate, latitudinalMeters: 800, longitudinalMeters: 800))
        } else {
            position = .region(Self.region(for: tour.routeCoordinates))
        }
    }

    private static func region(for coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        guard let first = coordinates.first else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 48.422, longitude: -123.368), latitudinalMeters: 1800,
                longitudinalMeters: 1800)
        }
        let minLat = coordinates.map(\.latitude).min() ?? first.latitude
        let maxLat = coordinates.map(\.latitude).max() ?? first.latitude
        let minLon = coordinates.map(\.longitude).min() ?? first.longitude
        let maxLon = coordinates.map(\.longitude).max() ?? first.longitude
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2),
            span: MKCoordinateSpan(
                latitudeDelta: max(0.008, (maxLat - minLat) * 1.6),
                longitudeDelta: max(0.008, (maxLon - minLon) * 1.6)),
        )
    }
}

struct StopMapPin: View {
    let number: Int
    let active: Bool
    let visited: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        Group {
            if visited && !active { Image(systemName: "checkmark").fontWeight(.bold) } else { Text("\(number)") }
        }
        // Keep geographic markers compact; VoiceOver exposes their number and state.
        .font(.system(size: active ? 16 : 14, weight: .bold, design: .rounded))
        .foregroundStyle(active ? TrailColor.cream : TrailColor.ink)
        .frame(width: active ? 48 : 44, height: active ? 48 : 44)
        .background(active ? TrailColor.coral : TrailColor.action, in: Circle())
        .overlay(Circle().stroke(.white, lineWidth: 3))
        .shadow(color: .black.opacity(0.18), radius: 5, y: 2)
        .animation(reduceMotion ? nil : .spring(response: 0.3), value: active)
        .accessibilityLabel("Stop \(number)")
        .accessibilityValue(active ? "Selected" : visited ? "Visited" : "Not visited")
    }
}

struct MapPlayerDock: View {
    let tour: Tour
    let stop: TourStop
    let nextStop: TourStop?
    let onExpand: () -> Void
    let onDirections: () -> Void
    @EnvironmentObject private var player: AudioPlayerModel
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(spacing: 6) {
            HStack(alignment: .top, spacing: 12) {
                Button(action: onExpand) {
                    HStack(spacing: 10) {
                        if !typeSize.isAccessibilitySize {
                            Text("\(stop.number)")
                                .font(.trailBody(15, weight: .bold))
                                .frame(minWidth: 32, minHeight: 32)
                                .background(TrailColor.coral.opacity(0.18), in: Circle())
                                .accessibilityHidden(true)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            if !typeSize.isAccessibilitySize {
                                Text("\(tour.title) · Stop \(stop.number) of \(tour.stops.count)")
                                    .font(.trailBody(12, weight: .semibold))
                                    .foregroundStyle(TrailColor.muted)
                                    .lineLimit(1)
                            }
                            Text(stop.title)
                                .font(.trailBody(17, weight: .bold))
                                .lineLimit(typeSize.isAccessibilitySize ? nil : 2)
                                .multilineTextAlignment(.leading)
                            if typeSize.isAccessibilitySize {
                                Text("Stop \(stop.number) of \(tour.stops.count)")
                                    .font(.trailBody(12, weight: .semibold))
                                    .foregroundStyle(TrailColor.muted)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: "chevron.up")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(TrailColor.muted)
                    }
                    .foregroundStyle(TrailColor.ink)
                    .frame(minHeight: 48)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Stop \(stop.number) of \(tour.stops.count), \(stop.title)")
                .accessibilityValue(player.isPlaying ? "Playing" : "Paused")
                .accessibilityHint("Opens story details, playback controls, and the audio scrubber")

                StoryPlaybackButton(tour: tour, stop: stop, diameter: 48)
            }

            StoryAudioStatus(tour: tour, stop: stop)

            ProgressView(value: player.duration > 0 ? player.progress / player.duration : 0)
                .tint(TrailColor.green)
                .accessibilityHidden(true)

            HStack(spacing: 8) {
                if let nextStop {
                    Button(action: onDirections) {
                        Label(
                            nextStop.id == stop.id ? "Walk to stop \(nextStop.number)" : "Next stop \(nextStop.number)",
                            systemImage: "location.north"
                        )
                        .font(.trailBody(14, weight: .bold))
                        .foregroundStyle(TrailColor.green)
                        .frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Directions to stop \(nextStop.number), \(nextStop.title)")
                    .accessibilityHint("Opens GPS and compass directions, available offline")
                }
                Spacer(minLength: 0)
                if !typeSize.isAccessibilitySize {
                    Text("\(playbackTime(player.progress)) / \(playbackTime(player.duration))")
                        .font(.trailBody(12, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(TrailColor.muted)
                        .accessibilityLabel("\(playbackTime(player.progress)) of \(playbackTime(player.duration))")
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, 4)
        .background(TrailColor.paper, in: RoundedRectangle(cornerRadius: TrailShape.card))
        .overlay(RoundedRectangle(cornerRadius: TrailShape.card).stroke(TrailColor.line.opacity(0.55)))
        .shadow(color: .black.opacity(0.1), radius: 10, y: 3)
    }
}

struct StoryPlaybackButton: View {
    let tour: Tour
    let stop: TourStop
    let diameter: CGFloat
    @EnvironmentObject private var player: AudioPlayerModel
    @State private var playbackHapticTrigger = 0

    private var isCurrentStop: Bool { player.currentTour?.id == tour.id && player.currentStop?.id == stop.id }

    var body: some View {
        Button {
            playbackHapticTrigger += 1
            if !isCurrentStop {
                player.load(tour: tour, stop: stop, autoplay: true)
            } else {
                player.toggle()
            }
        } label: {
            Group {
                if isCurrentStop && player.isLoading {
                    ProgressView().tint(TrailColor.ink)
                } else {
                    Image(systemName: isCurrentStop && player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: diameter > 48 ? 25 : 19, weight: .bold))
                }
            }
            .foregroundStyle(TrailColor.ink)
            .frame(width: diameter, height: diameter)
            .background(TrailColor.coral, in: Circle())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .light), trigger: playbackHapticTrigger)
        .disabled(isCurrentStop && player.isLoading)
        .accessibilityLabel(
            isCurrentStop && player.isLoading
                ? "Loading story" : isCurrentStop && player.isPlaying ? "Pause story" : "Play story")
    }
}

struct StoryAudioStatus: View {
    let tour: Tour
    let stop: TourStop
    @EnvironmentObject private var player: AudioPlayerModel

    var body: some View {
        if player.currentTour?.id == tour.id, player.currentStop?.id == stop.id {
            if player.isLoading {
                Label("Loading story…", systemImage: "arrow.down.circle")
                    .font(.trailBody(13, weight: .semibold))
                    .foregroundStyle(TrailColor.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if let error = player.lastError {
                HStack(spacing: 10) {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.trailBody(12, weight: .semibold))
                        .foregroundStyle(TrailColor.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 4)
                    Button("Retry") { player.load(tour: tour, stop: stop, autoplay: true) }
                        .font(.trailBody(13, weight: .bold))
                        .foregroundStyle(TrailColor.green)
                        .frame(minWidth: 44, minHeight: 44)
                }
            }
        }
    }
}

struct PlayerSheet: View {
    let tour: Tour
    let stop: TourStop
    let nextStop: TourStop?
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onDirections: () -> Void
    @EnvironmentObject private var player: AudioPlayerModel
    @ScaledMetric(relativeTo: .title2) private var numberDiameter = 46.0

    var body: some View {
        VStack(spacing: 10) {
            Text(tour.title)
                .font(.trailBody(15, weight: .semibold))
                .foregroundStyle(TrailColor.muted)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(alignment: .top, spacing: 13) {
                Text("\(stop.number)")
                    .font(.trailTitle(20))
                    .foregroundStyle(TrailColor.ink)
                    .frame(width: numberDiameter, height: numberDiameter)
                    .background(TrailColor.coral, in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    TrailEyebrow(text: "Stop \(stop.number) of \(tour.stops.count)")
                    Text(stop.title).font(.trailTitle(22)).foregroundStyle(TrailColor.ink)
                    Text(stop.summary)
                        .font(.trailBody(14))
                        .foregroundStyle(TrailColor.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let nextStop {
                Button(action: onDirections) {
                    Label(
                        nextStop.id == stop.id
                            ? "Get to stop \(nextStop.number) · \(nextStop.title)"
                            : "Next stop · \(nextStop.title)",
                        systemImage: "location.north.fill"
                    )
                    .font(.trailBody(14, weight: .bold))
                    .foregroundStyle(TrailColor.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(TrailColor.action, in: RoundedRectangle(cornerRadius: TrailShape.button))
                }
                .buttonStyle(.plain)
            }

            StoryAudioStatus(tour: tour, stop: stop)

            Slider(
                value: Binding(
                    get: { player.duration > 0 ? player.progress / player.duration : 0 },
                    set: { player.seek(to: $0) },
                )
            )
            .tint(TrailColor.coral)
            .disabled(player.isLoading || player.duration == 0)
            .accessibilityLabel("Playback position")
            .accessibilityValue("\(playbackTime(player.progress)) of \(playbackTime(player.duration))")

            HStack {
                Text(playbackTime(player.progress))
                Spacer()
                Text(player.isLoading ? "Loading…" : playbackTime(player.duration))
            }
            .font(.trailBody(12, weight: .semibold))
            .foregroundStyle(TrailColor.muted)

            HStack {
                Button(action: onPrevious) {
                    Image(systemName: "backward.end.fill").frame(width: 44, height: 44)
                }
                .disabled(stop.number == 1)
                .accessibilityLabel("Previous story")
                Spacer()
                Button {
                    player.skip(seconds: -15)
                } label: {
                    Image(systemName: "gobackward.15")
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Rewind 15 seconds")
                Spacer()
                StoryPlaybackButton(tour: tour, stop: stop, diameter: 64)
                Spacer()
                Button {
                    player.skip(seconds: 15)
                } label: {
                    Image(systemName: "goforward.15")
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Forward 15 seconds")
                Spacer()
                Button(action: onNext) {
                    Image(systemName: "forward.end.fill").frame(width: 44, height: 44)
                }
                .disabled(stop.number == tour.stops.count)
                .accessibilityLabel("Next story")
            }
            .font(.system(size: 21, weight: .semibold))
            .foregroundStyle(TrailColor.ink)
        }
        .padding(.horizontal, 22)
        .padding(.top, 18)
        .padding(.bottom, 12)
    }
}
