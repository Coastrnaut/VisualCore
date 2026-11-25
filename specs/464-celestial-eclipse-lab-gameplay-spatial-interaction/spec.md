# Feature Specification: R02-G17-04 — Celestial Eclipse Lab: gameplay spatial interaction

**Feature Branch**: `464-celestial-eclipse-lab-gameplay-spatial-interaction` (spec directory only; work on `main`)

**Created**: 2026-11-25

**Status**: Clarified

**Ledger gate**: R02-G17-04 (migration ledger, game feature of experience R02-G17) · ID namespace FR-R02G1704-###,
SC-R02G1704-###, T-R02G1704-###

**Input**: User description: the archived R02-G17-04 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Gameplay spatial interaction" for Celestial Eclipse Lab ("Implement native gesture-to-world actions, undo and camera
behavior"; player mechanic "position miniature orbits so sequential eclipses form a target sequence"; controls "drag
orbital handles, rotate time dial, step through predicted eclipse timeline"), with the canonical overrides of ADR-0009
and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/464-celestial-eclipse-lab-gameplay-spatial-interaction`; FR-R02G1704-###,
  SC-R02G1704-###, T-R02G1704-###.
- **Packaging (ADR-0009):** the gestures live in the experience `r02-g17.celestial-eclipse-lab` (a registered candidate
  since R02-G17-03) inside the one app; the source's `Apps/CelestialEclipseLab` and `Packages/GameModules` paths are
  superseded.
- **Superseded parts of the source prompt:** price, "no IAP" and the Round 2 lock. The source's "content count 74" is a
  milestone figure; the 100 certified levels of R02-G17-02 stand. **Device-only items:** touch feel and latency on
  D1/D2/D3, recorded as `{device}` tasks for after ImplementationLock-100. **Owner-only items:** none.
- **Shared features used:** R02-F14 (reversible history), R02-F22 (spatial controls and analytic picking), R02-F26
  (input and accessibility contract), the experience host's pointer events, and the kernel, content, adapter and
  renderer of R02-G17-01 … 03.
- **Model:** feature 454 (Starlit Cartouche's gameplay spatial interaction) for the gesture controller, picker, orbit
  and panel, adapted to miniature planets whose phases are set along their orbital rings.

## Clarifications

### Session 2026-11-25

Answered autonomously under the owner's standing delegation, safest well-supported option each time, following feature
454's answers where the games agree. Facts checked in code (read-only, 2026-11-25): the host's `PointerEvent` (id,
phase began/moved/ended/cancelled, location in view points with the origin top-left, timestamp); feature 454's
thresholds (tap below 10 points and 0.5 s, drag from 16 points, double tap within 0.35 s and 22 points, orbit 90° per
view width and 60° per view height, yaw ±60°, pitch −20° … +35°). Celestial Eclipse Lab's adapter declares
`orbit.phase` [body, offset], `clock.run`, `play.undo`, `play.redo`, `level.next`, `orbit.choose` [body] and
`clock.show` [tick] (the last two presentation only). The scene (`CelestialEclipseLabSceneGeometry`) draws each body as
a disc of radius r · s at w(position(at: shown tick, phase)) from eye (0.3, 0.2, 3.4) towards (0, −0.25, 0), fitted to
the box x −0.95 … 0.95, y −1.45 … 0.95, z −0.95 … 0.95, the timeline strip at y −1.15 from x −0.9 to 0.9 with window
brackets at y −1.05, and paints by kind (rings, bodies and shadow lenses by distance, halos, gauges by index).

- Q: How is a touch picked? → A: at touch-down every body is projected through the drawn camera (orbit included) into
  view points; a body is hit when the touch lies within its projected disc radius (r · s) grown by 8 points; of several
  hits the front-most wins (the one painted last). The time dial is the bounding box of the projected timeline strip
  ends and window brackets grown by 8 points. Anything else (rings, halos, bars, backdrop) is empty space. Tap, drag and
  double-tap thresholds are feature 454's. Impact: FR-R02G1704-005; SC-R02G1704-001.
- Q: What do taps do? → A: a tap on a body sends `orbit.choose [body]` in any stage (a fixed body may be chosen; its
  description says it cannot be moved); a tap on the time dial sends `clock.show [tick]` with the tick under the finger
  (below); a tap on empty space changes nothing and two such taps within 0.35 s and 22 points reset the view. On a won
  or failed play no kernel action is sent (taps and the dial still choose and show) and the description says the play
  is over (undo or next level). Impact: FR-R02G1704-002, 003, 007; SC-R02G1704-002.
- Q: How does the orbital-handle drag work? → A: a press on a movable body that moves 16 points or more while playing
  becomes a phase drag: the pending offset is the phase p (0 … period − 1) whose position of that body at the shown
  tick, orbit[(tick + p) mod period] mapped by w and projected, is nearest to the finger (ties to the lower p); the
  presenter shows the body's ghost there (a dashed copy of its disc) and the snapshot's predicted timeline is the
  kernel's timeline of the current phases with that body at the pending offset; on release exactly one `orbit.phase
  [body, p]` is sent when p differs from the current phase, otherwise nothing; a release outside playing, a cancel or
  a second finger clears the preview and sends nothing. A drag from a fixed body sends nothing and explains that it is
  fixed. The preview is presentation only (the snapshot gains `previewBody`, `previewOffset` and the preview timeline;
  none enters the digest). Impact: FR-R02G1704-001, 004, 007; SC-R02G1704-001, 003.
- Q: How do the time dial and two fingers behave? → A: from touch-down on the dial, the tick is the one whose projected
  place on the strip is nearest to the finger, the lower on ties (implementation note, 2026-11-25: under perspective the
  ticks are not evenly spaced on screen, so a linear fraction along the strip missed by one); every change sends
  `clock.show [tick]` (never an undo step, never a kernel action). Two fingers as feature 454: a second finger cancels
  any one-finger gesture (nothing sent) and orbits — yaw ±60° about the vertical axis through the authored box centre
  (90° per view width), pitch −20° … +35° (60° per view height); a third finger re-bases the midpoint; a double tap on
  empty space or "Reset view" returns to orbit (0, 0); the camera refits so the authored box stays inside the view with
  a 5 % margin at every orbit and aspect 0.4 … 2.5 and the eye stays outside the box; meshes are rebuilt when the orbit
  changes; orbit is not saved (schema stays 1). Impact: FR-R02G1704-003, 006; SC-R02G1704-002, 004.
- Q: How is it built and tested? → A: a Core gesture controller (`CelestialEclipseLabGestureController`) with a picker
  (`CelestialEclipseLabPicker`) and an orbit (`CelestialEclipseLabOrbit`, with `camera(_:aspect:orbit:)` equal to the
  authored camera at orbit 0) takes pointer events with the view size, the drawn snapshot and the orbit and returns
  gesture actions (choosePlanet, showTick, setPhase, preview, clearPreview, resetView, explain) and the orbit; the
  geometry draws the ghost; host tests feed 500 seeded taps, phase drags and dial drags on certified levels at several
  sizes and orbits against an independent pick in the test; simulator tests send touches through the experience's
  pointer entry; a host test wins all 100 certified levels through panel actions alone (planet − and +, phase − and +,
  "Set phase", run). The panel's phase − and + no longer send a phase change each (every change costs an action, so
  stepping to a far orbit position could exceed the budget): they move the chosen planet's pending offset (the same
  presentation-only preview as a drag, wrapping 0 … period − 1), and a new "Set phase"
  button sends exactly one `orbit.phase [body, pending offset]` when it differs from the current phase (the checklist's
  CHK013 found this, 2026-11-25). Impact: FR-R02G1704-005, 008, 009; SC-R02G1704-001 … 005.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Drag a planet along its orbit to set its phase (Priority: P1) 🎯

A player presses a movable planet and drags it along its orbital ring; while dragging, the planet's ghost follows the
nearest orbit position and the predicted timeline below the sky shows what the eclipses would become. Lifting the finger
sets the planet's phase there (one action, undoable).

**Why this priority**: changing a phase is the game's only move; the orbital handle is the natural way to do it.

**Independent Test**: scripted drags send exactly the phase change an independent pick predicts, or nothing.

**Acceptance Scenarios**:

1. **Given** a level while playing, **When** the player drags a movable planet along its ring and lifts at an orbit
   position other than its current one, **Then** exactly one phase change to that position is sent.
2. **Given** a drag that lifts at the planet's current position, off the ring or outside playing, **When** it lifts,
   **Then** nothing is sent and the preview clears.
3. **Given** a fixed planet, **When** the player drags it, **Then** nothing moves and the reason is given in words.

### User Story 2 - Tap a planet to choose it (Priority: P1)

A player taps a planet to make it the chosen planet (its dashed ring) for the panel's phase buttons and the
descriptions.

**Independent Test**: scripted taps choose exactly the planet an independent pick predicts; no kernel action is sent.

### User Story 3 - Rotate the time dial along the timeline (Priority: P1)

A player drags along the timeline below the sky (the time dial) to step the shown tick; the planets move to their
positions at that tick and the crescents and halos show the eclipses under way then. Tapping the timeline jumps to a
tick.

**Why this priority**: seeing when eclipses happen is how the player plans the order.

**Independent Test**: scripted drags along the timeline show exactly the tick an independent computation predicts; no
kernel action is sent.

### User Story 4 - Look around the sky and come back (Priority: P1)

A player orbits the sky with two fingers within bounds to see depth and returns to the authored view; the view never
changes the game.

**Independent Test**: orbit stays within bounds at every aspect, the scene stays inside the view, the digest never
changes.

### User Story 5 - Every move without gestures (Priority: P1)

A player who cannot touch precisely can do everything through the labelled panel (planet − and +, phase − and + with
"Set phase", tick − and +, run, undo, redo, next level, "Reset view"), including winning every certified level.

**Independent Test**: all 100 certified witnesses are replayed through panel actions on the host and win.

### Edge Cases

- **A touch that never moves far enough:** a tap is below 10 points and lifted within 0.5 s; a press lifted at 0.5 s
  or later without moving does nothing; two taps on empty space within 0.35 s and 22 points reset the view.
- **A touch that moves 10 … 16 points:** neither a tap nor a drag; nothing changes.
- **A planet hidden by a nearer planet:** the front-most planet under the finger is picked, as drawn.
- **A phase change the kernel refuses** (no action left, the stage): sent; the refusal is logged and shown with its
  reason code.
- **A finished play (won or failed):** gestures send no kernel action (taps still choose and the time dial still shows
  ticks) and the description says the play is over (undo or next level); orbit still works.
- **A second finger during a gesture:** cancels it (nothing sent) and starts an orbit.
- **A cancelled touch:** a previewed phase drag clears and nothing is sent.
- **Very small or very wide views:** picking, the time dial and orbit work at every supported aspect.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G1704-001**: A drag that starts on a movable planet while playing MUST preview the orbit position nearest the
  finger and, on release at a position other than the current one, send exactly one phase change to it; any other
  release MUST send nothing.
- **FR-R02G1704-002**: A tap on a planet MUST choose it (presentation only) in any stage.
- **FR-R02G1704-003**: A drag along the timeline (the time dial) or a tap on it MUST show the tick under the finger
  (presentation only) in any stage and MUST send no kernel action.
- **FR-R02G1704-004**: The phase preview MUST be presentation only: the planet's ghost at the previewed position and
  the predicted timeline of the previewed phases, never entering the digest, the snapshot's game state or the kernel.
- **FR-R02G1704-005**: Picking MUST be analytic and deterministic: each planet's projected disc through the drawn
  camera (orbit included), grown by a fixed margin, the front-most (drawn last) first; the timeline has its own
  projected region; anything else is empty space.
- **FR-R02G1704-006**: Two-finger orbit MUST stay within fixed yaw and pitch bounds, keep the scene inside the view with
  a 5 % margin at every aspect 0.4 … 2.5 and never enter the digest, the snapshot's game state or the kernel; a double
  tap on empty space or "Reset view" returns to the authored view.
- **FR-R02G1704-007**: Gestures on a finished play, cancelled touches and second fingers MUST send no kernel action.
- **FR-R02G1704-008**: The panel MUST keep every action available without gestures and gain "Reset view" and "Set
  phase" (phase − and + move a previewed pending offset; "Set phase" commits it as one action); every certified witness
  MUST be replayable through panel actions within its budget.
- **FR-R02G1704-009**: Gestures MUST be tested on the host by scripted pointer sequences and on the simulator through
  the experience's pointer entry; existing tests pass; every new public name is documented; refusals are logged with
  their reason code. Undo and redo stay the kernel's exact undo and redo through the panel.

### Key Entities

- **Gesture controller**: its state (idle, planet press, planet drag, dial drag, empty press, orbiting, cancelled), the
  touched target, the start and last points, the press time and the last tap's time and place.
- **Orbit**: yaw and pitch offsets from the authored view.
- **Phase preview**: the dragged planet, the previewed offset and the predicted timeline of the previewed phases.
- **Gesture action**: choosePlanet, showTick, setPhase, preview, clearPreview, resetView, explain; setPhase and the
  choices map onto the declared adapter controls `orbit.phase`, `orbit.choose` and `clock.show`.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G1704-001**: For 500 seeded scripted taps and drags on certified levels at several sizes and orbits, the
  actions and choices equal an independent computation.
- **SC-R02G1704-002**: Second fingers, cancels and gestures on a finished play send no kernel action in every scripted
  case.
- **SC-R02G1704-003**: Orbit and the phase preview never change the digest in every scripted case.
- **SC-R02G1704-004**: At every orbit within bounds and every aspect 0.4 … 2.5 the scene stays inside the view with a
  5 % margin.
- **SC-R02G1704-005**: All 100 certified levels are won through panel actions alone.
- **SC-R02G1704-006**: Existing tests pass; the reference regression passes 7 of 7; each test under 10 seconds.
- **SC-R02G1704-007** {device}: after ImplementationLock-100, touch feel and latency are checked on D1/D2/D3.

## Assumptions

- Hints, failure explanations and progression come in R02-G17-05; announcements, haptics, sound and full accessibility
  in R02-G17-06; persistence in R02-G17-07. The snapshot schema stays 1 here (orbit, the choice, the shown tick and the
  preview are not saved).
- All gestures map onto the adapter's declared controls or onto presentation state; no new kernel action is added.
- Thresholds for taps, drags and double taps follow feature 454 (and 444) so every round-two game feels the same.
- "Drag orbital handles" is read as dragging a planet along its own ring; "rotate time dial" and "step through
  predicted eclipse timeline" as dragging or tapping the timeline below the sky (stepping also by the panel's tick − and
  + buttons).
- Original design: all interaction and drawing are original code; no third-party assets or copied game designs.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Drag orbital handles | FR-R02G1704-001, 004 |
| Rotate time dial, step through predicted eclipse timeline | FR-R02G1704-003 |
| Choose a planet | FR-R02G1704-002 |
| Gesture-to-world actions (analytic picking) | FR-R02G1704-005 |
| Camera behavior (orbit, reset) | FR-R02G1704-006 |
| Undo, accessible panel | FR-R02G1704-007, 008, 009 |

## Negative Requirements / Excluded scope

- No new kernel action, no saved orbit, tick or preview, no device run before ImplementationLock-100, no availability
  before X-R02-G17.
