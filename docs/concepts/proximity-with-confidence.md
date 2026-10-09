---
title: Proximity with confidence
summary: Treat arrival as a confidence decision, not a single GPS measurement.
category: Navigation
status: Adopted
---

# Proximity with confidence

A walking tour should react when a person meaningfully arrives, without skipping ahead because GPS briefly drifts. The
trigger is therefore a small state machine rather than a raw distance check.

## The model

- **Enter** when the measured position is inside a stop's trigger radius and the reported accuracy is usable.
- **Stay inside** while readings wobble near the boundary.
- **Exit** only after moving beyond the larger exit radius. This hysteresis prevents repeated arrival events.
- **Choose one story** when trigger areas overlap: use the nearest newly entered stop and mark the overlap as handled.
- **Keep manual selection** available because sensor confidence can never be guaranteed.

The current engine defaults to a 30 m entry radius, a 45 m exit radius, and ignores readings whose horizontal accuracy
is worse than 65 m. Individual stops can tune their trigger radius between 5 m and 100 m.

## Product consequence

The interface should describe an arrival as helpful automation, not certainty. A person can always choose a stop, and a
poor reading should lead to no automatic action rather than the wrong action.
