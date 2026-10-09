import SwiftUI

@main
struct StoryTrailApp: App {
    @StateObject private var player = AudioPlayerModel()
    @StateObject private var library = TourLibrary()
    @StateObject private var connectivity = ConnectivityModel()
    @StateObject private var purchaseStore = PurchaseStore()

    init() {
        StoryTrailShortcuts.updateAppShortcutParameters()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(player)
                .environmentObject(library)
                .environmentObject(connectivity)
                .environmentObject(purchaseStore)
        }
    }
}
