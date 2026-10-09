import SwiftUI
import UIKit

enum TrailShape {
    static let card: CGFloat = 24
    static let button: CGFloat = 18
}

enum TrailColor {
    static let cream = adaptive(light: 0xF7F4EB, dark: 0x171E1C)
    static let paper = adaptive(light: 0xFFFDF7, dark: 0x222D2A)
    static let ink = adaptive(light: 0x1C2925, dark: 0xF4F5EB)
    static let muted = adaptive(light: 0x53645D, dark: 0xB9C9BF, highLight: 0x253A33, highDark: 0xFFFFFF)
    static let coral = adaptive(light: 0xF56B50, dark: 0xD55D48)
    static let green = adaptive(light: 0x0E6658, dark: 0x8BD9C6, highLight: 0x06473D, highDark: 0xC8FFF0)
    static let action = adaptive(light: 0x0B594D, dark: 0x155D52)
    static let unavailableAction = adaptive(light: 0x52615B, dark: 0x394D46)
    static let yellow = adaptive(light: 0xF4C261, dark: 0x6A4D20)
    static let sky = adaptive(light: 0xB9DFE1, dark: 0x23474A)
    static let line = adaptive(light: 0xD7DDD1, dark: 0x53645B, highLight: 0x73857B, highDark: 0xDDE9E0)

    private static func adaptive(light: UInt32, dark: UInt32, highLight: UInt32? = nil, highDark: UInt32? = nil)
        -> Color
    {
        Color(
            uiColor: UIColor { traits in
                let increased = traits.accessibilityContrast == .high
                let hex =
                    traits.userInterfaceStyle == .dark
                    ? (increased ? highDark ?? dark : dark)
                    : (increased ? highLight ?? light : light)
                return UIColor(
                    red: CGFloat((hex >> 16) & 255) / 255,
                    green: CGFloat((hex >> 8) & 255) / 255,
                    blue: CGFloat(hex & 255) / 255, alpha: 1
                )
            })
    }
}

extension Font {
    static func trailTitle(_ size: CGFloat) -> Font {
        let style: Font.TextStyle = size >= 32 ? .largeTitle : size >= 25 ? .title : .title2
        return .system(style, design: .rounded, weight: .heavy)
    }

    static func trailBody(_ size: CGFloat, weight: Weight = .regular) -> Font {
        let style: Font.TextStyle
        switch size {
        case ..<13: style = .caption
        case ..<15: style = .footnote
        case ..<17: style = .subheadline
        case ..<19: style = .body
        default: style = .title3
        }
        return .system(style, design: .rounded, weight: weight)
    }
}

struct CreamBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(TrailColor.cream.ignoresSafeArea())
            .tint(TrailColor.ink)
    }
}

extension View {
    func creamBackground() -> some View { modifier(CreamBackground()) }
}

struct TrailPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.975 : 1)
            .opacity(configuration.isPressed ? 0.86 : 1)
            .animation(
                reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.72), value: configuration.isPressed)
    }
}

struct TrailPageHeader: View {
    let eyebrow: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TrailEyebrow(text: eyebrow)
            Text(title)
                .font(.trailTitle(34))
                .foregroundStyle(TrailColor.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(subtitle)
                .font(.trailBody(16))
                .foregroundStyle(TrailColor.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

func playbackTime(_ seconds: Double) -> String {
    guard seconds.isFinite, seconds >= 0 else { return "0:00" }
    let totalSeconds = Int(seconds.rounded(.down))
    return String(format: "%d:%02d", totalSeconds / 60, totalSeconds % 60)
}

struct RoundIconButton: View {
    let systemName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(TrailColor.ink)
                .frame(width: 50, height: 50)
                .background(TrailColor.paper, in: Circle())
                .overlay(Circle().stroke(TrailColor.line.opacity(0.7)))
        }
        .buttonStyle(.plain)
    }
}

struct TrailEyebrow: View {
    let text: String
    var color = TrailColor.green

    var body: some View {
        Text(text.uppercased())
            .font(.trailBody(12, weight: .bold))
            .tracking(2.1)
            .foregroundStyle(color)
    }
}

struct TourMetadata: View {
    let tour: Tour
    var foregroundStyle = TrailColor.ink

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 14) { items }
            VStack(alignment: .leading, spacing: 8) { items }
        }
        .foregroundStyle(foregroundStyle)
    }

    private var items: some View {
        Group {
            item(icon: "clock", text: "\(tour.minutes) min")
            item(
                icon: "point.topleft.down.to.point.bottomright.curvepath",
                text: String(format: "%.1f km", tour.distance))
            item(icon: "mappin", text: "\(tour.stops.count) stops")
        }
    }

    private func item(icon: String, text: String) -> some View {
        Label(text, systemImage: icon)
            .font(.trailBody(13, weight: .semibold))
            .labelStyle(.titleAndIcon)
    }
}

struct LookUpCard: View {
    let stop: TourStop

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "binoculars.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(TrailColor.ink)
                .frame(width: 38, height: 38)
                .background(TrailColor.yellow, in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                TrailEyebrow(text: "Look up", color: TrailColor.ink)
                Text(lookUpPrompt(for: stop))
                    .font(.trailBody(14, weight: .semibold))
                    .foregroundStyle(TrailColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(TrailColor.yellow.opacity(0.22), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

func lookUpPrompt(for stop: TourStop) -> String {
    "Pause here and notice the details around \(stop.title)."
}
