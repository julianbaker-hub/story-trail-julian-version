# StoryTrail actions in Shortcuts

StoryTrail publishes three App Shortcuts with a tour picker:

| Action | What it does | Output |
| --- | --- | --- |
| Save Tour | Adds a tour to Saved. Running it twice keeps the tour saved. | Spoken or displayed confirmation |
| Remove Saved Tour | Removes a tour from Saved. Running it twice keeps the tour removed. | Spoken or displayed confirmation |
| Get Tour Progress | Counts stops visited on a tour. | Number of visited stops, usable by later Shortcuts actions |

In the Shortcuts app, create a shortcut or personal automation, add an action, search for **StoryTrail**, and choose a tour. The tour picker and progress data come from bundled content and local storage, so these actions need no network connection or location permission. They don't unlock purchases or mark stops visited. Progress changes when StoryTrail records an arrival during a walk.

The app's App Intents metadata is generated at build time. `TourEntityQuery` resolves and searches tour names from the bundled catalogue; the intents validate a selected tour again before acting. Save and removal update the same persistence used by the Saved tab and refresh the Saved Walk widget. When StoryTrail becomes active, it refreshes the Saved tab after an automation changes it.

Apple recommends a small set of common actions and suggests using App Entities for app-specific values. These actions follow its [App Intents overview](https://developer.apple.com/documentation/appintents/getting-started-with-the-app-intents-framework), [App Shortcuts guidance](https://developer.apple.com/documentation/appintents/app-shortcuts), and [entity query guidance](https://developer.apple.com/documentation/appintents/entity-queries).
