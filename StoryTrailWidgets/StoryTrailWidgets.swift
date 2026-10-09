import SwiftUI
import WidgetKit

private struct WalkEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

private struct WalkProvider: TimelineProvider {
    func placeholder(in context: Context) -> WalkEntry {
        WalkEntry(date: .now, snapshot: .init(activeTour: previewTour, savedTour: previewTour))
    }

    func getSnapshot(in context: Context, completion: @escaping (WalkEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WalkEntry>) -> Void) {
        completion(Timeline(entries: [currentEntry()], policy: .never))
    }

    private func currentEntry() -> WalkEntry {
        WalkEntry(
            date: .now,
            snapshot: WidgetSnapshotStore.load() ?? .init(activeTour: nil, savedTour: nil)
        )
    }

    private var previewTour: WidgetTour {
        WidgetTour(
            id: "inner-harbour", title: "Inner Harbour", subtitle: "Victoria's postcard icons",
            minutes: 50, visitedCount: 2, stopCount: 8, nextStopTitle: "Causeway Promenade"
        )
    }
}

private enum WalkKind {
    case continueWalk
    case savedWalk

    var heading: String { self == .continueWalk ? "CONTINUE WALK" : "SAVED WALK" }
    var symbol: String { self == .continueWalk ? "figure.walk" : "bookmark.fill" }
    var emptyTitle: String { self == .continueWalk ? "Your next walk starts here" : "Save a walk for later" }
    var emptyDetail: String {
        self == .continueWalk ? "Open a tour to see your progress." : "Bookmark a tour in StoryTrail."
    }
}

private struct WalkWidgetView: View {
    let entry: WalkEntry
    let kind: WalkKind
    @Environment(\.widgetFamily) private var family

    private var tour: WidgetTour? {
        kind == .continueWalk ? entry.snapshot.activeTour : entry.snapshot.savedTour
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(kind.heading, systemImage: kind.symbol)
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .tracking(1)
                .foregroundStyle(Color(red: 0.10, green: 0.42, blue: 0.30))

            if let tour {
                content(for: tour)
            } else {
                Spacer(minLength: 0)
                Text(kind.emptyTitle)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.8)
                Text(kind.emptyDetail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding()
        .containerBackground(for: .widget) { Color(red: 1, green: 0.98, blue: 0.94) }
        .widgetURL(tour.flatMap { WidgetTourLink.url(for: $0.id) })
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func content(for tour: WidgetTour) -> some View {
        Text(tour.title)
            .font(.system(size: family == .systemSmall ? 21 : 26, weight: .heavy, design: .rounded))
            .foregroundStyle(Color(red: 0.14, green: 0.10, blue: 0.08))
            .lineLimit(2)
            .minimumScaleFactor(0.8)

        if kind == .continueWalk {
            Text("\(tour.visitedCount) of \(tour.stopCount) stops visited")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .privacySensitive()
            ProgressView(value: Double(tour.visitedCount), total: Double(max(tour.stopCount, 1)))
                .tint(Color(red: 0.10, green: 0.42, blue: 0.30))
                .privacySensitive()
            if family == .systemMedium {
                Text(tour.nextStopTitle.map { "Next: \($0)" } ?? "Walk complete · revisit any stop")
                    .font(.subheadline)
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
                    .privacySensitive()
            }
        } else {
            Text("\(tour.minutes) min · \(tour.stopCount) stops")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            if family == .systemMedium {
                Text(tour.subtitle)
                    .font(.subheadline)
                    .lineLimit(2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct ContinueWalkWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ContinueWalk", provider: WalkProvider()) { entry in
            WalkWidgetView(entry: entry, kind: .continueWalk)
        }
        .configurationDisplayName("Continue Walk")
        .description("See your visited stops and the next story in your walk.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct SavedWalkWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SavedWalk", provider: WalkProvider()) { entry in
            WalkWidgetView(entry: entry, kind: .savedWalk)
        }
        .configurationDisplayName("Saved Walk")
        .description("Keep a bookmarked Victoria walk close at hand.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct StoryTrailWidgetBundle: WidgetBundle {
    var body: some Widget {
        ContinueWalkWidget()
        SavedWalkWidget()
    }
}
