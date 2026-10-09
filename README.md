# StoryTrail for iOS

A native SwiftUI prototype of StoryTrail's Victoria walking tours. The app uses Apple MapKit, Core Location, and AVFoundation, so no third-party map account or token is required.

## Start here

Start with the free Inner Harbour tour.

| What you need | Start with |
| --- | --- |
| A useful first run | [First-use walkthrough](docs/start-here.md) |
| An interactive project overview | [Open the offline tour](docs/project-overview.html) |
| Setup, scope, and development | The reference sections below |

## Run

1. Open `StoryTrail.xcodeproj` in Xcode.
2. Select the `StoryTrail` scheme and any iPhone simulator.
3. Press Run.

The simulator can show the route without location permission. To test nearby-stop triggering, choose a simulated location in Xcode near Victoria's Inner Harbour.

## Current prototype

- Four walking tours with native tab navigation and open editorial layouts
- Tour detail, stop list, route map, support, and saved-tour screens
- Interactive MapKit route with numbered stop markers, floating controls, and a compact audio player
- Native audio playback with bundled stories for all eight Inner Harbour stops
- Foreground location tracking and nearby-stop selection
- Offline GPS and compass directions, with clear handling for unavailable map tiles
- Local saved-tour state (no account required)
- Home Screen widgets for walk progress and saved tours, with links back to the tour
- Shortcuts actions to save tours, remove saved tours, and check visited-stop progress
- StoreKit 2 purchases for individual tours and an all-tours bundle

## Purchases

Inner Harbour is the free demo. Old Town, James Bay, and Beacon Hill Park can be unlocked individually, or together
with the all-tours bundle. All products are non-consumable, and the app verifies StoreKit transactions before granting
access. The last verified entitlements are retained locally so purchased tour content remains available offline.

Create these non-consumable in-app purchases in App Store Connect before testing with a sandbox Apple ID:

| Reference name | Product ID |
| --- | --- |
| All Victoria Tours | `com.storytrailguide.app.alltours` |
| Old Town | `com.storytrailguide.app.tour.oldtown` |
| James Bay | `com.storytrailguide.app.tour.jamesbay` |
| Beacon Hill Park | `com.storytrailguide.app.tour.beaconhill` |

Pricing and localization remain owned by App Store Connect; the app always displays Apple's localized price. When a
tour is added to `tours.json`, add its product mapping in `PurchaseConfiguration.swift`. For local purchase testing,
create an Xcode StoreKit configuration with the same identifiers and select it in the StoryTrail scheme's Run options.

## Widgets and Shortcuts

See [widgets](docs/widgets.md) for shared App Group configuration and [Shortcuts](docs/shortcuts.md) for available actions.
Both features use the bundled tour catalogue and locally stored progress.

## Tour data

The current catalogue lives in `StoryTrail/Resources/tours.json`. `TourLibrary`
depends on the `TourRepository` protocol rather than the file directly. The app
ships with `BundledTourRepository`, and `NetworkTourRepository` is ready for an
HTTP endpoint returning the same JSON envelope. Switching sources does not
require changes to screens or navigation.

The Inner Harbour stories are stored in `StoryTrail/Resources/Audio/`. Each `audio_file` in `tours.json` points to
one bundled MP3, named by tour, stop number, and place. The remaining tours still use the prototype preview track
until their own audio is supplied. For future backend audio, set a stop's `audio_url` in the tour JSON and omit
`audio_file`; the player already downloads and caches remote audio when a URL is present.

## Development quality checks

The project uses the `swift-format` tool bundled with Xcode for both formatting and strict style linting.

```sh
make setup-hooks # once per clone
make format
make check
```

`make check` runs the linter and the XCTest suite on the first available iPhone simulator. Set `SIMULATOR_ID` to
choose a specific simulator or `DERIVED_DATA_PATH` to change the build output location. Commits use the
[Conventional Commits](https://www.conventionalcommits.org/) format.
