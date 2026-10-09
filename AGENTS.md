# StoryTrail project instructions

These instructions apply to the entire repository.

## Project and architecture

- StoryTrail is a native SwiftUI app targeting iOS 17 and later.
- Keep UI in SwiftUI, navigation and map presentation in views, sensor/audio state in observable models, and pure calculations in testable value types.
- Prefer Apple frameworks already in use: MapKit, Core Location, AVFoundation, Network, and Foundation.
- Treat `project.yml` and the checked-in `StoryTrail.xcodeproj` as paired project definitions. Keep both aligned when adding files or changing build settings. Do not regenerate the project when that would discard newer checked-in settings.
- Preserve the offline-first experience. Tour metadata, bundled audio, GPS, compass navigation, and progress must remain useful without a network connection. Clearly distinguish optional network features from required functionality.

## Swift practices

- Follow the repository's `.swift-format` configuration. Use four-space indentation and keep lines within 120 columns.
- Run `make format` after editing Swift and `make lint` before committing.
- Prefer structs and immutable `let` state. Use classes only for identity, framework delegates, or shared mutable state.
- Keep UI-observed models on `@MainActor`. Use structured concurrency (`async`/`await` and `Task`) and honor cancellation for asynchronous work.
- Use `@StateObject` where a view owns an observable model and `@EnvironmentObject`/`@ObservedObject` only for injected ownership.
- Avoid force unwraps, force casts, force tries, implicitly unwrapped optionals, and silently swallowed errors. Model expected failure states and show actionable user-facing errors where appropriate.
- Keep view bodies declarative and extract repeated or complex UI into focused views or computed properties.
- Include accessibility labels/hints for icon-only controls and announce important automatic state changes.
- Start and stop location, heading, audio, and network work with the relevant lifecycle. Do not assume map tiles or remote media are available.
- Never log secrets, precise user location, or other sensitive values in production-level logs.

## Tests and verification

- Add or update XCTest coverage for navigation math, decoding, proximity behavior, persistence, and other non-UI logic changed by the work.
- Run `make check` before finishing a change. It performs strict style linting and the simulator test suite.
- Hardware-dependent behavior such as compass headings must be validated on a physical iPhone when it materially changes; report when only simulator verification was possible.
- Do not weaken lint rules, skip tests, or remove assertions merely to make verification pass.

## Git and commits

- Inspect `git status` before editing and preserve unrelated user changes.
- Commit every completed logical change. Keep commits focused and include only files belonging to that change.
- Use Conventional Commits: `type(scope): imperative summary` or `type: imperative summary`.
- Allowed types are `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, and `revert`.
- Examples: `feat(map): add offline compass fallback`, `fix(audio): retain cached playback`, `chore: add Swift quality checks`.
- Run verification before committing. Do not amend, squash, rebase, or push unless the user explicitly asks.

Run `make setup-hooks` once per clone to enable the repository's lint and commit-message hooks.
