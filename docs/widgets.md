# StoryTrail widgets

StoryTrail offers two Home Screen widgets in small and medium sizes:

- **Continue Walk** shows the most recently opened route, visited stop count, and (in medium size) the next stop.
- **Saved Walk** shows a bookmarked tour. When several tours are saved, it shows the first one in the tour library.

Both widgets open the matching tour detail screen. They show an invitation to open or save a walk when they have no data. The app writes a compact snapshot to `group.com.storytrailguide.app` when tours load, a route opens, a stop is visited, or a bookmark changes. The widget extension reads only that snapshot. It never starts location services or downloads tour media. Progress counts and next stop text are marked sensitive for system redaction.

The timeline uses `.never` because these values change in response to app actions, rather than at predictable times. The app reloads a widget kind only when its displayed snapshot changes. This follows Apple's guidance on [widget strategy](https://developer.apple.com/documentation/WidgetKit/Developing-a-WidgetKit-strategy), [timelines](https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date), and [opening the matching app scene](https://developer.apple.com/documentation/WidgetKit/Linking-to-specific-app-scenes-from-your-widget-or-Live-Activity).

For signed builds, register the App Group `group.com.storytrailguide.app` for both the app and widget extension App IDs in the Apple Developer portal, then refresh the provisioning profiles. The checked-in entitlements already declare the group on both targets.

To verify on a device, add each widget from the Home Screen gallery, open a route, visit a stop, save a tour, and confirm each widget updates and opens the corresponding tour. Check empty states before those actions and check redaction with the device locked. The automated simulator suite covers snapshot selection, shared persistence, URL parsing, and extension packaging; it does not simulate a physical arrival or Home Screen placement.
