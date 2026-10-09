# Apple HIG review

Reviewed 2026-09-18 for StoryTrail's iPhone experience. This is a targeted implementation review, not an accessibility certification or a claim that every Apple platform guideline applies.

## Changes applied

- **Typography and layout:** replaced fixed-point reading fonts with rounded semantic text styles that follow Dynamic Type. Tour metadata can stack, the tour grid uses larger cells at accessibility sizes, titles are allowed to grow, and numbered stop rails scale with their badges. Primary actions use minimum heights instead of fixed text containers. Directions and the map player can scroll when content exceeds the available space.
- **Color and appearance:** removed forced light mode. Added adaptive dark surfaces, text, accents, and increased-contrast text/border colors. Separated the dark action-button fill from the adaptive green foreground so white action labels remain readable in both appearances.
- **Controls and accessibility:** enlarged small playback and restore controls to at least 44 points, labeled playback actions and scrubbers, and exposed map marker numbers and state to VoiceOver. Geographic marker numbers intentionally remain compact to avoid covering the map; reading text scales.
- **Motion:** compass rotation, selected-marker animation, route expansion, and arrival transitions respect Reduce Motion.
- **Navigation and safe areas:** retained the tab bar during pushed tour navigation, replaced hard-coded top/bottom offsets with safe-area layout, and reserved space for the player outside the map's visible content so map attribution is not covered by the player.
- **Purchases and wording:** preserved StoreKit-localized prices and restore access. Clarified that bundled stories work offline while remote audio needs a connection on first use. Aligned saved-tour confirmation wording with the Saved tab.
- **Shape:** retained a coordinated 22-point card and 16-point button system. Apple does not require every button and container to have identical radii; component hierarchy and nested geometry matter.

## Existing behavior retained

- Location permission is requested in the relevant navigation flow, not at app launch. Manual stop selection remains available if permission is denied.
- GPS, compass calculations, bundled audio, tour metadata, and progress remain independent of a network connection. Map tiles and uncached remote audio are optional online resources.
- The audio model already handles system playback controls, audio interruptions, and disconnected headphones. This review does not alter those mechanisms.
- Native tabs, navigation destinations, purchase confirmation, alerts, sliders, and map gestures remain in use.

## Verification and remaining manual checks

`make format` and `make check` completed successfully, including strict lint and the simulator XCTest suite. The Tours screen was visually checked at default text size in light and dark appearance, and at the largest accessibility text size in dark appearance. Simulator appearance/text settings were restored afterward.

Full-screen-by-screen VoiceOver, Switch Control, small-device and landscape walkthroughs, and physical-device GPS/compass/audio checks remain necessary before making accessibility support claims. The screenshot check is not a complete interactive walkthrough of purchase, directions, or player screens. Colors were reviewed in code and screenshots; a full rendered contrast audit remains outstanding.

## Primary sources

- [Typography](https://developer.apple.com/design/human-interface-guidelines/typography)
- [Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)
- [Color](https://developer.apple.com/design/human-interface-guidelines/color)
- [Dark Mode](https://developer.apple.com/design/human-interface-guidelines/dark-mode)
- [Layout](https://developer.apple.com/design/human-interface-guidelines/layout)
- [Buttons](https://developer.apple.com/design/human-interface-guidelines/buttons)
- [Tab bars](https://developer.apple.com/design/human-interface-guidelines/tab-bars)
- [Toolbars](https://developer.apple.com/design/human-interface-guidelines/toolbars)
- [Maps](https://developer.apple.com/design/human-interface-guidelines/maps)
- [Privacy](https://developer.apple.com/design/human-interface-guidelines/privacy)
- [Playing audio](https://developer.apple.com/design/human-interface-guidelines/playing-audio)
- [In-app purchase](https://developer.apple.com/design/human-interface-guidelines/apple-in-app-purchase)
- [Reduced Motion evaluation criteria](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/reduced-motion-evaluation-criteria/)
