# Feature Specification: R02-G05-04 — Colorfall Canyons: gameplay spatial interaction

**Feature Branch**: `344-colorfall-canyons-gameplay-spatial-interaction` (spec directory only; work on `main`)

**Created**: 2026-11-21

**Status**: Clarified

**Ledger gate**: R02-G05-04 (migration ledger, game feature of experience R02-G05) · ID namespace FR-R02G0504-###,
SC-R02G0504-###, T-R02G0504-###

**Input**: User description: the archived R02-G05-04 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Implement native gesture-to-world actions, undo and camera behavior" for Colorfall Canyons (controls: "drag short sluice
edits and tap valves; pause/step/undo"), with the canonical overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/344-colorfall-canyons-gameplay-spatial-interaction`; FR-R02G0504-###,
  SC-R02G0504-###, T-R02G0504-###.
- **Packaging (ADR-0009):** the gestures live in the experience `r02-g05.colorfall-canyons` (a registered candidate since
  R02-G05-03) inside the one app; the source's `Apps/ColorfallCanyons` paths are superseded.
- **Superseded parts of the source prompt:** price, "no IAP" and the Round 2 lock (as before). **Device-only items:**
  touch feel and latency on D1/D2/D3, recorded as `{device}` tasks for after ImplementationLock-100. **Owner-only
  items:** none.
- **Shared features used:** R02-F22 (spatial controls and analytic picking), R02-F26 (input and accessibility
  contract), the experience host's pointer events, and the kernel, adapter and renderer of R02-G05-01 … 03.

## Clarifications

### Session 2026-11-21

Answered autonomously under the owner's standing delegation, safest well-supported option each time. Facts checked in
code (read-only, 2026-11-21): Hue Compass's feature 334 solved the same problem with a host-tested
`HueCompassGestureController` taking `PointerEvent`s (id, phase began/moved/ended/cancelled, location in view points with
the origin top-left, timestamp) with the view size and the drawn snapshot (idle, swiping, orbiting, cancelled; at most
one action per gesture; only event timestamps read) and an orbit in its scene geometry; Colorfall Canyons's camera
(`ColorfallCanyonsSceneGeometry.camera(_:aspect:)`) looks from +z pitched 50° down, fitted to the bounding sphere of the
tallest element; its panel has a cell picker with Carve, a valve button per spring, Step 1, Step 10, Run, Undo, Redo and
Next level; its adapter accepts `canyon.carve [cell]` and `canyon.valve [spring]`.

- Q: How does a drag become a carve? → A: a one-finger touch is picked at touch-down; if the pick is a carvable cell
  (open, no spring or basin, height above 0) the gesture is a drag on that cell; when the finger lifts after having moved
  at least 16 points from where it began, exactly one `canyon.carve [cell]` of the cell picked at touch-down is sent; a
  touch that never moves 10 points is a tap; a drag between 10 and 16 points sends nothing. Impact: FR-R02G0504-001;
  SC-R02G0504-001.
- Q: How is a touch picked? → A: the ray from the drawn camera through the touch point (in view points, with the view's
  aspect) is intersected with every block top (the square of the cell at y = its top height), every spring emitter
  (its column as an axis-aligned box of half-width 0.18·u up to the emitter top) and nothing else; the hit with the
  smallest ray distance wins (an emitter's cell picks the spring). When the ray hits nothing, the cell or emitter whose
  projected top centre lies within 22 points of the touch (the minimum target) and nearest to it is picked; otherwise
  the touch is on empty space. Impact: FR-R02G0504-003; SC-R02G0504-001.
- Q: What do taps do? → A: a tap on a spring sends exactly one `canyon.valve [spring]`; a tap on a cell sends nothing
  (carving needs a drag, so a stray tap never carves); two taps on empty space whose `.ended` timestamps are at most
  0.35 s apart reset the view, in every stage. While the play is not in stage `playing`, drags and taps send no action
  and show no highlight. Impact: FR-R02G0504-002; SC-R02G0504-002.
- Q: What can the camera do? → A: two-finger orbit of yaw (±40° about the y axis, 90° per view width) and pitch (25° … 70°
  down from the horizon, authored 50°, 60° per view height); a second finger cancels a drag (nothing sent); a third
  re-bases the midpoint; a double tap on empty space or "Reset view" returns to the authored view; the distance refits so
  the bounding sphere stays inside the view with a 5 % margin at every orbit and aspect 0.4 … 2.5. Presentation only:
  never in the digest, the snapshot or the kernel; not saved. Impact: FR-R02G0504-004; SC-R02G0504-003.
- Q: How is a drag previewed and tested? → A: from touch-down on a carvable cell until release, the cell's top is
  outlined in pearl and the description reads "Carving row r, column c"; nothing changes in the kernel until release.
  The Core gesture controller takes pointer events with the view size and the drawn snapshot and orbit and returns at
  most one action per gesture plus the highlight; host tests feed 500 seeded drags and taps on certified levels at
  several sizes and orbits and compare with an independent pick computed in the test; simulator tests send the same
  touches through the experience's pointer entry; a host test wins all 100 certified levels through panel actions (the
  picker's carvable-cell order, Carve, valve buttons and Run). Impact: FR-R02G0504-005 … 007; SC-R02G0504-001 … 004.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Drag to carve a sluice (Priority: P1) 🎯

A player drags a finger across a canyon cell and that cell is carved one step lower, opening a new channel; the cell
under the finger is highlighted while dragging, and exactly one carve is made when the finger lifts.

**Why this priority**: carving is the game's main move.

**Independent Test**: scripted drags over cells of certified levels produce exactly the carve the independent picking
computation predicts, or none.

**Acceptance Scenarios**:

1. **Given** a playing level, **When** a drag starts on a carvable cell and moves far enough, **Then** exactly one carve
   of that cell is sent on release.
2. **Given** a drag that starts on rock, a spring, a basin, a drain or empty space, **When** it is released, **Then**
   nothing is sent.

### User Story 2 - Tap a spring's valve (Priority: P1)

A player taps a spring and its valve opens or closes.

**Independent Test**: taps on spring emitters send exactly one valve toggle for that spring; taps elsewhere send none.

### User Story 3 - Look around and come back (Priority: P2)

A player orbits the canyon with two fingers within bounds and returns to the authored view with a double tap on empty
space or a "Reset view" button; the view never changes the game.

**Independent Test**: orbit stays within bounds at every aspect, the scene stays inside the view, and the digest never
changes.

### User Story 4 - Every move without gestures (Priority: P1)

A player who cannot drag or tap precisely can do everything through the labelled panel (cell picker and carve, valve
buttons, steps, undo, redo), including winning every certified level.

**Independent Test**: all 100 certified witnesses are replayed through panel actions on the host and win.

### Edge Cases

- **A drag that never moves far enough:** a tap; on a spring it toggles the valve, elsewhere nothing.
- **A second finger during a drag:** cancels the drag (nothing sent) and orbits.
- **A cancelled touch:** sends nothing.
- **Not playing (won, failed, paused):** gestures send nothing and show no highlight; orbit still works.
- **A cell hidden behind a taller nearer block:** picking selects the nearest block top hit by the touch ray.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G0504-001**: A drag that starts on a carvable cell and moves at least 16 points MUST send exactly one carve of
  that cell on release; a touch that moves less than 10 points is a tap; any other drag MUST send nothing.
- **FR-R02G0504-002**: A tap on a spring MUST send exactly one valve toggle of that spring; other taps MUST send nothing
  except a double tap on empty space, which resets the view.
- **FR-R02G0504-003**: Picking MUST be analytic and deterministic: the touch ray through the drawn camera against the
  block tops and emitter columns, the nearest hit winning, with a 22-point minimum touch target.
- **FR-R02G0504-004**: Two-finger orbit MUST stay within yaw ±40° and pitch 25° … 70° (authored 0°, 50°), keep the scene inside the view at
  every aspect 0.4 … 2.5 and never enter the digest, the snapshot or the kernel; a reset returns to the authored view.
- **FR-R02G0504-005**: While dragging, the picked cell MUST be highlighted and described; nothing changes in the kernel
  until release.
- **FR-R02G0504-006**: The panel MUST keep every action available without gestures and gain "Reset view"; every
  certified witness MUST be replayable through panel actions.
- **FR-R02G0504-007**: Gestures MUST be tested on the host by scripted pointer sequences and on the simulator through the
  experience's pointer entry; existing tests pass; every new public name is documented.

### Key Entities

- **Gesture controller**: state (idle, dragging, orbiting, cancelled), picked cell, start point, last points.
- **Orbit**: yaw and pitch offsets from the authored view.
- **Gesture action**: carve(cell), valve(spring) or resetView, at most one per gesture.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G0504-001**: For 500 seeded scripted drags and taps on certified levels at several sizes, the actions sent equal
  an independent computation of the touched cell or spring, at most one per gesture.
- **SC-R02G0504-002**: Second fingers, cancels and non-playing stages send no game action (no carve and no valve) in
  every scripted case; only the view may reset.
- **SC-R02G0504-003**: At every orbit within bounds and every aspect 0.4 … 2.5 the scene stays inside the view with a
  5 % margin, and the digest never changes.
- **SC-R02G0504-004**: All 100 certified levels are won through panel actions alone.
- **SC-R02G0504-005**: Existing tests pass; the reference regression passes 7 of 7; each test under 10 seconds.
- **SC-R02G0504-006** {device}: after ImplementationLock-100, touch feel and latency are checked on D1/D2/D3.

## Assumptions

- Hints, failure explanations and progression come in R02-G05-05; announcements, haptics and full accessibility in
  R02-G05-06; persistence in R02-G05-07.
- Time stays discrete: the panel's step and run buttons advance it; pausing is the play's stage, as before.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Gesture-to-world actions (drag sluice edits, tap valves) | FR-R02G0504-001, 002, 003 |
| Undo | FR-R02G0504-006 (panel undo and redo) |
| Camera behaviour (constrained orbit, reset, no singularities) | FR-R02G0504-004 |
| Accessible alternative to every gesture | FR-R02G0504-006 |
| Deterministic tests | FR-R02G0504-007; SC-R02G0504-001 … 004 |

## Negative Requirements / Excluded scope

- No free camera navigation, no gestures that change the rules, no hints, sounds or haptics, no device run before
  ImplementationLock-100, no availability before X-R02-G05.
