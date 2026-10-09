# A lighter StoryTrail surface

## Research notes

These are product patterns observed in first-party documentation and app guidance, not a claim that the referenced apps use identical visual styling on every screen.

| Reference | Useful pattern | StoryTrail application |
| --- | --- | --- |
| [Apple layout guidance](https://developer.apple.com/design/human-interface-guidelines/layout) | Related content can be grouped by negative space, alignment, or a separator as well as a background shape. | Let type and spacing organize ordinary pages; reserve filled surfaces for overlays and primary actions. |
| [Apple Maps place cards](https://developer.apple.com/design/human-interface-guidelines/maps/) | A selected map location gets a compact information layer while the map stays visible. Apple advises against repeating information already shown elsewhere. | Keep a small selected-tour strip on the map and leave most of the map unobstructed. |
| [Apple Music MiniPlayer](https://support.apple.com/guide/iphone/use-the-music-player-controls-iph676daac9b/27/ios/27) | Playback has a compact state for quick controls and a larger state for deeper controls. | Keep the tour player compact until the listener asks for seeking and stop navigation. |
| [VoiceMap walking tours](https://voicemap.me/walking-tour-app) | Location-triggered audio lets walkers focus on surroundings; pause and resume are core actions. | Make the active story and play state easy to glance at, with secondary player actions disclosed on demand. |
| [komoot navigation](https://support.komoot.com/hc/en-us/articles/10207935661338-Navigate-a-saved-route) | The map stays central while the next instruction remains prominent in a navigation panel. | Let directions and the next stop lead; keep route metrics and extras visually secondary. |
| [AllTrails route preview](https://support.alltrails.com/hc/en-us/articles/37212870983700-Trail-previews-on-trail-pages) | People can inspect a route on the map before starting and pause the preview to examine an area. | Keep route exploration available before starting audio, with the stop sequence easy to scan. |

## Three ways to reduce boxes

| Approach | Main idea | Benefit | Risk |
| --- | --- | --- | --- |
| **Editorial pages** | Image, heading, metadata, and story text sit directly on the page. | Strong sense of place and calmer reading. | Needs disciplined spacing to avoid a long undifferentiated page. |
| **Quiet index** | Tours, stops, help, and actions become rows with short separators. | Fast scanning and fewer nested surfaces. | Too many rules can feel like a settings screen. |
| **Floating navigation** | The map fills the view; only the active story and selected destination get a surface. | Keeps geography visible during a walk. | Overlays must remain legible against changing map detail. |

**Chosen experiment:** editorial pages for discovery and detail, quiet rows for sequences and help, and a single navigation layer over maps. This combines the strengths of the three approaches. Colour marks stop numbers and important states; typography, spacing, and a few rules do most of the grouping. Primary buttons and the player keep filled backgrounds because they need strong affordance and contrast outdoors.

## Checkpoints

- Tours: one unboxed feature image and a vertical list of walks.
- Detail: open progress, field note, route timeline, and action rows.
- Stops and help: a numbered or titled list with light separators.
- Saved and purchase: open empty state and distinct purchase sections.
- Maps: retain one compact, legible overlay for the selected tour or active player.
- Review in light, dark, and large text; run repository lint and simulator tests.

## Result of the experiment

The first pass removed enclosing cards from the featured walk, tour rows, saved state, progress, route preview, stop sequence, help and support rows, and purchase options. A selected map tour now uses a compact full-width material strip. The tour player and primary actions remain filled for legibility and clear touch targets.

Simulator review compared Tours and Stops with the previous boxed screens, then inspected Saved, Detail, Support, and Purchase in light appearance, Tours in dark appearance, and Tours and Stops at an accessibility text size. The open layout makes more of the stop sequence visible and gives tour imagery and titles more space. The repeated “Audio story and transcript” label became noisy at large text sizes, so the final pass removed it; the row's accessibility hint still explains the destination. The Tours heading was shortened so the first walk appears sooner.

The direct screen previews used for visual review were temporary and were removed from the app source. The screenshots did not exercise purchase completion, map tile availability, or live navigation. Those behaviors are unchanged by this visual experiment.
