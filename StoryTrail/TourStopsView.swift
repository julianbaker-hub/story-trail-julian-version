import SwiftUI

struct TourStopsView: View {
    let tour: Tour

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                TrailPageHeader(
                    eyebrow: tour.title,
                    title: "A story at every stop.",
                    subtitle: "Tour stop summaries, images and useful links."
                )
                .padding(.bottom, 20)

                ForEach(Array(tour.stops.enumerated()), id: \.element.id) { index, stop in
                    StopDetailSection(
                        stop: stop,
                        isLast: index == tour.stops.count - 1
                    )
                }
            }
            .padding(20)
        }
        .navigationTitle("Tour Stop Details")
        .navigationBarTitleDisplayMode(.inline)
        .creamBackground()
    }
}

struct StopDetailSection: View {
    let stop: TourStop
    let isLast: Bool
    @ScaledMetric(relativeTo: .footnote) private var numberDiameter = 38.0

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text("\(stop.number)")
                .font(.trailBody(14, weight: .bold))
                .foregroundStyle(TrailColor.green)
                .frame(width: numberDiameter, height: numberDiameter)
                .background(TrailColor.paper, in: Circle())
                .overlay(Circle().stroke(TrailColor.green, lineWidth: 2))

            VStack(alignment: .leading, spacing: 7) {
                TrailEyebrow(text: "Stop \(stop.number)")
                Text(stop.title)
                    .font(.trailTitle(20))
                    .foregroundStyle(TrailColor.ink)
                Text(stop.transcript.isEmpty ? stop.summary : stop.transcript)
                    .font(.trailBody(17))
                    .foregroundStyle(TrailColor.muted)
                    .lineSpacing(5)
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
    }
}
