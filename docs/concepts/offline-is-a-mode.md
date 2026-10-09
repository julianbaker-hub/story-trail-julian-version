---
title: Offline is a mode, not an error
summary: Preserve the walk when the network disappears and explain only what changed.
category: Resilience
status: Adopted
---

# Offline is a mode, not an error

Weak coverage is ordinary on a walking tour. StoryTrail should continue to feel like a guide when connectivity changes,
not collapse into a recovery screen.

## Capability layers

- **Always local:** tour metadata, bundled stories, transcripts, saved progress, GPS, and compass guidance.
- **Cacheable:** downloaded story audio and map detail previously viewed on the device.
- **Network-enhanced:** fresh map tiles, uncached remote media, purchases, and entitlement refresh.

The core walk must not depend on the third layer. Network-enhanced features can become unavailable without blocking stop
selection, directions, or already-local stories.

## Communication rule

Say what still works before what may not. “Offline — GPS and compass still work” is more useful than “No connection.”
Put the message near the affected surface, keep it dismissible where appropriate, and avoid repeated alerts.
