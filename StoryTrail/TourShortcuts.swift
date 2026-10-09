import AppIntents
import Foundation

struct TourEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Tour")
    static let defaultQuery = TourEntityQuery()

    let id: String
    let title: String
    let subtitle: String

    init(tour: Tour) {
        id = tour.id
        title = tour.title
        subtitle = tour.subtitle
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)", subtitle: "\(subtitle)")
    }
}

struct TourEntityQuery: EntityStringQuery {
    func entities(for identifiers: [TourEntity.ID]) async throws -> [TourEntity] {
        try await allTours().filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [TourEntity] {
        try await allTours()
    }

    func entities(matching string: String) async throws -> [TourEntity] {
        try await allTours().filter {
            $0.title.localizedCaseInsensitiveContains(string)
                || $0.subtitle.localizedCaseInsensitiveContains(string)
        }
    }

    private func allTours() async throws -> [TourEntity] {
        try await BundledTourRepository().fetchTours().map(TourEntity.init)
    }
}

private enum TourShortcutError: LocalizedError {
    case missingTour

    var errorDescription: String? {
        "This tour is no longer in the bundled catalogue. Choose another tour."
    }
}

private enum TourShortcutData {
    static func tour(for entity: TourEntity) async throws -> (Tour, [Tour]) {
        let tours = try await BundledTourRepository().fetchTours()
        guard let tour = tours.first(where: { $0.id == entity.id }) else {
            throw TourShortcutError.missingTour
        }
        return (tour, tours)
    }
}

struct TourVisitSummary {
    let visitedCount: Int
    let stopCount: Int

    init(tour: Tour, visitedIDs: Set<String>) {
        visitedCount = tour.stops.filter { visitedIDs.contains($0.id) }.count
        stopCount = tour.stops.count
    }
}

struct SaveTourIntent: AppIntent {
    static let title: LocalizedStringResource = "Save Tour"
    static let description = IntentDescription("Save a StoryTrail walk for later.")

    @Parameter(title: "Tour") var tour: TourEntity

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let (selected, tours) = try await TourShortcutData.tour(for: tour)
        let store = SavedToursStore()
        let changed = store.setSaved(true, tourID: selected.id)
        WidgetSnapshotPublisher.publish(tours: tours, savedIDs: store.ids)
        return .result(
            dialog: IntentDialog(changed ? "Saved \(selected.title)." : "\(selected.title) is already saved."))
    }
}

struct RemoveSavedTourIntent: AppIntent {
    static let title: LocalizedStringResource = "Remove Saved Tour"
    static let description = IntentDescription("Remove a walk from your saved StoryTrail tours.")

    @Parameter(title: "Tour") var tour: TourEntity

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let (selected, tours) = try await TourShortcutData.tour(for: tour)
        let store = SavedToursStore()
        let changed = store.setSaved(false, tourID: selected.id)
        WidgetSnapshotPublisher.publish(tours: tours, savedIDs: store.ids)
        return .result(
            dialog: IntentDialog(
                changed ? "Removed \(selected.title) from saved tours." : "\(selected.title) was not saved.")
        )
    }
}

struct GetTourProgressIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Tour Progress"
    static let description = IntentDescription("Get the number of visited stops on a StoryTrail walk.")

    @Parameter(title: "Tour") var tour: TourEntity

    func perform() async throws -> some IntentResult & ReturnsValue<Int> & ProvidesDialog {
        let (selected, _) = try await TourShortcutData.tour(for: tour)
        let visitedIDs = TourProgress.visitedStopIDs(for: selected.id)
        let summary = TourVisitSummary(tour: selected, visitedIDs: visitedIDs)
        return .result(
            value: summary.visitedCount,
            dialog: IntentDialog("\(selected.title): \(summary.visitedCount) of \(summary.stopCount) stops visited.")
        )
    }
}

struct StoryTrailShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SaveTourIntent(),
            phrases: ["Save \(\.$tour) in \(.applicationName)"],
            shortTitle: "Save Tour",
            systemImageName: "bookmark"
        )
        AppShortcut(
            intent: RemoveSavedTourIntent(),
            phrases: ["Remove \(\.$tour) from \(.applicationName)"],
            shortTitle: "Remove Saved Tour",
            systemImageName: "bookmark.slash"
        )
        AppShortcut(
            intent: GetTourProgressIntent(),
            phrases: ["Check \(\.$tour) progress in \(.applicationName)"],
            shortTitle: "Get Tour Progress",
            systemImageName: "checkmark.circle"
        )
    }
}
