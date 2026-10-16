import MapKit
import SwiftUI
import WebKit

struct MyBagView: View {
    let onExplore: () -> Void
    @EnvironmentObject private var library: TourLibrary
    @EnvironmentObject private var purchaseStore: PurchaseStore
    @State private var tourCardHapticTrigger = 0

    private var purchasedTours: [Tour] {
        let purchasedProductIDs = purchaseStore.purchasedProductIDs
        if purchasedProductIDs.contains(PurchaseConfiguration.allToursProductID) {
            return library.tours
        }
        return library.tours.filter { tour in
            guard let productID = PurchaseConfiguration.productID(for: tour.id) else { return false }
            return purchasedProductIDs.contains(productID)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                BrandMark()
                TrailPageHeader(
                    eyebrow: "Your collection",
                    title: "Tours worth keeping.",
                    subtitle:
                        "Once you purchase a tour its yours forever. Access it on location or listen to individual tour stops whenever you like"
                )
                if purchasedTours.isEmpty {
                    emptyState
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(purchasedTours) { tour in
                            NavigationLink(value: tour) { CompactTourCard(tour: tour, accessLabel: "PURCHASED") }
                                .buttonStyle(TrailPressStyle())
                                .simultaneousGesture(TapGesture().onEnded { tourCardHapticTrigger += 1 })
                        }
                    }
                }
            }
            .padding(22)
        }
        .navigationDestination(for: Tour.self) { TourDetailView(tour: $0) }
        .sensoryFeedback(.impact(weight: .light), trigger: tourCardHapticTrigger)
        .toolbar(.hidden, for: .navigationBar)
        .creamBackground()
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: "cart.fill")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(TrailColor.green)
                .frame(width: 60, height: 60)
                .background(TrailColor.sky.opacity(0.45), in: Circle())
            Text("No tours purchased yet")
                .font(.trailTitle(24))
                .foregroundStyle(TrailColor.ink)
            Button(action: onExplore) {
                Label("Explore tours", systemImage: "arrow.right")
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
                    if let coordinate = tour.mapPinCoordinate {
                        Annotation("", coordinate: coordinate, anchor: .bottom) {
                            TourMapPin(
                                title: mapPinTitle(for: tour),
                                isSelected: selectedTour?.id == tour.id,
                                reduceMotion: reduceMotion
                            )
                        }
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
                    Label("Tap a pin to preview a tour", systemImage: "hand.tap")
                        .foregroundStyle(TrailColor.ink)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(TrailColor.coral, in: Capsule())
                        .overlay { Capsule().stroke(TrailColor.cream, lineWidth: 2) }
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
                            TrailEyebrow(text: previewPrice(for: selectedTour))
                            Text(previewTitle(for: selectedTour))
                                .font(.trailBody(19, weight: .bold))
                                .foregroundStyle(TrailColor.ink)
                            Text(previewMetadata(for: selectedTour))
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
        .navigationTitle("Tours on the map")
        .navigationBarTitleDisplayMode(.inline)
        .animation(reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.82), value: selectedTour?.id)
        .sensoryFeedback(.selection, trigger: selectedTour?.id)
    }

    private func mapPinTitle(for tour: Tour) -> String {
        switch tour.id {
        case "inner-harbour":
            "Victoria Inner Harbour Tour"
        case "old-town":
            "Victoria Old Town Tour"
        case "james-bay":
            "James Bay Tour"
        case "beacon-hill":
            "Beacon Hill Park Tour"
        default:
            tour.title
        }
    }

    private func previewPrice(for tour: Tour) -> String {
        switch tour.id {
        case "inner-harbour", "old-town", "james-bay", "beacon-hill":
            "$10"
        default:
            purchaseStore.accessLabel(for: tour)
        }
    }

    private func previewTitle(for tour: Tour) -> String {
        switch tour.id {
        case "inner-harbour":
            "Victoria Inner Harbour"
        case "old-town":
            "Victoria Old Town"
        default:
            tour.title
        }
    }

    private func previewMetadata(for tour: Tour) -> String {
        switch tour.id {
        case "inner-harbour":
            "\(tour.minutes) min · 8 stops"
        case "old-town":
            "60 min · 10 stops"
        case "james-bay":
            "90 min · 10 stops"
        case "beacon-hill":
            "75 min · 10 stops"
        default:
            "\(tour.minutes) min · \(tour.stops.count) stops"
        }
    }
}

private struct TourMapPin: View {
    let title: String
    let isSelected: Bool
    let reduceMotion: Bool

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(TrailColor.coral)
                Circle()
                    .stroke(TrailColor.cream, lineWidth: 2)
                Image(systemName: "mappin")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(TrailColor.ink)
            }
            .frame(width: 36, height: 36)
            .keyframeAnimator(initialValue: 0.0, trigger: isSelected) { content, horizontalOffset in
                content.offset(x: isSelected && !reduceMotion ? horizontalOffset : 0)
            } keyframes: { _ in
                LinearKeyframe(-4, duration: 0.06)
                LinearKeyframe(4, duration: 0.08)
                LinearKeyframe(-3, duration: 0.08)
                LinearKeyframe(3, duration: 0.08)
                LinearKeyframe(0, duration: 0.06)
            }
            Text(title)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(TrailColor.ink)
        }
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
        case .privacyPolicy:
            PrivacyPolicyView()
        case .termsOfService:
            if let url = destination.liveDocumentURL {
                LiveSupportDocumentView(destination: destination, url: url)
            } else {
                ContentUnavailableView("Document unavailable", systemImage: "doc.text.magnifyingglass")
            }
        }
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
        case .helpCenter, .contactSupport, .privacyPolicy:
            nil
        }
    }
}

private struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("StoryTrail")
                        .font(.trailBody(17, weight: .bold))
                        .foregroundStyle(TrailColor.green)
                        .textCase(.uppercase)
                    Text("Privacy Policy")
                        .font(.trailTitle(36))
                        .foregroundStyle(TrailColor.ink)
                    Text("Last Updated: October 16, 2026")
                        .font(.trailBody(17, weight: .semibold))
                        .foregroundStyle(TrailColor.muted)
                }

                ForEach(Self.introduction, id: \.self) { paragraph in
                    policyText(paragraph)
                }

                ForEach(Self.sections) { section in
                    VStack(alignment: .leading, spacing: 14) {
                        Text(section.title)
                            .font(.trailTitle(24))
                            .foregroundStyle(TrailColor.ink)
                            .accessibilityAddTraits(.isHeader)
                        ForEach(section.content, id: \.self) { paragraph in
                            policyText(paragraph)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("© 2026 StoryTrail. All rights reserved.")
                        .font(.trailBody(17, weight: .semibold))
                        .foregroundStyle(TrailColor.muted)
                }
                .padding(.top, 8)
            }
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
        .textSelection(.enabled)
        .creamBackground()
    }

    private func policyText(_ text: String) -> some View {
        Text(text)
            .font(.trailBody(17))
            .foregroundStyle(TrailColor.ink)
            .lineSpacing(5)
            .fixedSize(horizontal: false, vertical: true)
    }

    private static let introduction = [
        "StoryTrail (\"StoryTrail\", \"we\", \"us\", or \"our\") respects your privacy and is committed to protecting your personal information.",
        "StoryTrail is a registered business operating in Victoria, British Columbia, Canada, owned and operated by Julian Baker.",
        "This Privacy Policy explains how we collect, use, disclose, retain, and protect personal information when you access or use the StoryTrail mobile application, our website at www.storytrailguide.com, our downloadable audio tours, and related services (collectively, the \"Services\").",
        "StoryTrail is designed to minimize the collection of personal information. In particular, GPS location processing used to deliver audio tours takes place primarily on your device, and StoryTrail does not maintain a record of your individual movements.",
        "This Privacy Policy explains our personal information practices and the choices available to you. Where required by applicable law, we obtain your consent before collecting, using, or disclosing personal information for specific purposes.",
    ]

    private static let sections = [
        PrivacyPolicySection(
            title: "1. Applicable Privacy Laws",
            content: [
                "StoryTrail operates in British Columbia, Canada, and handles personal information in accordance with applicable privacy legislation, including:",
                "• The Personal Information Protection Act (British Columbia) (\"BC PIPA\").\n• The Personal Information Protection and Electronic Documents Act (\"PIPEDA\"), where applicable.\n• Other applicable Canadian privacy and consumer protection laws.",
                "Where privacy laws of other jurisdictions apply to our activities, we will comply with their applicable requirements.",
                "International users may have additional privacy rights under the laws of their jurisdiction.",
            ]
        ),
        PrivacyPolicySection(
            title: "2. Information We Collect",
            content: [
                "StoryTrail collects and processes only the information reasonably necessary to operate its Services, fulfill purchases, respond to support requests, and maintain app functionality.",
                "2.1 Information You Provide Voluntarily",
                "StoryTrail does not currently require users to create an account or register to use the mobile application.",
                "We do not automatically collect your name, email address, account credentials, or billing address through the app.",
                "If you voluntarily contact us by email or through a support channel, we may receive:\n\n• Your name, if provided.\n• Your email address.\n• The contents of your message.\n• Attachments or other information you choose to provide.",
                "We use this information to respond to inquiries, provide customer support, investigate reported problems, and maintain appropriate records of communications.",
                "2.2 Location Information",
                "StoryTrail provides GPS-enabled audio tours that use your device's location to identify nearby tour stops, display your position on a map, and automatically trigger audio narration.",
                "With your permission, StoryTrail accesses location information through Apple's Core Location framework.",
                "GPS coordinates are processed locally on your device. StoryTrail does not receive or store your individual GPS coordinates on its servers or maintain a history of your movements.",
                "During an active tour, location processing may continue while the app is running in the background or your device is locked, subject to your device settings and permissions.",
                "StoryTrail may record local diagnostic information relating to location functionality, including GPS accuracy, distance to nearby tour stops, location-trigger events, and location-related errors. These diagnostic logs do not contain your precise latitude or longitude.",
                "StoryTrail uses Apple's MapKit and Maps services. Apple may process location-related information, including map requests and route information, according to Apple's own privacy practices.",
                "For additional information, please see:\n\nApple Maps & Privacy: https://www.apple.com/legal/privacy/data/en/apple-maps/\n\nApple Location Services & Privacy: https://www.apple.com/legal/privacy/data/en/location-services/",
                "2.3 Location Permissions and User Control",
                "StoryTrail requests location access through Apple's iOS permission system.",
                "You may allow or deny location access and modify your permissions at any time through your device's Settings.",
                "Disabling location access may prevent automatic GPS-triggered narration, position display, and other location-dependent features from functioning correctly.",
                "StoryTrail does not use location information for advertising, profiling, or the creation of individual movement histories.",
                "2.4 Purchases and Payment Information",
                "Purchases made through the StoryTrail iOS application are processed through Apple's App Store and in-app purchase system.",
                "Apple manages payment authorization, payment methods, billing information, taxes, and related transaction processing.",
                "StoryTrail does not receive or store your full credit card number, banking information, Apple Account password, or payment-card details.",
                "The application uses Apple's StoreKit framework to verify purchases and determine access to purchased tours.",
                "Information used for this purpose includes:\n\n• Purchased tour product identifiers.\n• Purchase verification status.\n• Current purchase entitlement status.\n• Purchase revocation status, where applicable.",
                "Purchased product identifiers may be stored locally on your device to maintain access to purchased content.",
                "StoryTrail does not currently transmit individual purchase transaction records to a StoryTrail-operated server.",
                "As the app developer, StoryTrail may receive aggregated sales, financial, and transaction reporting through App Store Connect, including information about products sold, transaction dates, sales territories, refunds, and revenue.",
                "Apple's processing of payment information is governed by Apple's applicable privacy policies and payment terms.",
                "2.5 Technical and Diagnostic Information",
                "StoryTrail uses technical information to operate and troubleshoot the application.",
                "The app may generate local diagnostic records relating to:\n\n• GPS accuracy and location-trigger functionality.\n• Distance to designated tour stops.\n• Audio playback errors.\n• Location service errors.\n• Other application performance or functionality issues.",
                "These diagnostic records are maintained through Apple's device logging mechanisms.",
                "StoryTrail does not currently operate its own system for automatically uploading these logs to a remote analytics or diagnostic server.",
                "Apple may separately collect and make available crash reports, performance information, and App Store analytics in accordance with Apple's privacy practices and applicable device settings.",
                "2.6 Analytics and Advertising",
                "StoryTrail does not currently integrate third-party advertising, behavioural analytics, or cross-app tracking SDKs into its iOS application.",
                "We do not use advertising identifiers to track users across other companies' applications or websites.",
                "We do not sell personal information to advertisers or data brokers.",
                "If we introduce additional analytics, advertising, or tracking technologies in the future, we will update this Privacy Policy and obtain any consent required by applicable law before implementing those practices.",
            ]
        ),
        PrivacyPolicySection(
            title: "3. How We Use Information",
            content: [
                "StoryTrail uses personal information and locally processed technical information for the following purposes:",
                "• Delivering GPS-triggered audio tours.\n• Displaying maps and tour routes.\n• Providing access to purchased content.\n• Maintaining tour progress and application preferences.\n• Responding to customer support inquiries.\n• Diagnosing technical problems and improving app reliability.\n• Preventing misuse or unauthorized access.\n• Complying with applicable legal and regulatory obligations.",
                "We do not use personal information for purposes unrelated to those described in this policy without an appropriate legal basis or consent where required.",
            ]
        ),
        PrivacyPolicySection(
            title: "4. Consent",
            content: [
                "Where required by applicable law, StoryTrail obtains meaningful consent for the collection, use, or disclosure of personal information.",
                "Location access is requested through Apple's operating-system permission controls.",
                "Users may withdraw location permission at any time through their device settings.",
                "Users may also contact StoryTrail to withdraw consent for other activities where withdrawal is legally available.",
                "Withdrawal of consent may affect our ability to provide certain features or respond to particular requests.",
                "We will explain relevant consequences where appropriate.",
            ]
        ),
        PrivacyPolicySection(
            title: "5. Sharing and Disclosure of Information",
            content: [
                "StoryTrail does not sell personal information.",
                "We may disclose limited information in the following circumstances.",
                "5.1 Apple Services",
                "StoryTrail relies on Apple technologies, including Core Location, MapKit, Maps, StoreKit, and App Store services.",
                "Apple may process information necessary to provide mapping, location, purchase, and platform functionality under its own privacy policies.",
                "5.2 Service Providers",
                "We may use service providers for website hosting, email communications, technical infrastructure, or other necessary business functions.",
                "Such providers may process information required to deliver their services, including ordinary connection information or information voluntarily submitted through support communications.",
                "Where service providers process personal information on our behalf, we take reasonable steps to ensure appropriate privacy and security protections.",
                "5.3 Legal Requirements",
                "We may disclose personal information where required or permitted by applicable law, including in response to valid legal processes or lawful requests from competent authorities.",
                "5.4 Business Transfers",
                "If StoryTrail is sold, transferred, reorganized, or otherwise undergoes a business transaction, personal information may be disclosed or transferred where permitted by applicable law and subject to appropriate safeguards.",
            ]
        ),
        PrivacyPolicySection(
            title: "6. Data Storage and International Processing",
            content: [
                "StoryTrail is operated from British Columbia, Canada.",
                "The mobile application processes GPS coordinates locally and does not maintain a server-based history of users' movements.",
                "Local app preferences, tour progress, and purchase entitlement information may be stored on your device.",
                "Other information, including support emails, website connection information, and information handled by Apple or service providers, may be stored or processed in Canada or other jurisdictions.",
                "Information processed outside Canada may be subject to the laws of the jurisdiction where it is processed, including lawful access requests by public authorities.",
                "We take reasonable steps to protect personal information under our control, including when service providers are involved.",
            ]
        ),
        PrivacyPolicySection(
            title: "7. Data Retention",
            content: [
                "StoryTrail retains personal information only for as long as reasonably necessary to fulfill the purposes for which it was collected, or as required or permitted by law.",
                "Our retention practices include:",
                "• Location data: GPS coordinates are processed locally for tour functionality and are not retained by StoryTrail as a location history.\n• Tour progress and preferences: Stored locally on your device until removed or reset through applicable device or app functions.\n• Purchase information: Locally cached entitlement information may remain on your device while the app is installed. Apple maintains its own transaction records according to its policies.\n• Support communications: Retained for as long as reasonably necessary to resolve inquiries, maintain appropriate business records, and meet legal obligations.\n• Diagnostic information: Local diagnostic logs are subject to the device's logging and retention mechanisms.\n• Financial and business records: Retained for periods required by applicable tax, accounting, and other laws.",
                "When personal information under our control is no longer required, we take reasonable steps to securely delete, destroy, or anonymize it, as appropriate.",
            ]
        ),
        PrivacyPolicySection(
            title: "8. Your Privacy Rights",
            content: [
                "Depending on applicable law, you may have the right to:",
                "• Request access to personal information held by StoryTrail.\n• Request correction of inaccurate or incomplete information.\n• Withdraw consent to certain uses of personal information.\n• Request deletion of personal information where legally permitted.\n• Ask questions or raise concerns about our privacy practices.",
                "To exercise these rights, please contact StoryTrail using the information provided at the end of this policy.",
                "We may request information reasonably necessary to verify your identity before responding to a privacy request.",
                "We will respond within the time limits established by applicable law. Under BC PIPA, the ordinary response period for a qualifying written access or correction request is 30 days, subject to permitted extensions and exceptions.",
                "Because StoryTrail does not maintain individual GPS histories or user accounts, we may not possess certain information that a user requests.",
            ]
        ),
        PrivacyPolicySection(
            title: "9. Account and Local Data Deletion",
            content: [
                "StoryTrail does not currently require or maintain individual user accounts.",
                "Accordingly, there is no StoryTrail account that users must delete to stop using the Services.",
                "Uninstalling the app ordinarily removes its locally stored application data, subject to applicable device backup and operating-system behaviour.",
                "Deleting the application does not automatically delete purchase records maintained by Apple.",
                "Users may contact StoryTrail to request deletion of personal information under our control, subject to applicable legal retention requirements.",
            ]
        ),
        PrivacyPolicySection(
            title: "10. Children's Privacy",
            content: [
                "StoryTrail provides educational and tourism content intended for general audiences, including families.",
                "The application is not specifically directed at children under 13 and does not currently require users to provide personal information to access its basic functionality.",
                "We do not knowingly collect personal information directly from children for advertising, profiling, or behavioural tracking.",
                "Where parental or guardian consent is required by applicable law, we will obtain that consent before collecting or using a child's personal information for the relevant purpose.",
                "Parents or guardians who believe a child has provided personal information to StoryTrail may contact us to request its review or deletion, where legally permitted.",
            ]
        ),
        PrivacyPolicySection(
            title: "11. Information Security",
            content: [
                "StoryTrail implements reasonable administrative, technical, and organizational safeguards appropriate to the nature and sensitivity of personal information under our control.",
                "These safeguards are intended to protect information against unauthorized access, disclosure, loss, misuse, or alteration.",
                "Our privacy-conscious app design reduces the amount of personal information transmitted or stored remotely.",
                "However, no electronic system, device, or communication method can be guaranteed to be completely secure.",
                "Users are encouraged to maintain appropriate device security, including operating-system updates and device access protections.",
            ]
        ),
        PrivacyPolicySection(
            title: "12. Privacy Incidents and Data Breaches",
            content: [
                "If StoryTrail becomes aware of a suspected or confirmed privacy or security incident involving personal information under our control, we will take reasonable steps to investigate, contain, assess, and remediate the incident.",
                "Where required by applicable law, we will notify affected individuals, privacy regulators, or other appropriate authorities.",
                "We will maintain records of privacy incidents where legally required.",
            ]
        ),
        PrivacyPolicySection(
            title: "13. Website Privacy and Cookies",
            content: [
                "StoryTrail operates a website at www.storytrailguide.com.",
                "When you visit the website, its hosting infrastructure may process technical information necessary to deliver website content, such as IP addresses, browser information, and request metadata.",
                "If you voluntarily contact StoryTrail through the website or an associated email link, we may receive the information you provide.",
                "Any website cookies, analytics, or other technologies that collect personal information will be subject to applicable privacy and consent requirements.",
                "The website's data-processing practices may differ from those of the native iOS application. We will provide additional notices or consent controls where required.",
            ]
        ),
        PrivacyPolicySection(
            title: "14. Third-Party Services and External Links",
            content: [
                "The Services may include links to external websites, attractions, mapping services, or other third-party resources.",
                "These services may collect and process information under their own privacy policies.",
                "StoryTrail does not control the independent privacy practices of third-party websites or services.",
                "We encourage users to review the privacy policies of third parties before providing personal information.",
            ]
        ),
        PrivacyPolicySection(
            title: "15. International Users",
            content: [
                "StoryTrail is based in Canada but may be accessed by visitors from other countries.",
                "Where international privacy legislation applies to StoryTrail's activities, we will comply with the relevant legal obligations.",
                "Depending on their location and applicable law, users may have additional rights concerning access, correction, deletion, restriction, portability, objection, or withdrawal of consent.",
                "Users may contact StoryTrail for information about exercising applicable privacy rights.",
            ]
        ),
        PrivacyPolicySection(
            title: "16. Changes to This Privacy Policy",
            content: [
                "StoryTrail may update this Privacy Policy to reflect changes in its Services, technologies, privacy practices, or applicable legal requirements.",
                "When changes are made, we will update the \"Last Updated\" date at the beginning of this document.",
                "Where changes materially affect how personal information is collected, used, or disclosed, we will provide appropriate notice and obtain additional consent where required by law.",
                "The current version will be made available through the StoryTrail application and our website.",
            ]
        ),
        PrivacyPolicySection(
            title: "17. Privacy Contact and Complaints",
            content: [
                "StoryTrail is responsible for personal information under its control.",
                "The person responsible for privacy matters is:",
                "Julian Baker\nOwner and Operator, StoryTrail\nRegistered British Columbia Business No. FM1118263\nVictoria, British Columbia, Canada",
                "Email: help@storytrail.com\nWebsite: www.storytrailguide.com",
                "You may contact us with questions, requests for access or correction, withdrawal of consent, or complaints concerning our privacy practices.",
                "We will review privacy complaints and respond in accordance with applicable law.",
                "If you are dissatisfied with our response, you may contact the Office of the Information and Privacy Commissioner for British Columbia:\n\nhttps://www.oipc.bc.ca/",
                "Where applicable, you may also contact the Office of the Privacy Commissioner of Canada:\n\nhttps://www.priv.gc.ca/",
            ]
        ),
    ]
}

private struct PrivacyPolicySection: Identifiable {
    var id: String { title }

    let title: String
    let content: [String]
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
