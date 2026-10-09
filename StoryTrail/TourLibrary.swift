import Foundation

@MainActor
final class TourLibrary: ObservableObject {
    @Published private(set) var tours: [Tour] = []
    @Published private(set) var savedTourIDs: Set<String> = []
    @Published private(set) var isLoading = false
    @Published private(set) var loadError: String?

    private let repository: any TourRepository
    private let savedStore = SavedToursStore()

    init(repository: any TourRepository = BundledTourRepository()) {
        self.repository = repository
        savedTourIDs = savedStore.ids
        Task { await reload() }
    }

    func reload() async {
        isLoading = true
        loadError = nil
        do {
            tours = try await repository.fetchTours()
            refreshSavedTours()
            WidgetSnapshotPublisher.publish(tours: tours, savedIDs: savedTourIDs)
        } catch {
            loadError = error.localizedDescription
        }
        isLoading = false
    }

    func isSaved(_ tour: Tour) -> Bool { savedTourIDs.contains(tour.id) }

    func toggleSaved(_ tour: Tour) {
        savedStore.setSaved(!savedStore.ids.contains(tour.id), tourID: tour.id)
        refreshSavedTours()
        WidgetSnapshotPublisher.publish(tours: tours, savedIDs: savedTourIDs)
    }

    func refreshSavedTours() {
        savedTourIDs = savedStore.ids
    }
}

struct SavedToursStore {
    static let didChangeNotification = Notification.Name("StoryTrailSavedToursDidChange")
    private let key = "savedTourIDs"
    let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var ids: Set<String> {
        Set(defaults.stringArray(forKey: key) ?? [])
    }

    @discardableResult
    func setSaved(_ saved: Bool, tourID: String) -> Bool {
        var updated = ids
        let changed = saved ? updated.insert(tourID).inserted : updated.remove(tourID) != nil
        guard changed else { return false }
        defaults.set(updated.sorted(), forKey: key)
        Task { @MainActor in
            NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
        }
        return true
    }
}
