import XCTest

@testable import StoryTrail

final class TourShortcutsTests: XCTestCase {
    func testSavedTourActionsAreIdempotent() {
        let suite = "TourShortcutsTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            XCTFail("Unable to create isolated defaults suite")
            return
        }
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = SavedToursStore(defaults: defaults)

        XCTAssertTrue(store.setSaved(true, tourID: "inner-harbour"))
        XCTAssertFalse(store.setSaved(true, tourID: "inner-harbour"))
        XCTAssertEqual(store.ids, ["inner-harbour"])
        XCTAssertTrue(store.setSaved(false, tourID: "inner-harbour"))
        XCTAssertFalse(store.setSaved(false, tourID: "inner-harbour"))
        XCTAssertTrue(store.ids.isEmpty)
    }

    func testTourPickerUsesBundledCatalogueAndSearch() async throws {
        let query = TourEntityQuery()
        let suggestions = try await query.suggestedEntities()
        let harbour = try XCTUnwrap(suggestions.first(where: { $0.id == "inner-harbour" }))

        let resolved = try await query.entities(for: [harbour.id])
        let matching = try await query.entities(matching: "INNER HARBOUR")
        let missing = try await query.entities(for: ["missing-tour"])
        XCTAssertEqual(resolved.map(\.id), [harbour.id])
        XCTAssertEqual(matching.map(\.id), [harbour.id])
        XCTAssertTrue(missing.isEmpty)
    }

    func testProgressIgnoresUnknownStopIDs() async throws {
        let tours = try await BundledTourRepository().fetchTours()
        let tour = try XCTUnwrap(tours.first)
        let firstStop = try XCTUnwrap(tour.stops.first)

        let summary = TourVisitSummary(tour: tour, visitedIDs: [firstStop.id, "unrelated-stop"])
        XCTAssertEqual(summary.visitedCount, 1)
        XCTAssertEqual(summary.stopCount, tour.stops.count)
    }
}
