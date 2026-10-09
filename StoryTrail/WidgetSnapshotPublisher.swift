import Foundation
import WidgetKit

enum WidgetSnapshotPublisher {
    private static let activeTourKey = "widget-active-tour-id"

    static func activate(_ tour: Tour, in tours: [Tour], savedIDs: Set<String>) {
        UserDefaults.standard.set(tour.id, forKey: activeTourKey)
        publish(tours: tours, savedIDs: savedIDs)
    }

    static func publish(tours: [Tour], savedIDs: Set<String>) {
        let activeID = UserDefaults.standard.string(forKey: activeTourKey)
        let snapshot = WidgetSnapshot(
            activeTour: tours.first(where: { $0.id == activeID }).map {
                makeWidgetTour($0, visitedIDs: TourProgress.visitedStopIDs(for: $0.id))
            },
            savedTour: tours.first(where: { savedIDs.contains($0.id) }).map {
                WidgetTour(
                    id: $0.id, title: $0.title, subtitle: $0.subtitle, minutes: $0.minutes,
                    visitedCount: 0, stopCount: $0.stops.count, nextStopTitle: nil
                )
            }
        )
        let previous = WidgetSnapshotStore.load()
        guard WidgetSnapshotStore.save(snapshot) else { return }
        if previous?.activeTour != snapshot.activeTour {
            WidgetCenter.shared.reloadTimelines(ofKind: "ContinueWalk")
        }
        if previous?.savedTour != snapshot.savedTour {
            WidgetCenter.shared.reloadTimelines(ofKind: "SavedWalk")
        }
    }

    static func makeWidgetTour(_ tour: Tour, visitedIDs: Set<String>) -> WidgetTour {
        return WidgetTour(
            id: tour.id,
            title: tour.title,
            subtitle: tour.subtitle,
            minutes: tour.minutes,
            visitedCount: tour.stops.filter { visitedIDs.contains($0.id) }.count,
            stopCount: tour.stops.count,
            nextStopTitle: tour.stops.first(where: { !visitedIDs.contains($0.id) })?.title
        )
    }
}
