# StoryTrail: your first walkthrough

Victoria stories, stop-by-stop audio, a compact map player, and offline GPS and compass directions.

**First useful result:** Open Inner Harbour, choose a stop, and play a bundled story.

## Try it

Start with the free Inner Harbour tour.

Run from the repository root:

```sh
open StoryTrail.xcodeproj
```

Then open **StoryTrail scheme in an iPhone simulator**.

## Walk through the experience

1. **Choose the free walk.** Run the StoryTrail scheme. Open Inner Harbour to explore without buying a tour.
2. **Hear a place.** Open the stop list or map and play a bundled Inner Harbour story. The compact dock keeps the route visible.
3. **Explore the controls.** Open story details for seeking and transport controls. Save the tour and inspect Saved.
4. **Try the walking context.** Simulate a location near Victoria's Inner Harbour. Validate compass behavior and a real offline walk on an iPhone.

## What is available

- Four Victoria tour routes
- Bundled Inner Harbour narration
- Saved tours and local progress
- StoreKit purchases, widgets, and Shortcuts

## Expectations that matter

- The other tours still use a prototype preview track until their own audio is supplied.
- Offline GPS and compass remain useful, but map tiles can be unavailable.
- Local purchase testing needs an Xcode StoreKit configuration. Real prices come from App Store Connect.

## If you get stuck

| Symptom | Next step |
| --- | --- |
| The map has no location | You can inspect the route without permission. Simulate a Victoria location for nearby-stop selection. |
| Purchase products do not load | Configure the matching StoreKit product IDs in Xcode or App Store Connect. Inner Harbour stays the free demo. |

## Continue with the right guide

- [Widgets](widgets.md)
- [Shortcuts](shortcuts.md)
- [Map player design](map-player-ux-review.md)

## Development checks

```sh
make check
```

This is a software walkthrough based on local source reviewed on 6 October 2026. It does not verify real device behavior, live account state, or external provider setup.
