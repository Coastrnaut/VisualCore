# Feature Specification: R02-G18-04 — Apsides Workshop: gameplay spatial interaction

**Feature Branch**: `474-apsides-workshop-gameplay-spatial-interaction` (spec directory only; work on `main`)

**Created**: 2026-11-25

**Status**: Clarified

**Ledger gate**: R02-G18-04 (migration ledger, game feature of experience R02-G18) · ID namespace FR-R02G1804-###,
SC-R02G1804-###, T-R02G1804-###

**Input**: User description: the archived R02-G18-04 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Gameplay spatial interaction" for Apsides Workshop ("Implement native gesture-to-world actions, undo and camera
behavior"; player mechanic "tune orbital eccentricity to sweep precise regions of a miniature sky"; controls "drag
periapsis knob and semi-major axis, turn time crank, play orbit"), with the canonical overrides of ADR-0009 and
Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/474-apsides-workshop-gameplay-spatial-interaction`; FR-R02G1804-###,
  SC-R02G1804-###, T-R02G1804-###.
- **Packaging (ADR-0009):** the gestures live in the experience `r02-g18.apsides-workshop` (a registered candidate since
  R02-G18-03) inside the one app; the source's `Apps/ApsidesWorkshop` and `Packages/GameModules` paths are superseded.
- **Superseded parts of the source prompt:** price, "no IAP" and the Round 2 lock. The source's "content count 78" is a
  milestone figure; the 100 certified levels of R02-G18-02 stand. **Device-only items:** touch feel and latency on
  D1/D2/D3, recorded as `{device}` tasks for after ImplementationLock-100. **Owner-only items:** none.
- **Shared features used:** R02-F14 (reversible history), R02-F22 (spatial controls and analytic picking), R02-F26
  (input and accessibility contract), the experience host's pointer events, and the kernel, content, adapter and
  renderer of R02-G18-01 … 03.
- **Model:** feature 464 (Celestial Eclipse Lab's gameplay spatial interaction) for the gesture controller, picker,
  orbit and panel, adapted to an orbit tuned by its periapsis knob and its size.

## Clarifications

### Session 2026-11-25

Answered autonomously under the owner's standing delegation, safest well-supported option each time, following feature
464's answers where the games agree. Facts checked in code (read-only, 2026-11-25): the host's `PointerEvent` (id,
phase began/moved/ended/cancelled, location in view points with the origin top-left, timestamp); feature 464's
thresholds (tap below 10 points and 0.5 s, drag from 16 points, double tap within 0.35 s and 22 points, orbit 90° per
view width and 60° per view height, yaw ±60°, pitch −20° … +35°). Apsides Workshop's adapter declares
`orbit.periapsis` [k, d], `orbit.size` [a], `orbit.play`, `play.undo`, `play.redo`, `level.next` and `clock.show`
[tick] (the last presentation only). The scene (`ApsidesWorkshopSceneGeometry`) maps sky units by s = 0.9 / 16 384 in
the plane z = 0, draws the periapsis diamond (0.035 across) at P(0), the apoapsis square (0.03) at P(T/2), the orbiter
(radius 0.03) at P(shown tick) and the orbit ribbon through every position, from eye (0, −0.3, 3.6) towards
(0, −0.3, 0), fitted to x −1.0 … 1.0, y −1.65 … 1.0, in painter's order by kind (markers, planets, star, orbiter last).
The R02-G18-03 panel sends one tuning per ± press, so stepping to a far orbit could cost more actions than the budget.

- Q: How is a touch picked? → A: at touch-down the handles are projected through the drawn camera (orbit included) into
  view points: the orbiter is hit within its projected radius grown by 8 points, the apoapsis square (the size handle)
  and the periapsis diamond (the knob) within their projected half-size grown by 12 points (they are small); of several
  hits the one drawn last wins (orbiter, then the size handle, then the knob). The orbit loop is hit within 10 points of
  its projected chords. Anything else (planets, star, compass, wedges, gauges, bars, backdrop) is empty space. Tap,
  drag and double-tap thresholds are feature 464's. Impact: FR-R02G1804-005; SC-R02G1804-001.
- Q: What do taps do? → A: a tap on the orbiter or the orbit loop sends `clock.show [tick]` with the tick whose
  projected position is nearest to the finger (lower on ties) in any stage; a tap on the knob or the size handle sends
  nothing and explains in words that the handle is dragged; a tap on empty space changes nothing and two such taps
  within 0.35 s and 22 points reset the view. On a won or failed play no kernel action is sent (the time crank still
  shows ticks) and the description says the play is over (undo or next level). Impact: FR-R02G1804-003, 007;
  SC-R02G1804-002.
- Q: How do the knob and size drags map the finger to steps? → A: a press on a handle that moves 16 points or more while
  playing becomes a drag; the finger is cast onto the sky plane z = 0 through the drawn camera. Knob: the direction step
  is the nearest multiple of 15° of the point's angle around the star (d = round(angle / 15°) mod 24) (a point exactly
  at the star keeps the current direction) and the eccentricity step is k = round(20 − 20 r / a) clamped to 0 … 15, with
  r the point's distance in lattice units and a the current size (the periapsis lies at a(20 − k)/20). Size handle: a =
  round(20 R / (20 + k)) clamped to 8 … 48, with R the point's distance and k the current eccentricity step (the
  apoapsis lies at a(20 + k)/20). The pending orbit is previewed when it is valid: the presenter draws its kernel
  positions as a dashed ghost and the gauges show its readings (the snapshot gains `previewOrbit` and its positions and
  readings, none in the digest); an invalid pending orbit shows no ghost and says why ("the periapsis would dip into the
  star" or "the apoapsis would leave the sky"). On release exactly one `orbit.periapsis [k, d]` or `orbit.size [a]` is
  sent when the pending orbit is valid and differs from the current one, otherwise nothing; a release outside playing, a
  cancel or a second finger clears the preview and sends nothing. Impact: FR-R02G1804-001, 002, 004, 007;
  SC-R02G1804-001, 003.
- Q: How do the time crank and two fingers behave? → A: from touch-down on the orbiter, every move sets the tick whose
  projected position is nearest to the finger (lower on ties) and sends `clock.show [tick]` (never an undo step, never a
  kernel action). Two fingers as feature 464: a second finger cancels any one-finger gesture (nothing sent) and orbits —
  yaw ±60° about the vertical axis through the authored box centre (90° per view width), pitch −20° … +35° (60° per
  view height); a third finger re-bases the midpoint; a double tap on empty space or "Reset view" returns to orbit
  (0, 0); the camera refits so the authored box stays inside the view with a 5 % margin at every orbit and aspect 0.4 …
  2.5 and the eye stays outside the box; meshes are rebuilt when the orbit changes; orbit is not saved (schema stays 1).
  Impact: FR-R02G1804-003, 006; SC-R02G1804-002, 004.
- Q: How is it built and tested, and how does the panel stay within the budget? → A: a Core gesture controller
  (`ApsidesWorkshopGestureController`) with a picker (`ApsidesWorkshopPicker`) and a view orbit
  (`ApsidesWorkshopViewOrbit`, with `camera(aspect:orbit:)` equal to the authored camera at orbit 0) takes pointer
  events with the view size, the drawn snapshot and the orbit and returns gesture actions (tunePeriapsis, tuneSize,
  showTick, preview, clearPreview, resetView, explain) and the orbit; the geometry draws the ghost; host tests feed 500
  seeded taps, knob drags, size drags and crank drags on certified levels at several sizes and orbits against an
  independent pick in the test; simulator tests send touches through the experience's pointer entry. The panel's
  eccentricity, direction and size − and + no longer send a tuning each: they move a pending orbit (the same
  presentation-only preview as a drag; the direction wraps, the other steps clamp to their ranges), and new "Set
  periapsis" and "Set size" buttons send exactly one `orbit.periapsis [k, d]` or `orbit.size [a]` with the pending steps
  when they differ from the current orbit and the result is valid (the pending orbit follows the current orbit after any
  accepted action — a tuning, undo, redo, play or level change — and a drag's preview replaces it); a host test wins all
  100 certified levels through panel actions alone (pending steps, the Set buttons, Play), each within its budget.
  Impact: FR-R02G1804-005, 008, 009; SC-R02G1804-001 … 005.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Drag the periapsis knob (Priority: P1) 🎯

A player presses the periapsis marker (the knob) and drags it: the knob's direction from the star sets the periapsis
direction and its distance sets the eccentricity at the current size; while dragging, a ghost orbit and the gauges show
what the orbit would become. Lifting the finger sets the knob there (one action, undoable).

**Why this priority**: the knob is the game's main lever.

**Independent Test**: scripted drags send exactly the tuning an independent pick predicts, or nothing.

**Acceptance Scenarios**:

1. **Given** a level while playing, **When** the player drags the knob and lifts where the nearest steps differ from
   the current ones and give a valid orbit, **Then** exactly one periapsis tuning to those steps is sent.
2. **Given** a drag that lifts at the current steps, at steps that give no valid orbit, or outside playing, **When** it
   lifts, **Then** nothing is sent, the preview clears and the reason is given in words.

### User Story 2 - Drag the semi-major axis (Priority: P1)

A player presses the apoapsis marker (the size handle) and drags it along the orbit's major axis; its distance from the
star sets the size at the current eccentricity, with the same ghost preview, and lifting sets it (one action).

**Independent Test**: scripted drags send exactly the size tuning an independent pick predicts, or nothing.

### User Story 3 - Turn the time crank (Priority: P1)

A player drags the orbiter along its orbit (the time crank) to step the shown tick; tapping the orbit loop jumps the
orbiter to the nearest tick. The gauges and the rest of the picture stay those of the current orbit.

**Why this priority**: seeing where the orbiter is at each tick is how the player reads the sweep and the order.

**Independent Test**: scripted drags along the orbit show exactly the tick an independent computation predicts; no
kernel action is sent.

### User Story 4 - Look around the sky and come back (Priority: P1)

A player orbits the compass with two fingers within bounds to see depth and returns to the authored view; the view never
changes the game.

**Independent Test**: orbit stays within bounds at every aspect, the scene stays inside the view, the digest never
changes.

### User Story 5 - Every move without gestures (Priority: P1)

A player who cannot touch precisely can do everything through the labelled panel (eccentricity, direction and size − and
+ with "Set periapsis" and "Set size", tick − and +, play, undo, redo, next level, "Reset view"), including winning
every certified level.

**Independent Test**: all 100 certified witnesses are replayed through panel actions on the host and win.

### Edge Cases

- **A touch that never moves far enough:** a tap is below 10 points and lifted within 0.5 s; a press lifted at 0.5 s or
  later without moving does nothing; two taps on empty space within 0.35 s and 22 points reset the view.
- **A touch that moves 10 … 16 points:** neither a tap nor a drag; nothing changes.
- **Handles under each other** (a circular orbit's knob and handle are opposite; a planet over a marker): the handle
  drawn last is picked, as drawn.
- **A tuning the kernel refuses** (no action left, the stage): sent; the refusal is logged and shown with its reason
  code. A knob or size position that gives no valid orbit is never sent; the preview says why.
- **A finished play (won or failed):** gestures send no kernel action (the time crank still shows ticks) and the
  description says the play is over (undo or next level); orbit still works.
- **A second finger during a gesture:** cancels it (nothing sent) and starts an orbit.
- **A cancelled touch:** a previewed tuning clears and nothing is sent.
- **Very small or very wide views:** picking, the time crank and orbit work at every supported aspect.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G1804-001**: A drag that starts on the periapsis knob while playing MUST preview the nearest eccentricity and
  direction steps under the finger at the current size and, on release at steps other than the current ones that give a
  valid orbit, send exactly one periapsis tuning; any other release MUST send nothing.
- **FR-R02G1804-002**: A drag that starts on the size handle while playing MUST preview the nearest size under the
  finger at the current eccentricity and, on release at a size other than the current one that gives a valid orbit,
  send exactly one size tuning; any other release MUST send nothing.
- **FR-R02G1804-003**: A drag of the orbiter along the orbit (the time crank) or a tap on the orbit loop MUST show the
  tick nearest the finger (presentation only) in any stage and MUST send no kernel action.
- **FR-R02G1804-004**: The tuning preview MUST be presentation only: a ghost orbit at the previewed steps and the
  gauges' previewed readings, never entering the digest, the snapshot's game state or the kernel.
- **FR-R02G1804-005**: Picking MUST be analytic and deterministic: each handle's projected marker and the orbiter's
  projected disc through the drawn camera (orbit included), grown by a fixed margin, the one drawn last first; the
  orbit loop has its own projected band; anything else is empty space.
- **FR-R02G1804-006**: Two-finger orbit MUST stay within fixed yaw and pitch bounds, keep the scene inside the view with
  a 5 % margin at every aspect 0.4 … 2.5 and never enter the digest, the snapshot's game state or the kernel; a double
  tap on empty space or "Reset view" returns to the authored view.
- **FR-R02G1804-007**: Gestures on a finished play, cancelled touches and second fingers MUST send no kernel action.
- **FR-R02G1804-008**: The panel MUST keep every action available without gestures and gain "Reset view", "Set
  periapsis" and "Set size" (the − and + buttons move a pending orbit; each Set button commits it as one action); every
  certified witness MUST be replayable through panel actions within its budget.
- **FR-R02G1804-009**: Gestures MUST be tested on the host by scripted pointer sequences and on the simulator through
  the experience's pointer entry; existing tests pass; every new public name is documented; refusals are logged with
  their reason code. Undo and redo stay the kernel's exact undo and redo through the panel.

### Key Entities

- **Gesture controller**: its state (idle, knob press, knob drag, handle press, handle drag, orbiter press, crank drag,
  empty press, orbiting, cancelled), the touched target, the start and last points, the press time and the last tap's
  time and place.
- **Orbit**: yaw and pitch offsets from the authored view.
- **Tuning preview**: the lever dragged, the previewed steps, the ghost orbit's positions and the gauges' previewed
  readings, or the reason no valid orbit is there.
- **Gesture action**: tunePeriapsis, tuneSize, showTick, preview, clearPreview, resetView, explain; the tunings and the
  tick map onto the declared adapter controls `orbit.periapsis`, `orbit.size` and `clock.show`.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G1804-001**: For 500 seeded scripted taps and drags on certified levels at several sizes and orbits, the
  actions and ticks equal an independent computation.
- **SC-R02G1804-002**: Second fingers, cancels and gestures on a finished play send no kernel action in every scripted
  case.
- **SC-R02G1804-003**: Orbit and the tuning preview never change the digest in every scripted case.
- **SC-R02G1804-004**: At every orbit within bounds and every aspect 0.4 … 2.5 the scene stays inside the view with a
  5 % margin.
- **SC-R02G1804-005**: All 100 certified levels are won through panel actions alone.
- **SC-R02G1804-006**: Existing tests pass; the reference regression passes 7 of 7; each test under 10 seconds.
- **SC-R02G1804-007** {device}: after ImplementationLock-100, touch feel and latency are checked on D1/D2/D3.

## Assumptions

- Hints, failure explanations and progression come in R02-G18-05; announcements, haptics, sound and full accessibility
  in R02-G18-06; persistence in R02-G18-07. The snapshot schema stays 1 here (orbit, the shown tick and the preview are
  not saved).
- All gestures map onto the adapter's declared controls or onto presentation state; no new kernel action is added.
- Thresholds for taps, drags and double taps follow feature 464 (and 454) so every round-two game feels the same.
- "Drag periapsis knob" is read as dragging the periapsis marker (direction and eccentricity), "semi-major axis" as
  dragging the apoapsis marker (size), "turn time crank" as dragging the orbiter along its orbit, and "play orbit" as
  the panel's Play (a deliberate commitment, never a gesture side effect).
- Original design: all interaction and drawing are original code; no third-party assets or copied game designs.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Drag periapsis knob | FR-R02G1804-001, 004 |
| Drag semi-major axis | FR-R02G1804-002, 004 |
| Turn time crank | FR-R02G1804-003 |
| Gesture-to-world actions (analytic picking) | FR-R02G1804-005 |
| Camera behavior (orbit, reset) | FR-R02G1804-006 |
| Undo, accessible panel, play orbit | FR-R02G1804-007, 008, 009 |

## Negative Requirements / Excluded scope

- No new kernel action, no saved orbit, tick or preview, no device run before ImplementationLock-100, no availability
  before X-R02-G18.
