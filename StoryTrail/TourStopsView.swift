import SwiftUI

struct TourStopsView: View {
    let tour: Tour
    @EnvironmentObject private var player: AudioPlayerModel

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    TrailPageHeader(
                        eyebrow: "\(tour.title) · field notes",
                        title: "A story at every stop.",
                        subtitle: "Follow the route in order, or open any story and read at your own pace."
                    )
                }
                .padding(.bottom, 20)

                ForEach(Array(tour.stops.enumerated()), id: \.element.id) { index, stop in
                    NavigationLink {
                        StopTranscriptView(tour: tour, stop: stop)
                    } label: {
                        StopCard(
                            stop: stop,
                            isCurrent: player.currentStop?.id == stop.id,
                            isVisited: TourProgress.visitedStopIDs(for: tour.id).contains(stop.id),
                            isLast: index == tour.stops.count - 1,
                        )
                    }
                    .buttonStyle(TrailPressStyle())
                }
            }
            .padding(20)
        }
        .navigationTitle("Tour Stops")
        .navigationBarTitleDisplayMode(.inline)
        .creamBackground()
    }
}

struct StopCard: View {
    let stop: TourStop
    let isCurrent: Bool
    let isVisited: Bool
    let isLast: Bool
    @ScaledMetric(relativeTo: .footnote) private var numberDiameter = 38.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 3) {
                Group {
                    if isVisited && !isCurrent {
                        Image(systemName: "checkmark")
                    } else {
                        Text("\(stop.number)")
                    }
                }
                .font(.trailBody(14, weight: .bold))
                .foregroundStyle(isCurrent ? TrailColor.ink : TrailColor.green)
                .frame(width: numberDiameter, height: numberDiameter)
                .background(isCurrent ? TrailColor.coral : TrailColor.paper, in: Circle())
                .overlay(Circle().stroke(TrailColor.green, lineWidth: isCurrent ? 0 : 2))

            }

            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    TrailEyebrow(text: isCurrent ? "Now playing" : "Stop \(stop.number)")
                    Spacer()
                    if isCurrent {
                        Image(systemName: "speaker.wave.2.fill")
                            .foregroundStyle(TrailColor.coral)
                            .accessibilityLabel("Now playing")
                    }
                }
                Text(stop.title)
                    .font(.trailTitle(20))
                    .foregroundStyle(TrailColor.ink)
                if !dynamicTypeSize.isAccessibilitySize {
                    Text(stop.summary)
                        .font(.trailBody(14))
                        .foregroundStyle(TrailColor.muted)
                        .lineLimit(3)
                }
            }
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .bottom) {
                if !isLast { Divider().overlay(TrailColor.line) }
            }
        }
        .padding(.bottom, isLast ? 0 : 12)
        .background(alignment: .topLeading) {
            if !isLast {
                GeometryReader { geometry in
                    Rectangle()
                        .fill(TrailColor.green.opacity(0.28))
                        .frame(width: 2, height: max(0, geometry.size.height - numberDiameter))
                        .offset(x: numberDiameter / 2 - 1, y: numberDiameter)
                }
                .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens story transcript")
        .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.8), value: isCurrent)
    }
}

struct StopTranscriptView: View {
    let tour: Tour
    let stop: TourStop
    @EnvironmentObject private var player: AudioPlayerModel
    @State private var playbackHapticTrigger = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                TrailEyebrow(text: "Stop \(stop.number) of \(tour.stops.count)")
                Text(stop.title).font(.trailTitle(32)).foregroundStyle(TrailColor.ink)
                LookUpCard(stop: stop)
                TrailEyebrow(text: "The story", color: TrailColor.muted)
                Text(stop.transcript)
                    .font(.trailBody(18))
                    .foregroundStyle(TrailColor.ink)
                    .lineSpacing(7)
                Button {
                    playbackHapticTrigger += 1
                    player.load(tour: tour, stop: stop, autoplay: true)
                } label: {
                    Label("Play this stop", systemImage: "play.fill")
                        .font(.trailBody(17, weight: .bold))
                        .foregroundStyle(TrailColor.ink)
                        .frame(maxWidth: .infinity).padding(18)
                        .background(TrailColor.action, in: RoundedRectangle(cornerRadius: TrailShape.button))
                }
                .buttonStyle(TrailPressStyle())
                .sensoryFeedback(.impact(weight: .light), trigger: playbackHapticTrigger)
            }
            .padding(22)
        }
        .navigationTitle("Transcript")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if player.currentTour?.id == tour.id, player.currentStop?.id == stop.id {
                CompactStopPlayer(tour: tour, stop: stop)
            }
        }
        .creamBackground()
    }
}

struct CompactStopPlayer: View {
    let tour: Tour
    let stop: TourStop
    @EnvironmentObject private var player: AudioPlayerModel
    @State private var playbackHapticTrigger = 0

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("STOP \(stop.number)")
                        .font(.trailBody(12, weight: .bold))
                        .foregroundStyle(TrailColor.muted)
                    Text(stop.title)
                        .font(.trailBody(16, weight: .bold))
                        .foregroundStyle(TrailColor.ink)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                Button(action: togglePlayback) {
                    Group {
                        if player.isLoading {
                            ProgressView().tint(TrailColor.ink)
                        } else {
                            Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 19, weight: .bold))
                        }
                    }
                    .frame(width: 48, height: 48)
                    .background(TrailColor.coral, in: Circle())
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.impact(weight: .light), trigger: playbackHapticTrigger)
                .disabled(player.isLoading)
                .accessibilityLabel(player.isPlaying ? "Pause audio" : "Play audio")
            }

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

            if let error = player.lastError {
                HStack(spacing: 8) {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.trailBody(12, weight: .semibold))
                        .foregroundStyle(TrailColor.muted)
                        .lineLimit(2)
                    Spacer(minLength: 4)
                    Button("Retry") { player.load(tour: tour, stop: stop, autoplay: true) }
                        .font(.trailBody(13, weight: .bold))
                        .foregroundStyle(TrailColor.green)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) { Divider() }
    }

    private func togglePlayback() {
        playbackHapticTrigger += 1
        if player.hasFinished {
            player.seek(to: 0)
        }
        player.toggle()
    }
}
