import MapKit
import SwiftUI
import UIKit

struct TourDetailView: View {
    let tour: Tour
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var library: TourLibrary
    @EnvironmentObject private var player: AudioPlayerModel
    @EnvironmentObject private var purchaseStore: PurchaseStore
    @State private var visitedCount = 0
    @State private var showsPurchase = false
    @State private var showsFullRoute = false
    @State private var showsResumeConfirmation = false
    @State private var showsSafetyNotice = false
    @State private var showsStartLocationGate = false
    @State private var showsStartedTour = false
    @State private var startingStopID: String?
    @State private var safetyNoticeClearsProgress = false
    @State private var startLocationConfirmed = false
    @State private var startTourHapticTrigger = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    hero
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            TrailEyebrow(text: "Walking tour")
                            Group {
                                if tour.id == "old-town" {
                                    Text("Victoria Old Town")
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.75)
                                } else {
                                    Text(tour.title)
                                }
                            }
                            .font(.trailTitle(38))
                            .foregroundStyle(TrailColor.ink)
                            TourMetadata(tour: tour, fontSize: 17)
                                .frame(maxWidth: .infinity)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 16)
                                .background(
                                    TrailColor.paper,
                                    in: RoundedRectangle(cornerRadius: TrailShape.card, style: .continuous)
                                )
                                .padding(.top, 8)
                        }

                        VStack(alignment: .leading, spacing: 14) {
                            TrailEyebrow(text: "About this tour", color: TrailColor.muted)
                            Text(tour.about)
                                .font(.trailBody(19))
                                .foregroundStyle(TrailColor.ink)
                                .lineSpacing(5)
                            TourHighlightsView(highlights: highlights)
                        }

                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                TrailEyebrow(text: "Tour route")
                                Spacer()
                                Text("\(tour.stops.count) STOPS")
                                    .font(.trailBody(11, weight: .bold))
                                    .tracking(1)
                                    .foregroundStyle(TrailColor.muted)
                            }
                            ForEach(visibleStops) { stop in
                                RoutePreviewRow(stop: stop, isLast: stop.id == visibleStops.last?.id)
                            }
                            if tour.stops.count > 3 {
                                Button {
                                    withAnimation(reduceMotion ? nil : .default) { showsFullRoute.toggle() }
                                } label: {
                                    Label(
                                        showsFullRoute ? "Show fewer stops" : "View all \(tour.stops.count) stops",
                                        systemImage: showsFullRoute ? "chevron.up" : "chevron.down"
                                    )
                                    .font(.trailBody(15, weight: .bold))
                                    .frame(maxWidth: .infinity, minHeight: 44)
                                }
                                .tint(TrailColor.green)
                                .buttonStyle(TrailPressStyle())
                            }
                        }
                        .padding(.vertical, 18)
                        .overlay(alignment: .top) { Divider().overlay(TrailColor.line) }
                        .overlay(alignment: .bottom) { Divider().overlay(TrailColor.line) }

                        if let imageName = tourStartImageName {
                            NavigationLink {
                                TourMapView(tour: tour, startsPlayer: false)
                            } label: {
                                TourStartLocationCard(imageName: imageName)
                            }
                            .buttonStyle(TrailPressStyle())
                        }

                        VStack(spacing: 0) {
                            if purchaseStore.hasAccess(to: tour) {
                                NavigationLink {
                                    TourMapView(tour: tour, startsPlayer: false)
                                } label: {
                                    DetailRow(
                                        icon: "map.fill", color: TrailColor.green, title: "Tour Route Map",
                                        subtitle: "Route map with tour stops")
                                }
                                NavigationLink {
                                    TourStopsView(tour: tour)
                                } label: {
                                    DetailRow(
                                        icon: "waveform", color: TrailColor.coral, title: "Tour Stop Details",
                                        subtitle: "\(tour.stops.count) audio stops and transcripts")
                                }
                            } else {
                                Button {
                                    showsPurchase = true
                                } label: {
                                    DetailRow(
                                        icon: "lock.fill", color: TrailColor.green, title: "Unlock this tour",
                                        subtitle: "Route, audio stories, transcripts, and offline access", isCard: true)
                                }
                            }
                            NavigationLink {
                                FAQView(tour: tour)
                            } label: {
                                DetailRow(
                                    icon: "info.circle.fill", color: TrailColor.yellow, title: "Know before you go",
                                    subtitle: "Offline access and common questions", isCard: true)
                            }
                            .padding(.top, 12)
                        }
                        .buttonStyle(TrailPressStyle())

                        Button {
                            library.toggleSaved(tour)
                        } label: {
                            Label(
                                library.isSaved(tour) ? "Saved to your walks" : "Save for later",
                                systemImage: library.isSaved(tour) ? "checkmark.circle.fill" : "plus.circle",
                            )
                            .font(.trailBody(16, weight: .semibold))
                            .foregroundStyle(TrailColor.green)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(TrailPressStyle())
                        .sensoryFeedback(.success, trigger: library.isSaved(tour))
                    }
                    .padding(22)
                }
            }
            .scrollIndicators(.hidden)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Group {
                if purchaseStore.hasAccess(to: tour) {
                    Button {
                        prepareToStartTour()
                    } label: {
                        startButton
                    }
                    .sensoryFeedback(.impact(weight: .light), trigger: startTourHapticTrigger)
                } else {
                    Button {
                        showsPurchase = true
                    } label: {
                        startButton
                    }
                }
            }
            .buttonStyle(TrailPressStyle())
            .background(TrailColor.cream)
        }
        .sheet(isPresented: $showsPurchase) {
            PurchaseView(tour: tour)
        }
        .fullScreenCover(isPresented: $showsSafetyNotice, onDismiss: completeSafetyNotice) {
            TourSafetyNoticeView {
                showsSafetyNotice = false
            }
        }
        .fullScreenCover(isPresented: $showsStartLocationGate, onDismiss: completeStartLocationGate) {
            if let firstStop = tour.stops.first {
                TourStartLocationView(
                    tour: tour,
                    stop: firstStop,
                    onCancel: { showsStartLocationGate = false },
                    onArrival: {
                        startLocationConfirmed = true
                        showsStartLocationGate = false
                    }
                )
            }
        }
        .confirmationDialog(
            "Continue your tour?",
            isPresented: $showsResumeConfirmation,
            titleVisibility: .visible
        ) {
            Button("Resume Tour") { resumeTour() }
            Button("Start Again") { startAgain() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Resume at your first incomplete stop, or start again from Stop 1.")
        }
        .navigationDestination(isPresented: $showsStartedTour) {
            TourMapView(tour: tour, startsPlayer: true, startingStopID: startingStopID)
        }
        .toolbar(.hidden, for: .navigationBar)
        .creamBackground()
        .onAppear {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.5)) {
                visitedCount = TourProgress.visitedStopIDs(for: tour.id).count
            }
        }
    }

    private var startButton: some View {
        HStack(spacing: 8) {
            Image(systemName: purchaseStore.hasAccess(to: tour) ? "play.fill" : "lock.fill")
            Text(purchaseStore.hasAccess(to: tour) ? startButtonTitle : unlockButtonTitle)
                .font(.system(.title2, design: .rounded, weight: .bold))
        }
        .foregroundStyle(TrailColor.ink)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .frame(minHeight: 64)
        .background(TrailColor.action, in: RoundedRectangle(cornerRadius: TrailShape.button))
        .padding(.horizontal, 22)
        .padding(.bottom, 10)
    }

    private var visibleStops: [TourStop] {
        showsFullRoute ? tour.stops : Array(tour.stops.prefix(3))
    }

    private func prepareToStartTour() {
        startTourHapticTrigger += 1
        switch TourProgress.startState(for: tour) {
        case .notStarted:
            presentSafetyNotice(clearingProgress: false)
        case .partiallyCompleted:
            showsResumeConfirmation = true
        case .completed:
            presentSafetyNotice(clearingProgress: true)
        }
    }

    private func resumeTour() {
        guard case .partiallyCompleted(let firstIncompleteStopID) = TourProgress.startState(for: tour),
            let stop = tour.stops.first(where: { $0.id == firstIncompleteStopID })
        else {
            startAgain()
            return
        }
        openTour(at: stop)
    }

    private func startAgain() {
        TourProgress.clearVisitedStopIDs(for: tour.id)
        visitedCount = 0
        openTour(at: tour.stops.first)
    }

    private func openTour(at stop: TourStop?) {
        guard let stop else { return }
        startingStopID = stop.id
        showsStartedTour = true
    }

    private func presentSafetyNotice(clearingProgress: Bool) {
        player.resetSession()
        safetyNoticeClearsProgress = clearingProgress
        showsSafetyNotice = true
    }

    private func completeSafetyNotice() {
        showsStartLocationGate = true
    }

    private func completeStartLocationGate() {
        guard startLocationConfirmed else {
            safetyNoticeClearsProgress = false
            return
        }
        startLocationConfirmed = false
        if safetyNoticeClearsProgress {
            TourProgress.clearVisitedStopIDs(for: tour.id)
            visitedCount = 0
        }
        safetyNoticeClearsProgress = false
        openTour(at: tour.stops.first)
    }

    private var tourStartImageName: String? {
        switch tour.id {
        case "inner-harbour":
            return "InnerHarbourTourStart"
        case "old-town":
            return "OldTownTourStart"
        default:
            return nil
        }
    }

    private var highlights: [TourHighlight] {
        switch tour.id {
        case "inner-harbour":
            return [
                TourHighlight(icon: "mappin", title: "8 Must-See Stops"),
                TourHighlight(icon: "star.fill", title: "10 Famous Landmarks"),
                TourHighlight(icon: "music.note", title: "Curated Music"),
            ]
        case "old-town":
            return [
                TourHighlight(icon: "mappin", title: "10 Must-See Stops"),
                TourHighlight(icon: "diamond.fill", title: "Hidden Gems"),
                TourHighlight(icon: "music.note", title: "Curated Music"),
            ]
        case "beacon-hill":
            return [
                TourHighlight(icon: "mappin", title: "10 Must-See Stops"),
                TourHighlight(
                    icon: "point.topleft.down.to.point.bottomright.curvepath", title: "Time-Saving Route"),
                TourHighlight(icon: "binoculars.fill", title: "Beautiful Viewpoints"),
            ]
        case "james-bay":
            return [
                TourHighlight(icon: "mappin", title: "10 Must-See Stops"),
                TourHighlight(icon: "water.waves", title: "Coastal Viewpoints"),
                TourHighlight(icon: "music.note", title: "Curated Music"),
            ]
        default:
            return []
        }
    }

    private var unlockButtonTitle: String {
        if let price = purchaseStore.product(for: tour)?.displayPrice {
            return "Unlock Tour · \(price)"
        }
        return "Unlock Tour"
    }

    private var startButtonTitle: String {
        if visitedCount == 0 { return "Start Tour" }
        if visitedCount >= tour.stops.count { return "Replay Tour" }
        return "Continue Tour"
    }

    private var hero: some View {
        ZStack(alignment: .topLeading) {
            TourImage(tour: tour)
                .frame(height: 270)
                .clipped()
            LinearGradient(colors: [.black.opacity(0.24), .clear], startPoint: .top, endPoint: .center)
            RoundIconButton(systemName: "chevron.left", action: { dismiss() })
                .accessibilityLabel("Back to tours")
                .padding(.leading, 20)
                .padding(.top, 12)
        }
    }
}

private struct TourStartLocationView: View {
    let tour: Tour
    let stop: TourStop
    let onCancel: () -> Void
    let onArrival: () -> Void

    @StateObject private var location = LocationModel()
    @State private var showsCompass = false
    @State private var showsMap = false
    @State private var hasConfirmedArrival = false
    @Environment(\.openURL) private var openURL

    private var locationState: TourStartLocationState {
        TourStartLocationGate.state(
            authorization: location.authorization,
            location: location.location,
            stop: stop
        )
    }

    private var displayTourTitle: String {
        switch tour.id {
        case "inner-harbour":
            return "Victoria Inner Harbour Tour"
        case "old-town":
            return "Victoria Old Town Tour"
        case "james-bay":
            return "James Bay Tour"
        case "beacon-hill":
            return "Beacon Hill Park Tour"
        default:
            return tour.title.hasSuffix("Tour") ? tour.title : "\(tour.title) Tour"
        }
    }

    private var navigationStop: TourStop {
        TourStop(
            id: stop.id,
            number: stop.number,
            title: stop.title,
            summary: stop.summary,
            transcript: stop.transcript,
            imageName: stop.imageName,
            coordinate: stop.coordinate,
            triggerRadiusMeters: TourStartLocationGate.radius,
            audioURL: stop.audioURL,
            audioFile: stop.audioFile
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 62, weight: .semibold))
                        .foregroundStyle(TrailColor.coral)
                        .accessibilityHidden(true)

                    Text("Go to the Tour Start")
                        .font(.trailTitle(32))
                        .foregroundStyle(TrailColor.ink)
                        .multilineTextAlignment(.center)

                    Text(
                        "You are not currently at the \(displayTourTitle) start location. Please proceed to Stop 1 before starting the tour."
                    )
                    .font(.trailBody(18))
                    .foregroundStyle(TrailColor.ink)
                    .multilineTextAlignment(.center)

                    VStack(spacing: 8) {
                        TrailEyebrow(text: "Stop 1")
                        Text(stop.title)
                            .font(.trailTitle(25))
                            .foregroundStyle(TrailColor.ink)
                            .multilineTextAlignment(.center)
                        Text(distanceText)
                            .font(.trailTitle(32))
                            .foregroundStyle(TrailColor.ink)
                        Label(statusText, systemImage: statusSymbol)
                            .font(.trailBody(17, weight: .semibold))
                            .foregroundStyle(statusColor)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(20)
                    .background(TrailColor.paper, in: RoundedRectangle(cornerRadius: TrailShape.card))

                    VStack(spacing: 12) {
                        Button {
                            showsCompass = true
                        } label: {
                            Label("Compass Navigation", systemImage: "location.north.fill")
                                .frame(maxWidth: .infinity, minHeight: 54)
                        }
                        .buttonStyle(StartLocationButtonStyle())

                        Button {
                            showsMap = true
                        } label: {
                            Label("View Start Location Map", systemImage: "map.fill")
                                .frame(maxWidth: .infinity, minHeight: 54)
                        }
                        .buttonStyle(StartLocationButtonStyle())

                        if locationState == .denied {
                            Button("Open Settings") {
                                guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
                                openURL(settingsURL)
                            }
                            .font(.trailBody(17, weight: .bold))
                            .foregroundStyle(TrailColor.ink)
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .background(
                                TrailColor.yellow,
                                in: RoundedRectangle(cornerRadius: TrailShape.button)
                            )
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 28)
            }
            .scrollBounceBehavior(.basedOnSize)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: onCancel) {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Cancel starting tour")
                }
            }
        }
        .background(TrailColor.cream.ignoresSafeArea())
        .interactiveDismissDisabled()
        .onAppear { location.begin(for: []) }
        .onDisappear { location.stop() }
        .onChange(of: locationState, initial: true) { _, state in
            guard case .arrived = state, !hasConfirmedArrival else { return }
            hasConfirmedArrival = true
            UIAccessibility.post(notification: .announcement, argument: "You have arrived at Stop 1.")
            onArrival()
        }
        .fullScreenCover(isPresented: $showsCompass) {
            DirectionView(tour: tour, target: navigationStop, location: location)
        }
        .sheet(isPresented: $showsMap) {
            TourStartMapView(tourTitle: displayTourTitle, stop: stop)
        }
    }

    private var distanceText: String {
        switch locationState {
        case .outside(let distance):
            return NavigationMath.distanceText(distance)
        case .arrived:
            return "At Stop 1"
        default:
            return "Locating…"
        }
    }

    private var statusText: String {
        switch locationState {
        case .requestingPermission:
            return "Requesting location access…"
        case .denied:
            return "Location access is required to start this tour."
        case .locating:
            return "Finding your location…"
        case .inaccurate:
            return "Waiting for an accurate location…"
        case .outside:
            return "Live location active"
        case .arrived:
            return "You have arrived"
        }
    }

    private var statusSymbol: String {
        switch locationState {
        case .denied:
            return "location.slash.fill"
        case .inaccurate, .locating, .requestingPermission:
            return "location.circle"
        case .outside, .arrived:
            return "location.fill"
        }
    }

    private var statusColor: Color {
        switch locationState {
        case .denied:
            return TrailColor.coral
        case .arrived:
            return TrailColor.green
        default:
            return TrailColor.muted
        }
    }
}

private struct StartLocationButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.trailBody(17, weight: .bold))
            .foregroundStyle(TrailColor.ink)
            .padding(.horizontal, 16)
            .background(TrailColor.action, in: RoundedRectangle(cornerRadius: TrailShape.button))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

private struct TourStartMapView: View {
    let tourTitle: String
    let stop: TourStop
    @Environment(\.dismiss) private var dismiss
    @State private var position: MapCameraPosition

    init(tourTitle: String, stop: TourStop) {
        self.tourTitle = tourTitle
        self.stop = stop
        _position = State(
            initialValue: .region(
                MKCoordinateRegion(
                    center: stop.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.003, longitudeDelta: 0.003)
                )
            )
        )
    }

    var body: some View {
        NavigationStack {
            Map(position: $position) {
                Marker("Stop 1 · \(stop.title)", coordinate: stop.coordinate)
                    .tint(TrailColor.coral)
            }
            .navigationTitle(tourTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct TourSafetyNoticeView: View {
    let onUnderstand: () -> Void
    @ScaledMetric(relativeTo: .largeTitle) private var warningSymbolSize = 64.0

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 24) {
                    Spacer(minLength: 32)

                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: warningSymbolSize, weight: .semibold))
                        .foregroundStyle(TrailColor.yellow)
                        .accessibilityHidden(true)

                    VStack(spacing: 18) {
                        Text("Safety is Your Responsibility")
                            .font(.trailTitle(32))
                            .foregroundStyle(TrailColor.ink)

                        Text(
                            "StoryTrail tours guide you around urban pedestrian areas and point out visual features."
                        )
                        .font(.trailBody(18))
                        .foregroundStyle(TrailColor.ink)

                        Text(
                            "But it is your responsibility to stay safe and use good judgement. You are responsible for your own safety."
                        )
                        .font(.trailBody(18, weight: .semibold))
                        .foregroundStyle(TrailColor.ink)
                    }
                    .multilineTextAlignment(.center)

                    Button("I Understand", action: onUnderstand)
                        .font(.trailBody(18, weight: .bold))
                        .foregroundStyle(TrailColor.ink)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(TrailColor.action, in: RoundedRectangle(cornerRadius: TrailShape.button))
                        .buttonStyle(TrailPressStyle())
                        .accessibilityHint("Starts the tour")

                    Spacer(minLength: 32)
                }
                .padding(.horizontal, 28)
                .frame(maxWidth: .infinity, minHeight: geometry.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .background(TrailColor.cream.ignoresSafeArea())
        .interactiveDismissDisabled()
    }
}

private struct TourStartLocationCard: View {
    let imageName: String

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(imageName)
                .resizable()
                .aspectRatio(contentMode: .fit)

            Text("Tour Start Location")
                .font(.trailBody(17, weight: .bold))
                .foregroundStyle(TrailColor.cream)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(TrailColor.yellow, in: Capsule())
                .padding(14)
        }
        .clipShape(RoundedRectangle(cornerRadius: TrailShape.card, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Tour Start Location")
        .accessibilityHint("Opens the tour route map")
    }
}

private struct TourHighlight: Identifiable {
    let icon: String
    let title: String

    var id: String { title }
}

private struct TourHighlightsView: View {
    let highlights: [TourHighlight]

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            ForEach(highlights) { highlight in
                HStack(spacing: 12) {
                    Image(systemName: highlight.icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(TrailColor.coral)
                        .frame(width: 24)
                    Text(highlight.title)
                        .font(.trailBody(16, weight: .semibold))
                        .foregroundStyle(TrailColor.ink)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }
}

struct RoutePreviewRow: View {
    let stop: TourStop
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            VStack(spacing: 4) {
                Text("\(stop.number)")
                    .font(.trailBody(13, weight: .bold))
                    .foregroundStyle(TrailColor.ink)
                    .frame(width: 30, height: 30)
                    .background(TrailColor.action, in: Circle())
                if !isLast {
                    Rectangle()
                        .fill(TrailColor.green.opacity(0.24))
                        .frame(width: 2, height: 22)
                }
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(stop.title)
                    .font(.trailBody(16, weight: .bold))
                    .foregroundStyle(TrailColor.ink)
                Text(stop.summary)
                    .font(.trailBody(13))
                    .foregroundStyle(TrailColor.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

struct DetailRow: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String
    var isCard = false
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 21, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 32, height: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.trailBody(18, weight: .bold)).foregroundStyle(TrailColor.ink)
                Text(subtitle).font(.trailBody(16)).foregroundStyle(TrailColor.muted)
            }
            Spacer()
            Image(systemName: "chevron.right").fontWeight(.bold).foregroundStyle(TrailColor.muted)
        }
        .padding(.horizontal, isCard ? 14 : 0)
        .padding(.vertical, 14)
        .frame(minHeight: 72)
        .background(
            isCard ? TrailColor.paper : .clear,
            in: RoundedRectangle(cornerRadius: TrailShape.card, style: .continuous)
        )
        .overlay(alignment: .bottom) {
            if !isCard {
                Divider().overlay(TrailColor.line)
            }
        }
        .contentShape(Rectangle())
    }
}

struct FAQView: View {
    let tour: Tour

    private var displayTitle: String {
        switch tour.id {
        case "inner-harbour": "Victoria Inner Harbour"
        case "old-town": "Victoria Old Town"
        default: tour.title
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    TrailEyebrow(text: displayTitle)
                    Text("Know before you go.")
                        .font(.trailTitle(34))
                        .foregroundStyle(TrailColor.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 6)
                if tour.id == "inner-harbour" {
                    FAQRow(
                        question: "Where does this tour start?",
                        answer:
                            "This tour starts at the Victoria Visitor Center, at the corner of Government Street and Wharf Street. When you arrive here, press the Start Tour button. If the audio does not start, walk closer to the Victoria Visitor Center."
                    )
                }
                FAQRow(
                    question: "Do I need cellular data?",
                    answer:
                        "No. We strongly recommend that you download a tour via prior to use. Wifi is usually best for downloading. These audio tours are designed to work offline.",
                )
                FAQRow(
                    question: "Does this tour play automatically?",
                    answer:
                        "Yes. Once you start a tour, the app senses your location by GPS and triggers tour stop audio automatically once you enter a tour stop area.",
                )
                FAQRow(
                    question: "What if I reach the next stop while audio is playing?",
                    answer:
                        "The tour stops are sequenced so that the currently-playing audio will finish before the next stop begins. Don't rush, though! The tour audio will guide you to next stop.",
                )
                FAQRow(
                    question: "Can I pause or skip a stop?",
                    answer:
                        "Yes. You can pause the audio and walk to the next stop, if you like. You may need to check the map for directions."
                )
            }
            .padding(22)
        }
        .navigationTitle("Know before you go")
        .navigationBarTitleDisplayMode(.inline)
        .creamBackground()
    }
}

struct FAQRow: View {
    let question: String
    let answer: String
    @State private var expanded = false
    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            Text(answer).font(.trailBody(15)).foregroundStyle(TrailColor.muted).padding(.vertical, 8)
        } label: {
            Text(question)
                .font(.trailBody(17, weight: .bold))
                .foregroundStyle(TrailColor.ink)
                .multilineTextAlignment(.leading)
        }
        .tint(TrailColor.green)
        .padding(.vertical, 18)
        .overlay(alignment: .bottom) { Divider().overlay(TrailColor.line) }
    }
}
