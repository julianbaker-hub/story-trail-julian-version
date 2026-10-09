import MapKit
import SwiftUI
import WebKit

struct MyBagView: View {
    let onExplore: () -> Void
    @EnvironmentObject private var library: TourLibrary
    private var saved: [Tour] { library.tours.filter(library.isSaved) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                BrandMark()
                TrailPageHeader(
                    eyebrow: "Your collection",
                    title: "Walks worth keeping.",
                    subtitle: "Your saved routes stay close whenever you are ready to head out."
                )
                if saved.isEmpty {
                    emptyState
                } else {
                    ForEach(Array(saved.enumerated()), id: \.element.id) { index, tour in
                        NavigationLink(value: tour) { CompactTourCard(tour: tour) }
                            .buttonStyle(TrailPressStyle())
                        if index < saved.count - 1 {
                            Divider().overlay(TrailColor.line)
                        }
                    }
                }
            }
            .padding(22)
        }
        .navigationDestination(for: Tour.self) { TourDetailView(tour: $0) }
        .toolbar(.hidden, for: .navigationBar)
        .creamBackground()
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: "bookmark.fill")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(TrailColor.green)
                .frame(width: 60, height: 60)
                .background(TrailColor.sky.opacity(0.45), in: Circle())
            Text("Your next favourite walk starts here")
                .font(.trailTitle(24))
                .foregroundStyle(TrailColor.ink)
            Text("Save a tour to keep its route and stories handy for later.")
                .font(.trailBody(15))
                .foregroundStyle(TrailColor.muted)
            Button(action: onExplore) {
                Label("Explore walks", systemImage: "arrow.right")
                    .font(.trailBody(16, weight: .bold))
                    .foregroundStyle(TrailColor.ink)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(TrailColor.action, in: RoundedRectangle(cornerRadius: TrailShape.button))
            }
            .buttonStyle(TrailPressStyle())
        }
        .padding(.top, 24)
    }
}

struct AllToursMapView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var library: TourLibrary
    @EnvironmentObject private var connectivity: ConnectivityModel
    @EnvironmentObject private var purchaseStore: PurchaseStore
    @State private var selectedTour: Tour?
    @State private var position: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 48.4225, longitude: -123.369),
            latitudinalMeters: 3500, longitudinalMeters: 3500,
        ))

    var body: some View {
        ZStack(alignment: .top) {
            Map(position: $position, selection: $selectedTour) {
                ForEach(library.tours) { tour in
                    if tour.id == "inner-harbour" {
                        MapPolyline(coordinates: tour.routeCoordinates)
                            .stroke(
                                TrailColor.green,
                                style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: [4, 9]))
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
                                StopMapPin(number: stop.number, active: false, visited: false)
                            }
                            .tag(tour)
                        }
                    } else if let first = tour.stops.first {
                        Marker(tour.title, systemImage: "figure.walk", coordinate: first.coordinate)
                            .tint(TrailColor.green)
                            .tag(tour)
                    }
                }
                UserAnnotation()
            }
            .mapStyle(.standard(elevation: .realistic))

            VStack(spacing: 8) {
                if connectivity.isOffline {
                    Label("Offline — map detail may be unavailable", systemImage: "wifi.slash")
                        .foregroundStyle(TrailColor.cream)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(TrailColor.yellow, in: Capsule())
                }
                if selectedTour == nil {
                    Label("Tap a pin to preview a walk", systemImage: "hand.tap")
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(TrailColor.paper, in: Capsule())
                }
            }
            .font(.trailBody(13, weight: .bold))
            .foregroundStyle(TrailColor.ink)
            .padding(.top, 12)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let selectedTour {
                NavigationLink(value: selectedTour) {
                    HStack(spacing: 14) {
                        Image(systemName: "figure.walk.circle.fill")
                            .font(.system(size: 35))
                            .foregroundStyle(TrailColor.green)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 4) {
                            TrailEyebrow(text: purchaseStore.accessLabel(for: selectedTour))
                            Text(selectedTour.title)
                                .font(.trailBody(19, weight: .bold))
                                .foregroundStyle(TrailColor.ink)
                            Text("\(selectedTour.minutes) min · \(selectedTour.stops.count) stories")
                                .font(.trailBody(14))
                                .foregroundStyle(TrailColor.muted)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(TrailColor.green)
                            .accessibilityHidden(true)
                    }
                    .padding(.horizontal, 22)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity)
                    .background(.regularMaterial)
                    .overlay(alignment: .top) { Divider() }
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                }
                .buttonStyle(TrailPressStyle())
                .accessibilityHint("Opens tour details")
            }
        }
        .navigationDestination(for: Tour.self) { TourDetailView(tour: $0) }
        .navigationTitle("Walks on the map")
        .navigationBarTitleDisplayMode(.inline)
        .animation(reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.82), value: selectedTour?.id)
        .sensoryFeedback(.selection, trigger: selectedTour?.id)
    }
}

struct SupportView: View {
    @EnvironmentObject private var purchaseStore: PurchaseStore

    private var versionDescription: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        return version.map { "StoryTrail v\($0)" } ?? "StoryTrail"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                BrandMark()
                TrailPageHeader(
                    eyebrow: "Support & settings",
                    title: "Help for the journey.",
                    subtitle: "Answers, purchase help, and the practical details for a good walk."
                )
                .padding(.top, 8)

                TrailEyebrow(text: "Your access", color: TrailColor.muted)

                purchaseSupport

                TrailEyebrow(text: "Help & legal", color: TrailColor.muted)
                    .padding(.top, 6)
                VStack(spacing: 0) {
                    ForEach(Array(SupportDestination.allCases.enumerated()), id: \.element.id) { index, destination in
                        NavigationLink(value: destination) {
                            SupportLinkRow(destination: destination)
                        }
                        .buttonStyle(TrailPressStyle())
                        if index < SupportDestination.allCases.count - 1 {
                            Divider().overlay(TrailColor.line)
                        }
                    }
                }

                TrailEyebrow(text: "Tour essentials", color: TrailColor.muted)
                    .padding(.top, 6)
                VStack(spacing: 0) {
                    SupportCard(
                        icon: "location.fill", title: "Location",
                        detail:
                            "Allow location while using the app to highlight nearby stops. You can still select every stop manually.",
                    )
                    SupportCard(
                        icon: "headphones", title: "Audio",
                        detail: "Use headphones in busy areas, but stay aware of traffic and your surroundings.")
                    SupportCard(
                        icon: "wifi.slash", title: "Works offline",
                        detail:
                            "Tour details, bundled stories, GPS, and compass navigation work without data. Apple Maps may need a connection for uncached map detail.",
                    )
                }

                Text(versionDescription)
                    .font(.trailBody(13, weight: .semibold))
                    .foregroundStyle(TrailColor.muted)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 12)
            }
            .padding(22)
        }
        .toolbar(.hidden, for: .navigationBar)
        .creamBackground()
        .navigationDestination(for: SupportDestination.self) { destination in
            supportDestination(destination)
        }
        .alert(
            "Purchase problem",
            isPresented: Binding(
                get: { purchaseStore.errorMessage != nil },
                set: { if !$0 { purchaseStore.clearError() } },
            ),
            actions: { Button("OK") { purchaseStore.clearError() } },
            message: { Text(purchaseStore.errorMessage ?? "Please try again.") },
        )
    }

    @ViewBuilder
    private func supportDestination(_ destination: SupportDestination) -> some View {
        switch destination {
        case .helpCenter:
            HelpCenterView()
        case .contactSupport:
            ContactSupportView()
        case .termsOfService, .privacyPolicy:
            if let url = destination.liveDocumentURL {
                LiveSupportDocumentView(destination: destination, url: url)
            } else {
                ContentUnavailableView("Document unavailable", systemImage: "doc.text.magnifyingglass")
            }
        }
    }

    private var purchaseSupport: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Purchases", systemImage: "person.crop.circle.fill")
                .font(.trailBody(18, weight: .bold))
                .foregroundStyle(TrailColor.ink)
            Text("Restore access with the Apple ID used to buy your tours.")
                .font(.trailBody(15))
                .foregroundStyle(TrailColor.muted)
            Button("Restore Purchases") {
                Task { await purchaseStore.restorePurchases() }
            }
            .font(.trailBody(16, weight: .bold))
            .foregroundStyle(TrailColor.green)
            .frame(minHeight: 44)
            .disabled(purchaseStore.isLoading)
        }
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) { Divider().overlay(TrailColor.line) }
    }
}

private enum SupportDestination: String, CaseIterable, Hashable, Identifiable {
    case helpCenter
    case contactSupport
    case termsOfService
    case privacyPolicy

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .helpCenter: "questionmark.circle.fill"
        case .contactSupport: "envelope.fill"
        case .termsOfService: "doc.text.fill"
        case .privacyPolicy: "hand.raised.fill"
        }
    }

    var title: String {
        switch self {
        case .helpCenter: "Help Center"
        case .contactSupport: "Contact Support"
        case .termsOfService: "Terms of Service"
        case .privacyPolicy: "Privacy Policy"
        }
    }

    var detail: String {
        switch self {
        case .helpCenter: "FAQs and guides"
        case .contactSupport: "Get help from our team"
        case .termsOfService: "Read our terms"
        case .privacyPolicy: "How we protect your data"
        }
    }

    var liveDocumentURL: URL? {
        switch self {
        case .termsOfService:
            URL(string: "https://storytrailguide.com/TermsOfService")
        case .privacyPolicy:
            URL(string: "https://storytrailguide.com/PrivacyPolicy")
        case .helpCenter, .contactSupport:
            nil
        }
    }
}

private struct SupportLinkRow: View {
    let destination: SupportDestination

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: destination.icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(TrailColor.green)
                .frame(width: 32, height: 42)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(destination.title)
                    .font(.trailBody(17, weight: .bold))
                    .foregroundStyle(TrailColor.ink)
                Text(destination.detail)
                    .font(.trailBody(14))
                    .foregroundStyle(TrailColor.muted)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(TrailColor.muted)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

private struct HelpCenterView: View {
    private let articles = [
        HelpArticle(
            title: "How to use StoryTrail",
            detail:
                "Choose a walk from Tours, unlock it if needed, and tap Start Tour. Follow the route to each stop. Nearby stories can be selected automatically with location access, and every stop can also be opened manually.",
        ),
        HelpArticle(
            title: "How to Redeem Purchased Tours",
            detail:
                "Tours purchased with your Apple ID unlock automatically. If a purchase is missing, return to Support and tap Restore Purchases. StoryTrail does not require a separate redemption code.",
        ),
        HelpArticle(
            title: "App FAQs",
            detail:
                "Tour details, stops, bundled audio, GPS, and compass guidance work offline. Apple Maps may need a connection for uncached map detail. Location access is only needed for nearby-stop detection; manual selection remains available.",
        ),
        HelpArticle(
            title: "How to Log Out or Change Accounts",
            detail:
                "StoryTrail does not use a separate app account. Purchases are linked to your Apple ID. Change the Media & Purchases account in Settings, then return to StoryTrail and restore purchases.",
        ),
        HelpArticle(
            title: "How to Switch to Another Tour",
            detail:
                "Leave the current tour with the back control, open the Tours tab, and choose another walk. Your saved tours and completed-stop progress remain available.",
        ),
        HelpArticle(
            title: "My Download isn't Working",
            detail:
                "Bundled tour stories do not need a separate download. If content is missing, restore purchases and reopen the app. Map detail can require a connection; contact support if bundled audio still does not play.",
        ),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                TrailPageHeader(
                    eyebrow: "Help center",
                    title: "Good to know.",
                    subtitle: "Straight answers for the moments before and during your walk."
                )
                Text("Office hours: Mon–Fri, 8:00 AM–5:00 PM Pacific")
                    .font(.trailBody(15))
                    .foregroundStyle(TrailColor.muted)

                ForEach(articles) { article in
                    DisclosureGroup {
                        Text(article.detail)
                            .font(.trailBody(15))
                            .foregroundStyle(TrailColor.muted)
                            .lineSpacing(3)
                            .padding(.top, 10)
                    } label: {
                        Text(article.title)
                            .font(.trailBody(17, weight: .bold))
                            .foregroundStyle(TrailColor.ink)
                    }
                    .tint(TrailColor.green)
                    .padding(.vertical, 18)
                    .overlay(alignment: .bottom) { Divider().overlay(TrailColor.line) }
                }
            }
            .padding(22)
        }
        .navigationTitle("Help Center")
        .navigationBarTitleDisplayMode(.inline)
        .creamBackground()
    }
}

private struct HelpArticle: Identifiable {
    var id: String { title }

    let title: String
    let detail: String
}

private struct ContactSupportView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                TrailPageHeader(
                    eyebrow: "Contact us",
                    title: "We're here to help.",
                    subtitle: "Choose the way that works best for you."
                )
                Text("Office hours: Mon–Fri, 8:00 AM–5:00 PM Pacific")
                    .font(.trailBody(15))
                    .foregroundStyle(TrailColor.muted)
                    .multilineTextAlignment(.center)

                if let phoneURL = URL(string: "tel:+12508808459") {
                    Link(destination: phoneURL) {
                        SupportActionCard(
                            icon: "phone.fill",
                            title: "Call",
                            detail: "1-250-880-8459",
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens the Phone app")
                }

                if let emailURL = URL(string: "mailto:juliancharlesbaker@gmail.com") {
                    Link(destination: emailURL) {
                        SupportActionCard(
                            icon: "envelope.fill",
                            title: "Email",
                            detail: "juliancharlesbaker@gmail.com",
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens your email app")
                }
            }
            .padding(22)
        }
        .navigationTitle("Contact Support")
        .navigationBarTitleDisplayMode(.inline)
        .creamBackground()
    }
}

private struct SupportActionCard: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(TrailColor.green)
                .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.trailBody(17, weight: .bold))
                    .foregroundStyle(TrailColor.ink)
                Text(detail)
                    .font(.trailBody(15))
                    .foregroundStyle(TrailColor.muted)
            }
            Spacer(minLength: 0)
            Image(systemName: "arrow.up.right")
                .foregroundStyle(TrailColor.green)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) { Divider().overlay(TrailColor.line) }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

private struct LiveSupportDocumentView: View {
    let destination: SupportDestination
    let url: URL
    @EnvironmentObject private var connectivity: ConnectivityModel
    @State private var loadError: String?
    @State private var retryID = UUID()

    var body: some View {
        VStack(spacing: 0) {
            if connectivity.isOffline {
                ContentUnavailableView(
                    "Connection needed", systemImage: "wifi.slash",
                    description: Text("This current document is available online at storytrailguide.com."),
                )
            } else if let loadError {
                ContentUnavailableView {
                    Label("Couldn't open document", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(loadError)
                } actions: {
                    Button("Try again") {
                        self.loadError = nil
                        retryID = UUID()
                    }
                }
            } else {
                Label("This current document is loaded from storytrailguide.com.", systemImage: "wifi")
                    .font(.trailBody(13, weight: .semibold))
                    .foregroundStyle(TrailColor.ink)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(TrailColor.yellow.opacity(0.35))
                SupportWebView(url: url, loadError: $loadError)
                    .id(retryID)
            }
        }
        .navigationTitle(destination.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct SupportWebView: UIViewRepresentable {
    let url: URL
    @Binding var loadError: String?

    func makeCoordinator() -> Coordinator { Coordinator(loadError: $loadError) }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.allowsBackForwardNavigationGestures = true
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard webView.url != url else { return }
        webView.load(URLRequest(url: url))
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        @Binding var loadError: String?

        init(loadError: Binding<String?>) {
            _loadError = loadError
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation?, withError error: Error) {
            guard (error as? URLError)?.code != .cancelled else { return }
            loadError = "Check your connection and try again."
        }

        func webView(
            _ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation?, withError error: Error
        ) {
            guard (error as? URLError)?.code != .cancelled else { return }
            loadError = "Check your connection and try again."
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation?) {
            loadError = nil
        }
    }
}

struct SupportCard: View {
    let icon: String
    let title: String
    let detail: String
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon).font(.system(size: 20, weight: .bold)).foregroundStyle(TrailColor.green)
                .frame(width: 30, height: 30)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.trailBody(18, weight: .bold)).foregroundStyle(TrailColor.ink)
                Text(detail).font(.trailBody(15)).foregroundStyle(TrailColor.muted).lineSpacing(3)
            }
        }
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .overlay(alignment: .bottom) { Divider().overlay(TrailColor.line) }
    }
}
