import SwiftUI

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var selection = 0
    @State private var tourPath: [Tour] = []
    @State private var pendingTourID: String?
    @EnvironmentObject private var library: TourLibrary

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack(path: $tourPath) { ToursView() }
                .tabItem { Label("Tours", systemImage: "location.north.circle.fill") }
                .tag(0)
            NavigationStack { MyBagView(onExplore: { selection = 0 }) }
                .tabItem { Label("Saved", systemImage: "heart.fill") }
                .tag(1)
            NavigationStack { AllToursMapView() }
                .tabItem { Label("Map", systemImage: "map.fill") }
                .tag(2)
            NavigationStack { SupportView() }
                .tabItem { Label("Support", systemImage: "questionmark.circle.fill") }
                .tag(3)
        }
        .tint(TrailColor.green)
        .preferredColorScheme(.dark)
        .onOpenURL { url in
            guard let tourID = WidgetTourLink.tourID(from: url) else { return }
            pendingTourID = tourID
            openPendingTour()
        }
        .onChange(of: library.tours) { _, _ in openPendingTour() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { library.refreshSavedTours() }
        }
        .onReceive(NotificationCenter.default.publisher(for: SavedToursStore.didChangeNotification)) { _ in
            library.refreshSavedTours()
        }
    }

    private func openPendingTour() {
        guard let pendingTourID, let tour = library.tours.first(where: { $0.id == pendingTourID }) else {
            return
        }
        selection = 0
        tourPath = [tour]
        self.pendingTourID = nil
    }
}

struct ToursView: View {
    @EnvironmentObject private var library: TourLibrary
    @State private var tourCardHapticTrigger = 0
    @State private var showsHowToStartTour = false

    var body: some View {
        ZStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    BrandMark()
                        .padding(.top, 12)

                    TrailPageHeader(
                        eyebrow: "",
                        title: "Tour Victoria",
                        subtitle: "Explore at your own pace with stories that play automatically as you walk."
                    )

                    Button {
                        showsHowToStartTour = true
                    } label: {
                        HowItWorksButton()
                    }
                    .buttonStyle(TrailPressStyle())

                    if !library.tours.isEmpty {
                        TourChooserHeader()

                        LazyVStack(spacing: 12) {
                            ForEach(library.tours) { tour in
                                NavigationLink(value: tour) { CompactTourCard(tour: tour) }
                                    .buttonStyle(TrailPressStyle())
                                    .simultaneousGesture(TapGesture().onEnded { tourCardHapticTrigger += 1 })
                            }
                        }
                    }

                    VStack(spacing: 0) {
                        HomeInfoRow(
                            icon: "arrow.down.circle.fill",
                            title: "Made to work offline",
                            detail: "Download your tour via wifi before heading out the door."
                        )
                        Divider().overlay(TrailColor.line)
                        HomeInfoRow(
                            icon: "headphones",
                            title: "Headphones recommended",
                            detail: "For the best listening experience, we strongly recommend you use headphones."
                        )
                        Divider().overlay(TrailColor.line)
                        HomeInfoRow(
                            icon: "battery.50",
                            iconRotation: .degrees(-90),
                            title: "GPS & Battery Usage",
                            detail:
                                "Continuous location tracking can drain your battery faster than normal. We recommend starting with a well-charged phone."
                        )
                    }
                    .overlay(alignment: .top) { Divider().overlay(TrailColor.line) }
                    .padding(.top, 8)
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)

            if library.isLoading && library.tours.isEmpty {
                ProgressView("Loading tours…")
                    .font(.trailBody(15, weight: .semibold))
                    .padding(22)
                    .background(TrailColor.paper, in: RoundedRectangle(cornerRadius: 18))
            } else if let error = library.loadError, library.tours.isEmpty {
                ContentUnavailableView {
                    Label("Couldn't load tours", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                } actions: {
                    Button("Try again") { Task { await library.reload() } }
                }
            }
        }
        .navigationDestination(for: Tour.self) { TourDetailView(tour: $0) }
        .sensoryFeedback(.impact(weight: .light), trigger: tourCardHapticTrigger)
        .toolbar(.hidden, for: .navigationBar)
        .creamBackground()
        .fullScreenCover(isPresented: $showsHowToStartTour) {
            HowToStartTourOverlay {
                showsHowToStartTour = false
            }
            .presentationBackground(.clear)
        }
    }
}

private struct HowItWorksButton: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 19, weight: .bold))
                .accessibilityHidden(true)
            Text("How it works")
                .font(.system(.title2, design: .rounded, weight: .bold))
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 15, weight: .bold))
                .accessibilityHidden(true)
        }
        .foregroundStyle(TrailColor.coral)
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, minHeight: 64)
        .background(TrailColor.paper, in: RoundedRectangle(cornerRadius: TrailShape.button))
        .contentShape(RoundedRectangle(cornerRadius: TrailShape.button))
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens instructions for taking a tour")
    }
}

private struct TourChooserHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            TrailEyebrow(text: "Choose a Victoria tour", color: TrailColor.muted)
            HStack(spacing: 8) {
                Image(systemName: "headphones")
                    .accessibilityHidden(true)
                Text("Free demos available for each")
            }
            .font(.trailBody(15, weight: .semibold))
            .foregroundStyle(TrailColor.green)
            .accessibilityElement(children: .combine)
        }
    }
}

private struct HowToStartTourOverlay: View {
    let onDismiss: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.opacity(0.62)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onDismiss)
                    .accessibilityHidden(true)

                HowToStartTourSheet(onDismiss: onDismiss)
                    .frame(maxWidth: 620)
                    .frame(height: geometry.size.height * (dynamicTypeSize.isAccessibilitySize ? 0.9 : 0.75))
                    .padding(.horizontal, 20)
            }
        }
        .accessibilityAction(.escape, onDismiss)
    }
}

private struct HowToStartTourSheet: View {
    let onDismiss: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .top) {
                    Text("How to Start a Tour")
                        .font(.trailTitle(32))
                        .foregroundStyle(TrailColor.ink)
                        .accessibilityAddTraits(.isHeader)
                    Spacer(minLength: 12)
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(TrailColor.ink)
                            .frame(width: 44, height: 44)
                            .background(TrailColor.unavailableAction, in: Circle())
                    }
                    .accessibilityLabel("Close instructions")
                }

                VStack(alignment: .leading, spacing: 22) {
                    HowToStartTourStep(
                        title: "Step 1: Choose a tour",
                        detail:
                            "Browse our walking tours, listen to a free demo, and purchase the one you'd like to take."
                    )
                    HowToStartTourStep(
                        title: "Step 2: Download for offline use",
                        detail: "It's best download your tour using Wi-Fi before heading out."
                    )
                    HowToStartTourStep(
                        title: "Step 3: Find your starting point",
                        detail: "Check the tour map and make your way to Stop 1."
                    )
                    HowToStartTourStep(
                        title: "Step 4: Press play and explore",
                        detail:
                            "Start your tour at Stop 1. Stories play automatically as you reach each stop and guide you to the next stop."
                    )
                }
            }
            .padding(24)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(TrailColor.paper, in: RoundedRectangle(cornerRadius: TrailShape.card, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: TrailShape.card, style: .continuous))
        .shadow(color: .black.opacity(0.35), radius: 20, y: 8)
    }
}

private struct HowToStartTourStep: View {
    let title: LocalizedStringKey
    let detail: LocalizedStringKey

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.trailBody(19, weight: .bold))
                .foregroundStyle(TrailColor.green)
                .accessibilityAddTraits(.isHeader)
            Text(detail)
                .font(.trailBody(17))
                .foregroundStyle(TrailColor.ink)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct HomeInfoRow: View {
    let icon: String
    let iconRotation: Angle
    let title: String
    let detail: String

    init(icon: String, iconRotation: Angle = .zero, title: String, detail: String) {
        self.icon = icon
        self.iconRotation = iconRotation
        self.title = title
        self.detail = detail
    }

    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(TrailColor.green)
                .rotationEffect(iconRotation)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.trailBody(16, weight: .bold))
                    .foregroundStyle(TrailColor.ink)
                Text(detail)
                    .font(.trailBody(14))
                    .foregroundStyle(TrailColor.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 20)
        .accessibilityElement(children: .combine)
    }
}

struct BrandMark: View {
    var body: some View {
        HStack(spacing: 10) {
            Image("BrandIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 54, height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            Text("StoryTrail")
                .font(.trailTitle(23))
                .foregroundStyle(TrailColor.ink)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("StoryTrail")
    }
}

struct CompactTourCard: View {
    let tour: Tour
    var accessLabel: String? = nil
    @EnvironmentObject private var purchaseStore: PurchaseStore

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            TourImage(tour: tour)
                .frame(width: 88, height: 88)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text(displayTitle)
                    .font(.trailTitle(19))
                    .foregroundStyle(TrailColor.ink)
                Text(displaySubtitle)
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(TrailColor.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                HStack(spacing: 8) {
                    Text(displayMetadata)
                        .font(.trailBody(12, weight: .semibold))
                    Spacer(minLength: 8)
                    Text(displayAccessLabel)
                        .font(.trailBody(11, weight: .bold))
                        .tracking(1)
                }
                .foregroundStyle(TrailColor.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(TrailColor.muted)
                .accessibilityHidden(true)
        }
        .padding(14)
        .background(TrailColor.paper, in: RoundedRectangle(cornerRadius: TrailShape.card, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: TrailShape.card, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens tour details")
    }

    private var displayTitle: String {
        switch tour.id {
        case "inner-harbour": "Inner Harbour"
        case "old-town": "Old Town"
        default: tour.title
        }
    }

    private var displaySubtitle: LocalizedStringResource {
        switch tour.id {
        case "inner-harbour": "Iconic waterfront & landmarks"
        case "old-town": "Hidden alleys & beautiful buildings"
        case "james-bay": "Victoria's historic neighbourhood"
        case "beacon-hill": "Landscape, views & stories"
        default: "Victoria walking tour"
        }
    }

    private var displayMetadata: String {
        switch tour.id {
        case "old-town":
            "60 min · 1.2 km"
        case "james-bay":
            "90 min · 2.1 km"
        case "beacon-hill":
            "\(tour.minutes) min · 1.5 km"
        default:
            "\(tour.minutes) min · \(String(format: "%.1f", tour.distance)) km"
        }
    }

    private var displayAccessLabel: String {
        if let accessLabel {
            return accessLabel
        }
        switch tour.id {
        case "inner-harbour", "beacon-hill":
            return "$9.99"
        case "old-town", "james-bay":
            return "$12.99"
        default:
            return purchaseStore.accessLabel(for: tour)
        }
    }
}

struct TourImage: View {
    let tour: Tour

    var body: some View {
        GeometryReader { geometry in
            Image(tour.imageName)
                .resizable()
                .scaledToFill()
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
        }
    }
}

struct IllustratedSky: View {
    let palette: TourPalette
    var body: some View {
        ZStack {
            LinearGradient(colors: palette.colors, startPoint: .top, endPoint: .bottom)
            HStack(alignment: .bottom, spacing: 12) {
                ForEach(0..<5, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 6)
                        .fill((palette.colors.last ?? TrailColor.green).opacity(0.65))
                        .frame(width: 48, height: CGFloat([72, 112, 64, 92, 76][index]))
                }
            }
            .padding(.bottom, -8)
        }
    }
}
