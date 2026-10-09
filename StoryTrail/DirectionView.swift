import MapKit
import SwiftUI

struct DirectionView: View {
    let tour: Tour
    let target: TourStop
    @ObservedObject var location: LocationModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var connectivity: ConnectivityModel

    private var distance: CLLocationDistance? { location.distance(to: target) }
    private var bearing: CLLocationDirection? { location.bearing(to: target) }
    private var relativeBearing: CLLocationDirection { location.relativeBearing(to: target) ?? bearing ?? 0 }
    private var hasArrived: Bool { (distance ?? .greatestFiniteMagnitude) <= target.triggerRadiusMeters }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [TrailColor.cream, TrailColor.sky.opacity(0.48)],
                startPoint: .top,
                endPoint: .bottom,
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    HStack {
                        RoundIconButton(systemName: "xmark") { dismiss() }
                            .accessibilityLabel("Close directions")
                        Spacer()
                        Text(tour.title)
                            .font(.trailBody(16, weight: .bold))
                            .foregroundStyle(TrailColor.ink)
                        Spacer()
                        Color.clear.frame(width: 50, height: 50)
                    }
                    .padding(.horizontal, 20)

                    Spacer(minLength: 20)

                    Text(hasArrived ? "YOU'VE ARRIVED" : "STOP \(target.number) OF \(tour.stops.count)")
                        .font(.trailBody(14, weight: .heavy))
                        .tracking(1.4)
                        .foregroundStyle(TrailColor.green)

                    Text("\(target.number). \(target.title)")
                        .font(.trailTitle(30))
                        .foregroundStyle(TrailColor.ink)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 26)
                        .padding(.top, 8)

                    Spacer(minLength: 22)

                    ZStack {
                        Circle()
                            .fill(TrailColor.paper)
                            .frame(width: 286, height: 286)
                            .shadow(color: TrailColor.ink.opacity(0.1), radius: 24, y: 10)
                        Circle()
                            .stroke(TrailColor.green.opacity(0.18), style: StrokeStyle(lineWidth: 12, dash: [3, 8]))
                            .frame(width: 236, height: 236)
                        if hasArrived {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 138, weight: .black))
                                .foregroundStyle(TrailColor.green)
                        } else if bearing != nil, location.headingDegrees != nil {
                            Image(systemName: "location.north.fill")
                                .font(.system(size: 138, weight: .black))
                                .foregroundStyle(TrailColor.coral)
                                .rotationEffect(.degrees(relativeBearing))
                                .animation(
                                    reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.78),
                                    value: relativeBearing)
                        } else if bearing != nil {
                            Image(systemName: "safari.fill")
                                .font(.system(size: 110, weight: .semibold))
                                .foregroundStyle(TrailColor.green)
                        } else {
                            Image(
                                systemName: location.authorization == .denied || location.authorization == .restricted
                                    ? "location.slash.fill" : "location.circle"
                            )
                            .font(.system(size: 92, weight: .semibold))
                            .foregroundStyle(TrailColor.muted)
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(directionAccessibilityLabel)

                    VStack(spacing: 7) {
                        Text(distance.map(NavigationMath.distanceText) ?? "Locating…")
                            .font(.trailTitle(42))
                            .foregroundStyle(TrailColor.ink)
                        if !hasArrived, let bearing {
                            Text("\(NavigationMath.cardinalDirection(for: bearing)) · \(Int(bearing.rounded()))°")
                                .font(.trailBody(17, weight: .bold))
                                .foregroundStyle(TrailColor.muted)
                        }
                        Text(instructionText)
                            .font(.trailBody(15))
                            .foregroundStyle(TrailColor.muted)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 24)

                    Text("Stay aware of crossings and your surroundings as you walk.")
                        .font(.trailBody(13, weight: .semibold))
                        .foregroundStyle(TrailColor.muted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                        .padding(.top, 14)

                    Spacer()

                    if connectivity.isOffline {
                        Label("Offline navigation active", systemImage: "location.north.circle.fill")
                            .font(.trailBody(14, weight: .bold))
                            .foregroundStyle(TrailColor.green)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(TrailColor.green.opacity(0.1), in: Capsule())
                            .padding(.bottom, 10)
                    }

                    Button {
                        if hasArrived { dismiss() } else { openInMaps() }
                    } label: {
                        Label(externalDirectionsTitle, systemImage: hasArrived ? "arrow.right" : "figure.walk")
                            .font(.trailBody(16, weight: .bold))
                            .foregroundStyle(TrailColor.ink)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 17)
                            .background(TrailColor.paper, in: RoundedRectangle(cornerRadius: TrailShape.button))
                            .overlay {
                                RoundedRectangle(cornerRadius: TrailShape.button)
                                    .stroke(TrailColor.line.opacity(0.8))
                            }
                    }
                    .padding(.horizontal, 22)
                    .padding(.bottom, 14)
                }
            }
        }
        .onAppear { location.begin(for: tour.stops) }
    }

    private var directionAccessibilityLabel: String {
        if hasArrived { return "You have arrived at \(target.title)" }
        let distanceText = distance.map(NavigationMath.distanceText) ?? "unknown distance"
        let bearingText =
            bearing.map { "\(NavigationMath.cardinalDirection(for: $0)), \(Int($0.rounded())) degrees" }
            ?? "unknown direction"
        return "\(target.title), \(distanceText), \(bearingText)"
    }

    private var instructionText: String {
        if hasArrived { return "You're at the story location — continue when you're ready" }
        if location.authorization == .denied || location.authorization == .restricted {
            return "Location is off. Enable it in Settings for live guidance, or choose stops manually."
        }
        if distance == nil { return "Finding your position…" }
        if connectivity.isOffline, location.headingDegrees != nil {
            return "GPS and compass work offline — turn until the arrow points straight ahead"
        }
        return location.headingDegrees == nil
            ? "Compass will activate on your iPhone" : "Turn until the arrow points straight ahead"
    }

    private var externalDirectionsTitle: String {
        if hasArrived { return "Continue tour" }
        return connectivity.isOffline ? "Open Maps (map detail may be unavailable)" : "Open walking directions in Maps"
    }

    private func openInMaps() {
        let destination = MKMapItem(placemark: MKPlacemark(coordinate: target.coordinate))
        destination.name = target.title
        destination.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking])
    }
}
