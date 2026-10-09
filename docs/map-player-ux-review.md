# Map player UX review

## Latest map update

The October 2 update keeps a compact story dock over the map and opens a separate sheet for story details, seeking,
and transport controls. Back and recenter buttons float over the map. The combined app also publishes walk progress
to widgets and retains offline compass directions. The review below records the earlier inline expansion design.

## Current experience

The tour map opens with a large, always-visible player. Its stop summary, offline label, scrubber, timestamps, five transport controls, and directions button compete for the same space as the route. On an iPhone, the player can occupy much of the map even when someone only wants to find the next pin. The permanent “GPS works offline” line repeats information already shown elsewhere. The recenter control also has two outcomes (current location or full route) but one generic label.

## Alternatives considered

| Option | Compact sketch | Strengths | Costs |
| --- | --- | --- | --- |
| A. Keep the full player | `map / stop details / directions / scrubber / five controls` | Every action is visible | Leaves little map space and gives secondary controls equal emphasis |
| B. Collapsible player card | `map / stop + Play / progress / Directions + More controls` | Keeps the main actions visible; expands for seeking and skip controls; fits the existing SwiftUI navigation | Adds one tap for secondary controls |
| C. Floating play button | `map / floating Play`; open a separate full screen player | Maximizes map space | Hides the stop title and directions; requires frequent context switching |

**Chosen: B.** Walking requires quick access to the current story, next direction, and map. The compact card gives those actions a stable place without making the route a narrow strip. A labeled expand control reveals the full player when needed. The card retains the existing offline audio and compass behavior.

## Interaction details

- The compact card shows the stop number and title, a prominent Play/Pause control, listening progress, directions, and a labeled More controls button.
- Expanded mode adds the stop summary, interactive scrubber, skip and story navigation controls, loading/error status, and a collapse control.
- The map control describes its actual action: center on the user when location is available, otherwise show the full route.
- Offline status remains near the map title. The player does not repeat it in every state.

## Verification

Check the compact and expanded states on an iPhone simulator, including long stop titles and the last stop. Run `make check` for strict formatting and unit tests. Compass heading behavior is unchanged.
