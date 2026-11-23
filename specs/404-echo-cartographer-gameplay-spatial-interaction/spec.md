# Feature Specification: R02-G11-04 — Echo Cartographer: gameplay spatial interaction

**Feature Branch**: `404-echo-cartographer-gameplay-spatial-interaction` (spec directory only; work on `main`)

**Created**: 2026-11-23

**Status**: Clarified

**Ledger gate**: R02-G11-04 (migration ledger, game feature of experience R02-G11) · ID namespace FR-R02G1104-###,
SC-R02G1104-###, T-R02G1104-###

**Input**: User description: the archived R02-G11-04 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Gameplay spatial interaction" for Echo Cartographer (controls "tap to emit pulse; triangulate via dragging markers;
rotate 3D camera"), with the canonical overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/404-echo-cartographer-gameplay-spatial-interaction`; FR-R02G1104-###,
  SC-R02G1104-###, T-R02G1104-###.
- **Packaging (ADR-0009):** the gestures live in the experience `r02-g11.echo-cartographer` (a registered candidate since
  R02-G11-03) inside the one app; the source's `Apps/EchoCartographer` and `Packages/GameModules` paths are superseded.
- **Superseded parts of the source prompt:** price, "no IAP" and the Round 2 lock. The source's "content count 90" is a
  milestone figure; the 100 certified levels of R02-G11-02 stand. **Device-only items:** touch feel and latency on
  D1/D2/D3, recorded as `{device}` tasks for after ImplementationLock-100. **Owner-only items:** none.
- **Shared features used:** R02-F14 (reversible history), R02-F22 (spatial controls and analytic picking), R02-F26
  (input and accessibility contract), the experience host's pointer events, and the kernel, content, adapter and
  renderer of R02-G11-01 … 03.
- **Model:** feature 394 (Backwards Aurora's gameplay spatial interaction) for the gesture controller, picker, orbit and
  panel.

## Clarifications

### Session 2026-11-23

Answered autonomously under the owner's standing delegation, safest well-supported option each time, following feature
394's answers where the games agree. Facts checked in code (read-only, 2026-11-23): Backwards Aurora's feature 394
solved the same problem with a host-tested gesture controller in its Core taking `PointerEvent`s (id, phase
began/moved/ended/cancelled, location in view points with the origin top-left, timestamp) with the view size, the drawn
snapshot and orbit, an analytic picker and a clamped orbit; tap below 10 points and 0.5 s, drag from 16 points, double
tap within 0.35 s and 22 points, orbit 90° per view width and 60° per view height; Echo Cartographer's camera
(`EchoCartographerSceneGeometry.camera(_:aspect:)`) looks from above and in front at the box x −1 … 1, z −1 … 1.1,
y 0 … 0.8; cell (x, y) is centred at X = (x + 0.5 − W / 2)·s, Z = (y + 0.5 − H / 2)·s on y = 0; the adapter accepts
`cell.pulse`, `cell.claim`, `cell.mark` [x, y], `play.undo`, `play.redo` and `level.next`; the panel's cursor is
presentation state.

- Q: How is a touch picked? → A: at touch-down the touch ray through the drawn camera meets the floor plane y = 0 at
  (X, Z). In this order: a marker (its ring centre projected within 22 points of the touch; the nearest first, ties to
  the lower cell index), then the cell whose square contains (X, Z) inside the chamber; anything else is empty space. A
  tap is a touch that moves less than 10 points and lifts within 0.5 s; a drag moves at least 16 points; 10 … 16 points
  is neither. Impact: FR-R02G1104-001, 004; SC-R02G1104-001.
- Q: What do taps do? → A: a tap on a cell known open sends `cell.pulse [x, y]` while playing; a tap on any other cell
  of the chamber (unknown or known wall) moves the cursor there and sends nothing; a tap on a marker's cell counts as a
  tap on that cell; a tap on empty space changes nothing, and two such taps within 0.35 s and 22 points reset the view.
  Impact: FR-R02G1104-001, 005; SC-R02G1104-001.
- Q: What do drags and held presses do? → A: a drag that starts on a marker moves it: on release over a cell of the
  chamber other than its own that has no marker, it sends `cell.mark` on the old cell (removing it) and then
  `cell.mark` on the new cell (adding it); over its own cell, a marked cell or empty space it sends nothing. A drag that
  starts on a cell without a marker places one: on release over a cell of the chamber without a marker it sends
  `cell.mark` there (the kernel refuses a ninth marker); otherwise nothing. A press held 0.5 s without moving 10 points
  arms a claim; lifting it sends `cell.claim [x, y]` for the held cell while playing; moving 10 points after it armed
  cancels it and nothing is sent. The cursor follows every placed, moved or claimed cell. Impact: FR-R02G1104-002, 003;
  SC-R02G1104-001.
- Q: How do two fingers behave, and what happens on a finished play? → A: a second finger cancels any one-finger
  gesture (nothing sent) and orbits: yaw ±35° about the y axis (90° per view width), pitch −15° … +20° (60° per view
  height) about the authored view; a third finger re-bases the midpoint; a double tap on empty space or "Reset view"
  returns to the authored view. The camera distance refits so the authored box stays inside the view with a 5 % margin
  at every orbit and aspect 0.4 … 2.5. Orbit is presentation only: not saved, so the snapshot schema stays 1. On a won,
  failed or result stage taps, drags and held presses send nothing and the description says the play is over (undo or
  next level); the cursor and orbit still work. A pulse, claim or mark the kernel refuses is refused by the adapter with
  its reason code, which the presenter logs and shows. Impact: FR-R02G1104-005, 007; SC-R02G1104-002, 004.
- Q: How is everything tested? → A: the Core gesture controller (`EchoCartographerGestureController`) with a picker
  (`EchoCartographerPicker`) takes pointer events with the view size, the drawn snapshot, the orbit and the cursor and
  returns the gesture actions (pulse, claim, mark, moveCursor, resetView) and the orbit; host tests feed 500 seeded taps,
  drags and held presses on certified levels at several sizes and orbits and compare with an independent pick computed
  in the test; simulator tests send the same touches through the experience's pointer entry; a host test wins all 100
  certified levels through panel actions alone (cursor steppers, pulse, claim). Impact: FR-R02G1104-006, 007;
  SC-R02G1104-001 … 005.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Tap to send a pulse (Priority: P1) 🎯

A player taps a floor cell they already know is open; a pulse goes out from it. Tapping any other cell inside the
chamber moves the panel's cursor there without sending anything.

**Why this priority**: pulsing is the game's first move.

**Independent Test**: scripted taps on cells of certified levels send exactly one pulse from known-open cells and move
the cursor on other cells, as an independent pick predicts.

**Acceptance Scenarios**:

1. **Given** a level while playing, **When** the player taps a known-open cell, **Then** exactly one pulse from that
   cell is sent.
2. **Given** a tap on an unknown or wall cell, **When** it lifts, **Then** the cursor moves to that cell and nothing is
   sent; a tap outside the chamber changes nothing.

### User Story 2 - Drag markers to triangulate (Priority: P1)

A player drags from a cell to place a marker where the finger lifts, and drags an existing marker to move it; markers
help reason about where the beacons must be.

**Why this priority**: the catalog names dragging markers as the triangulation control.

**Independent Test**: scripted drags place or move exactly one marker as an independent pick predicts.

### User Story 3 - Hold to claim a beacon (Priority: P1)

A player presses and holds on a cell where they believe a beacon is; lifting the held press claims it.

**Independent Test**: scripted held presses send exactly one claim of the held cell.

### User Story 4 - Look around and come back (Priority: P2)

A player orbits the chamber with two fingers within bounds and returns to the authored view; the view never changes the
game.

**Independent Test**: orbit stays within bounds at every aspect, the scene stays inside the view, and the digest never
changes.

### User Story 5 - Every move without gestures (Priority: P1)

A player who cannot tap precisely can do everything through the labelled panel (column and row steppers, pulse, claim,
mark, undo, redo, next level, "Reset view"), including winning every certified level.

**Independent Test**: all 100 certified witnesses are replayed through panel actions on the host and win.

### Edge Cases

- **A touch that never moves far enough:** a tap; two taps on empty space outside the chamber within 0.35 s and 22
  points reset the view.
- **A touch that moves 10 … 16 points:** neither a tap nor a drag; nothing changes.
- **A finished play (won, failed or showing the result):** gestures send nothing and the description says the play is
  over (undo or next level); the cursor and orbit still work.
- **A pulse or claim the kernel refuses:** sent and refused with its reason, shown to the player.
- **A second finger during a gesture:** cancels it (nothing sent) and starts an orbit.
- **A cancelled touch:** changes nothing.
- **A held press that then moves:** after the hold, moving 10 points cancels it; nothing is sent.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G1104-001**: A tap on a known-open cell while playing MUST send exactly one pulse from it; a tap on another cell
  inside the chamber MUST move the cursor (presentation state) and send nothing; a tap outside MUST change nothing.
- **FR-R02G1104-002**: A drag MUST place a marker at the release cell, or move a dragged marker there, through the
  declared mark control, and nothing else.
- **FR-R02G1104-003**: A press held without moving and then lifted MUST send exactly one claim of the held cell.
- **FR-R02G1104-004**: Picking MUST be analytic and deterministic: the touch ray through the drawn camera against the
  floor plane, with a minimum touch target for markers.
- **FR-R02G1104-005**: Two-finger orbit MUST stay within stated bounds, keep the scene inside the view with a 5 % margin
  at every aspect 0.4 … 2.5 and never enter the digest, the snapshot or the kernel; a double tap on empty space or
  "Reset view" returns to the authored view.
- **FR-R02G1104-006**: The panel MUST keep every action available without gestures and gain "Reset view"; every
  certified witness MUST be replayable through panel actions.
- **FR-R02G1104-007**: Gestures MUST be tested on the host by scripted pointer sequences and on the simulator through the
  experience's pointer entry; existing tests pass; every new public name is documented; refusals are logged with their
  reason code (observability).

### Key Entities

- **Gesture controller**: state (idle, cell press, marker drag, cell drag, held press, orbiting, cancelled), the touched
  cell or marker, the start and last points, the press time, the last tap time and place.
- **Orbit**: yaw and pitch offsets from the authored view.
- **Gesture action**: pulse, claim, mark, moveCursor, resetView; pulse, claim and mark map onto declared kernel
  controls.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G1104-001**: For 500 seeded scripted taps, drags and held presses on certified levels at several sizes and
  orbits, the actions and cursor changes equal an independent computation.
- **SC-R02G1104-002**: Second fingers, cancels and gestures on a finished play send no action in every scripted case.
- **SC-R02G1104-003**: Orbit never changes the digest in every scripted case.
- **SC-R02G1104-004**: At every orbit within bounds and every aspect 0.4 … 2.5 the scene stays inside the view with a 5 %
  margin.
- **SC-R02G1104-005**: All 100 certified levels are won through panel actions alone.
- **SC-R02G1104-006**: Existing tests pass; the reference regression passes 7 of 7; each test under 10 seconds.
- **SC-R02G1104-007** {device}: after ImplementationLock-100, touch feel and latency are checked on D1/D2/D3.

## Assumptions

- Hints, failure explanations and progression come in R02-G11-05; announcements, haptics and full accessibility in
  R02-G11-06; persistence in R02-G11-07. The snapshot schema stays 1 here (orbit and cursor are not saved).
- All gestures map onto the adapter's declared controls or onto presentation state; no new kernel action is added.
- Original design: all interaction and drawing are original code; no third-party assets or copied game designs.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Tap to emit pulse | FR-R02G1104-001 |
| Triangulate via dragging markers | FR-R02G1104-002 |
| Rotate 3D camera (constrained orbit, reset) | FR-R02G1104-005 |
| Gesture arbitration with accessible stepper controls | FR-R02G1104-003, 006 |
| Camera motion must not change puzzle semantics | FR-R02G1104-005; SC-R02G1104-003 |

## Negative Requirements / Excluded scope

- No new kernel action, no free camera navigation, no device run before ImplementationLock-100, no availability before
  X-R02-G11.
