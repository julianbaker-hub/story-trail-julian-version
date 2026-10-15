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

    private var featuredTour: Tour? { library.tours.first }
    private var remainingTours: [Tour] { Array(library.tours.dropFirst()) }

    var body: some View {
        ZStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    BrandMark()
                        .padding(.top, 12)

                    TrailPageHeader(
                        eyebrow: "",
                        title: "Explore Victoria",
                        subtitle: "Choose a tour, download it, and listen as each landmark comes to life"
                    )
                    .padding(.bottom, 8)

                    if let featuredTour {
                        NavigationLink(value: featuredTour) {
                            FeaturedTourCard(tour: featuredTour)
                        }
                        .buttonStyle(TrailPressStyle())
                        .simultaneousGesture(TapGesture().onEnded { tourCardHapticTrigger += 1 })
                    }

                    if !remainingTours.isEmpty {
                        HStack {
                            TrailEyebrow(text: "More tours", color: TrailColor.muted)
                            Spacer()
                            Text("VICTORIA, B.C.")
                                .font(.trailBody(10, weight: .bold))
                                .tracking(1.4)
                                .foregroundStyle(TrailColor.muted)
                        }

                        LazyVStack(spacing: 12) {
                            ForEach(remainingTours) { tour in
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
    }
}

private struct HomeInfoRow: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(TrailColor.green)
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

struct FeaturedTourCard: View {
    let tour: Tour

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ZStack(alignment: .topTrailing) {
                TourImage(tour: tour)
                    .frame(height: 230)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                Text("FEATURED TOUR")
                    .font(.trailBody(11, weight: .bold))
                    .tracking(1.3)
                    .foregroundStyle(TrailColor.cream)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(TrailColor.yellow, in: Capsule())
                    .padding(14)

                VStack {
                    Spacer()
                    HStack {
                        Text("$10")
                            .font(.trailBody(11, weight: .bold))
                            .tracking(1.1)
                            .foregroundStyle(TrailColor.ink)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(TrailColor.paper, in: Capsule())
                        Spacer()
                    }
                    .padding(14)
                }
            }

            VStack(alignment: .leading, spacing: 11) {
                Text(tour.title).font(.trailTitle(28)).foregroundStyle(TrailColor.ink)
                TourMetadata(tour: tour)
            }
        }
        .padding(14)
        .background(TrailColor.paper, in: RoundedRectangle(cornerRadius: TrailShape.card, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: TrailShape.card, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens tour details")
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
                Text(displayMetadata)
                    .font(.trailBody(12, weight: .semibold))
                    .foregroundStyle(TrailColor.muted)
                Text(displayAccessLabel)
                    .font(.trailBody(11, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(TrailColor.muted)
            }
            Spacer(minLength: 0)
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
        tour.id == "old-town" ? "Victoria Old Town" : tour.title
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
        case "old-town", "james-bay", "beacon-hill":
            return "$10"
        default:
            return purchaseStore.accessLabel(for: tour)
        }
    }
}

struct TourImage: View {
    let tour: Tour

    var body: some View {
        GeometryReader { geometry in
            AsyncImage(url: tour.imageURL) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else {
                    IllustratedSky(palette: tour.palette)
                }
            }
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
