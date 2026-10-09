import SwiftUI

struct TourDetailView: View {
    let tour: Tour
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var library: TourLibrary
    @EnvironmentObject private var purchaseStore: PurchaseStore
    @State private var visitedCount = 0
    @State private var showsPurchase = false
    @State private var showsFullRoute = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    hero
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            TrailEyebrow(text: "Walking tour")
                            Text(tour.title)
                                .font(.trailTitle(38))
                                .foregroundStyle(TrailColor.ink)
                            Text(tour.subtitle)
                                .font(.trailBody(17, weight: .semibold))
                                .foregroundStyle(TrailColor.muted)
                            TourMetadata(tour: tour)
                                .padding(.top, 4)
                        }

                        VStack(alignment: .leading, spacing: 9) {
                            HStack {
                                Label("Your walk", systemImage: "figure.walk")
                                    .font(.trailBody(16, weight: .bold))
                                Spacer()
                                Text("\(visitedCount) / \(tour.stops.count) stops")
                                    .font(.trailBody(13, weight: .bold))
                            }
                            .foregroundStyle(TrailColor.muted)
                            ProgressView(value: Double(visitedCount), total: Double(tour.stops.count))
                                .tint(TrailColor.green)
                                .accessibilityLabel("Tour progress")
                                .accessibilityValue("\(visitedCount) of \(tour.stops.count) stops visited")
                            Text(visitedCount == 0 ? "Every stop has a story waiting." : "Pick up where you left off.")
                                .font(.trailBody(14))
                                .foregroundStyle(TrailColor.muted)
                        }
                        .padding(.vertical, 18)
                        .overlay(alignment: .bottom) { Divider().overlay(TrailColor.line) }

                        TrailEyebrow(text: "About this walk", color: TrailColor.muted)
                            .padding(.top, 4)
                        Text(tour.about)
                            .font(.trailBody(19))
                            .foregroundStyle(TrailColor.ink)
                            .lineSpacing(5)

                        HStack(alignment: .top, spacing: 13) {
                            Image(systemName: "eye.fill")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(TrailColor.ink)
                                .frame(width: 30, height: 30)
                            VStack(alignment: .leading, spacing: 3) {
                                TrailEyebrow(text: "Field note", color: TrailColor.ink)
                                Text(
                                    "Keep your headphones on and your eyes up. Stories begin automatically as you arrive."
                                )
                                .font(.trailBody(15, weight: .semibold))
                                .foregroundStyle(TrailColor.ink)
                                .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(.leading, 16)
                        .overlay(alignment: .leading) {
                            Rectangle().fill(TrailColor.yellow).frame(width: 3)
                        }

                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                TrailEyebrow(text: "Your route")
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

                        VStack(spacing: 0) {
                            if purchaseStore.hasAccess(to: tour) {
                                NavigationLink {
                                    TourMapView(tour: tour, startsPlayer: false)
                                } label: {
                                    DetailRow(
                                        icon: "map.fill", color: TrailColor.green, title: "Explore the route",
                                        subtitle: "Map, stops, and directions")
                                }
                                NavigationLink {
                                    TourStopsView(tour: tour)
                                } label: {
                                    DetailRow(
                                        icon: "waveform", color: TrailColor.coral, title: "All stories",
                                        subtitle: "\(tour.stops.count) audio stops and transcripts")
                                }
                            } else {
                                Button {
                                    showsPurchase = true
                                } label: {
                                    DetailRow(
                                        icon: "lock.fill", color: TrailColor.green, title: "Unlock this tour",
                                        subtitle: "Route, audio stories, transcripts, and offline access")
                                }
                            }
                            NavigationLink {
                                FAQView(tour: tour)
                            } label: {
                                DetailRow(
                                    icon: "info.circle.fill", color: TrailColor.yellow, title: "Before you go",
                                    subtitle: "Offline access and common questions")
                            }
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
                    NavigationLink {
                        TourMapView(tour: tour, startsPlayer: true)
                    } label: {
                        startButton
                    }
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
            if !purchaseStore.hasAccess(to: tour) {
                Image(systemName: "lock.fill")
            }
            Text(purchaseStore.hasAccess(to: tour) ? startButtonTitle : unlockButtonTitle)
                .font(.trailBody(18, weight: .bold))
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
                    .lineLimit(2)
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
        .padding(.vertical, 14)
        .frame(minHeight: 72)
        .overlay(alignment: .bottom) { Divider().overlay(TrailColor.line) }
        .contentShape(Rectangle())
    }
}

struct FAQView: View {
    let tour: Tour
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                TrailPageHeader(
                    eyebrow: tour.title,
                    title: "Before you go.",
                    subtitle: "A few useful answers for a relaxed walk."
                )
                .padding(.bottom, 6)
                FAQRow(
                    question: "Do I need mobile data?",
                    answer:
                        "No for GPS, compass navigation, tour details, and bundled stories. Stops with online audio need a connection the first time they are loaded, and Apple Maps may need data for uncached map detail.",
                )
                FAQRow(
                    question: "Does the tour play automatically?",
                    answer:
                        "After you start a tour, StoryTrail plays a stop when you come within about 30 metres. You can always choose stops manually.",
                )
                FAQRow(
                    question: "What if I reach the next stop while audio is playing?",
                    answer:
                        "The current story stops and the new stop starts from the beginning, so what you hear always matches where you are.",
                )
                FAQRow(
                    question: "Can I pause or skip a stop?",
                    answer: "Yes. The player supports pause, seeking, and moving between stops.")
            }
            .padding(22)
        }
        .navigationTitle("Before you go")
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
