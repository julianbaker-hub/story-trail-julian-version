# StoryTrail experience redesign

## Screen and flow inventory

| Area | Current experience | Opportunity |
| --- | --- | --- |
| Tours | Editorial introduction and image-heavy cards | Put the next useful action first and give every tour a consistent status |
| Tour detail | Long linear page with route, access, and start actions | Make the walk's rhythm and progress legible at a glance |
| Tour map and player | Numbered pins and a compact player | Keep map and listening controls distinct, with clear selection feedback |
| Compass directions | Large arrow and distance | Convey uncertainty and arrival calmly, without depending on map tiles |
| Stops and transcript | Stacked cards and reading page | Make the sequence feel like collected field notes; keep audio close to reading |
| Saved | Plain empty state and repeated featured cards | Give saved walks a useful launch point and a warm empty state |
| All-tours map | Four markers with no destination | Let a marker preview and open its tour |
| Purchase | Two equal purchase cards | Explain the choice with a clear bundle recommendation and purchase state |
| Support, FAQs, help, contact, legal | Several unrelated list styles | Use one clear section and card language, and distinguish online documents |

## Three candidate directions

| Direction | Visual idea | Interaction idea | Strengths | Concern |
| --- | --- | --- | --- | --- |
| **A. City Guide** | White canvas, crisp blue, compact data rows | Fast filters and utility controls | Efficient and familiar | Feels transactional for a story-led walk |
| **B. Field Journal** | Warm paper, ink, stamps, hand-drawn route cues | Pages and collected notes | Warm and memorable | Dense decoration can crowd a map and long transcript |
| **C. Pocket Atlas** | Coastal green, warm ivory, coral stop markers, generous type | Tactile cards, gentle route reveal, clear map previews | Balances navigation and discovery | Needs restraint so motion stays helpful |

**Decision: Pocket Atlas, with the Field Journal's stop markers and editorial headings.** It puts walking and listening first while giving the stories an inviting personality. The map remains a functional tool. Decorative details stay off the map surface and out of long reading passages.

### How each direction would feel

```text
A · City Guide           B · Field Journal          C · Pocket Atlas
VICTORIA WALKS           STORYTRAIL                 STORYTRAIL
[search] [filters]       Today's field notes        Victoria has a story…
Tour • 50 min • 8 stops  [illustrated cover]        [featured walk photo]
Tour • 35 min • 5 stops  Stamp 01 / 08             8 stop route mark
[Map] [List]             Turn the page →           Walk · Listen · Discover
```

City Guide would use short fades and utility transitions. Field Journal would use page and stamp animations, which risk slowing frequent map/list changes. Pocket Atlas uses a subtle press response, a short progress reveal, and a calm arrival state; these movements confirm action without demanding attention during a walk.

## Chosen system

- **Hierarchy:** one clear page heading, one primary action, short supporting copy, and a consistent card surface. Tour status and progress are visible without opening every detail page.
- **Color:** warm ivory canvas, dark ink, coastal green for actions and routes, coral for the active stop, pale sky for location context, and amber for offline or attention states. Light, dark, and increased-contrast appearances remain adaptive.
- **Shape and type:** rounded editorial headings, 20–24 point cards, soft borders, and large tap targets. Numbered circles connect the map, route list, and player.
- **Motion:** a brief card press response, route/progress reveal when a screen opens, and a small arrival celebration. Every nonessential animation respects Reduce Motion. No continuous or attention-demanding motion while walking.
- **Offline:** maps may lose tile detail, but tour choices, route markers, player, progress, transcripts, and compass remain useful. Online legal documents and uncached audio say when they need a connection.

## Application by screen

| Screen | Redesign |
| --- | --- |
| Tours | Calm page header, featured walking card, consistent secondary cards, and a visible offline promise |
| Detail | Stronger route summary, progress ring/bar, easy entry to map and stories, and a stable Start/Continue action |
| Map/player | Keep the compact player from the first map iteration, tune it to the shared surface and action system |
| Directions | Framed destination and compass with clear distance, arrival state, and optional Maps handoff |
| Stops/transcript | Connected numbered sequence, quieter reading surface, and an anchored audio control |
| Saved | A welcoming empty state with an Explore action; saved cards show walk metadata and access status |
| Map tab | Select a tour marker to reveal an actionable preview card |
| Purchase | Show the single-tour and all-tour choices distinctly; make localized prices and loading states clear |
| Support/FAQ/help/contact/legal | Shared heading and card rhythm; accurate current naming and plain explanations |

## Validation

`make format` and `make check` passed, including strict lint and all 12 simulator XCTest cases. Direct simulator render checks covered Tours, Saved, tour discovery map and preview, tour detail, stop sequence, transcript, compass directions, purchase choices, Support, and the tour FAQ in light appearance. Tours, map, purchase, and directions were also checked in dark appearance. Tours, Saved, map, stops, and purchase were checked at an accessibility text size. The production launch path was restored after these direct screen checks.

The preview build was installed and launched on a paired iPhone 17 Pro beside the existing app. A device screenshot confirmed the redesigned map and player render on hardware. Compass calculations were not changed; the display now waits for a heading before presenting a directional arrow. The user checked Directions while turning the phone and reported that it looked good. Haptic feel was not independently assessed. StoreKit purchase completion and online legal-document availability depend on external services and were not exercised by the screenshot review.
