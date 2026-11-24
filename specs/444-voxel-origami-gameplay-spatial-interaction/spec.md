# Feature Specification: R02-G15-04 — Voxel Origami: gameplay spatial interaction

**Feature Branch**: `444-voxel-origami-gameplay-spatial-interaction` (spec directory only; work on `main`)

**Created**: 2026-11-24

**Status**: Clarified

**Ledger gate**: R02-G15-04 (migration ledger, game feature of experience R02-G15) · ID namespace FR-R02G1504-###,
SC-R02G1504-###, T-R02G1504-###

**Input**: User description: the archived R02-G15-04 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Gameplay spatial interaction" for Voxel Origami ("Implement native gesture-to-world actions, undo and camera behavior";
player mechanic "reconfigure hinged voxels into a target solid without collisions"), with the canonical overrides of
ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/444-voxel-origami-gameplay-spatial-interaction`; FR-R02G1504-###,
  SC-R02G1504-###, T-R02G1504-###.
- **Packaging (ADR-0009):** the gestures live in the experience `r02-g15.voxel-origami` (a registered candidate since
  R02-G15-03) inside the one app; the source's `Apps/VoxelOrigami` and `Packages/GameModules` paths are superseded.
- **Superseded parts of the source prompt:** price, "no IAP" and the Round 2 lock. The source's "content count 88" is a
  milestone figure; the 100 certified levels of R02-G15-02 stand. **Device-only items:** touch feel and latency on
  D1/D2/D3, recorded as `{device}` tasks for after ImplementationLock-100. **Owner-only items:** none.
- **Shared features used:** R02-F14 (reversible history), R02-F22 (spatial controls and analytic picking), R02-F26
  (input and accessibility contract), the experience host's pointer events, and the kernel, content, adapter and
  renderer of R02-G15-01 … 03.
- **Model:** feature 434 (Moonlit Mechanism's gameplay spatial interaction) for the gesture controller, picker, orbit
  and panel, adapted to a chain of hinged cubes seen in three dimensions.

## Clarifications

### Session 2026-11-24

Answered autonomously under the owner's standing delegation, safest well-supported option each time, following feature
434's answers where the games agree. Facts checked in code (read-only, 2026-11-24): the host's `PointerEvent` (id,
phase began/moved/ended/cancelled, location in view points with the origin top-left, timestamp); feature 434's
thresholds (`MoonlitMechanismGestureController`: tap below 10 points and 0.5 s, drag from 16 points, double tap within
0.35 s and 22 points, orbit 90° per view width and 60° per view height) and orbit bounds (Moonlit yaw ±25°, pitch
−10° … +15°; Acoustic Constellator yaw ±35°, pitch −15° … +20°). Voxel Origami's adapter declares `hinge.turn`
[hinge, ±1], `play.undo`, `play.redo`, `level.next` and `hinge.choose` [hinge] (presentation only); hinge h twists the
subtree of cube h about the line from its parent to cube h, so cube h itself stays and only the cubes off that line
swing (`VoxelOrigamiLattice.swinging`); the kernel refuses a hinge with nothing to swing (`r02-g15.action`) and fails a
turn on a collision or a sweep. The scene (`VoxelOrigamiSceneGeometry`) draws cubes of side 0.9 s at w(cell) from eye
(1.4, 1.1, 2.6) towards (0, −0.1, 0), fitted to the box x −0.95 … 0.95, y −1.25 … 0.95, z −0.95 … 0.95, in painter's
order by distance with back faces culled.

- Q: How is a touch picked? → A: at touch-down every cube is projected through the drawn camera (orbit included) into
  view points; a cube is hit when the touch lies inside the convex outline of its eight projected corners (side 0.9 s)
  grown by 8 points; of several hits the front-most wins (the one drawn last: the nearest centre to the eye, then the
  higher index, as the paint order draws it). Anything else (the target wireframe, hinge marks, gauges, backdrop) is
  empty space; a touch on the root cube (cube 0, which has no hinge) picks the root. Tap, drag and double-tap thresholds
  are feature 434's. Impact: FR-R02G1504-001 … 003; SC-R02G1504-001.
- Q: How does a drag on a cube turn its hinge? → A: the controller predicts, for the touched cube h, the on-screen motion
  of the tracked cube — of the cubes hinge h swings, the one farthest from its hinge line (lowest index on ties), since
  the centroid of a subtree symmetric about the line would not move — for a `+1` and a `−1` quarter turn (its projected
  centre after the turn minus before, ignoring collisions); with the finger's travel d from touch-down, the pending step is the sign whose
  predicted motion has the larger projection d · û (û its unit direction), shown once that projection reaches 24 points
  (cleared if it falls back below). On release while playing, exactly one `hinge.turn [h, step]` is sent (one quarter
  turn per drag; a half turn is two drags); below 24 points nothing is sent. A drag on the root, on a cube whose hinge
  swings nothing, or in any stage other than playing previews nothing and sends nothing; the description says why (the
  root has no hinge; nothing would move; the play is over). Impact: FR-R02G1504-001; SC-R02G1504-001.
- Q: What do taps and double taps do? → A: a tap on a non-root cube sends `hinge.choose [h]` in any stage (presentation
  only, never an undo step); a tap on the root changes nothing. A second tap on the same non-root cube within 0.35 s and
  22 points while playing sends `hinge.turn [h, +1]` when that hinge can turn; otherwise it sends nothing and the
  description says nothing would move (the first tap chose it). A tap on empty space changes nothing; two such taps within 0.35 s and 22 points reset the view. On a won or failed
  play no kernel action is sent (taps choose, orbit works) and the description says the play is over (undo or next
  level). Impact: FR-R02G1504-002, 005; SC-R02G1504-002.
- Q: How do two fingers behave and how far may the view turn? → A: as feature 434: a second finger cancels any
  one-finger gesture (nothing sent) and orbits — yaw ±60° about the vertical axis through the authored box centre (90°
  per view width) and pitch −20° … +35° (60° per view height), wider than 434's because the solid must be seen from its
  sides and above; a third finger re-bases the midpoint; a double tap on empty space or "Reset view" returns to the
  authored view (orbit 0, 0); the camera refits so the authored box stays inside the view with a 5 % margin at every
  orbit and aspect 0.4 … 2.5, and the eye stays outside the box. The meshes face the drawn eye (billboards, paint order,
  culling), so they are rebuilt when the orbit changes. Orbit is not saved (schema stays 1). Impact: FR-R02G1504-004;
  SC-R02G1504-003, 004.
- Q: How is it built and tested? → A: a Core gesture controller (`VoxelOrigamiGestureController`) with a picker
  (`VoxelOrigamiPicker`) and an orbit (`VoxelOrigamiOrbit`, with `camera(_:aspect:orbit:)` equal to the authored camera
  at orbit 0) takes pointer events with the view size, the drawn snapshot and the orbit and returns gesture actions
  (chooseHinge, pendingTurn, turn, clearPending, resetView, explain) and the orbit; host tests feed 500 seeded taps and
  drags on certified levels at several sizes and orbits against an independent pick and prediction in the test;
  simulator tests send touches through the experience's pointer entry; a host test wins all 100 certified levels through
  panel actions alone. Impact: FR-R02G1504-003, 006, 007; SC-R02G1504-001 … 005.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Turn a hinge by dragging its cube (Priority: P1) 🎯

A player puts a finger on a cube and drags it the way the cube should swing: while dragging, the pending quarter turn
of that cube's hinge is shown; on release the hinge turns that way, one action per quarter turn.

**Why this priority**: turning hinges is the game's only move; the chain folds only when a hinge turns.

**Independent Test**: scripted drags send exactly the hinge, the number and the sign of quarter turns an independent
computation predicts from the finger's travel and the drawn chain.

**Acceptance Scenarios**:

1. **Given** a level while playing, **When** the player drags a turnable cube 24 points or more in the direction a `+1`
   quarter turn of its hinge moves the swinging cubes on screen and lifts, **Then** exactly one `+1` turn of that cube's
   hinge is sent.
2. **Given** the same drag in the opposite direction, **When** it lifts, **Then** exactly one `−1` turn is sent.
3. **Given** a drag shorter than the turn threshold, **When** it lifts, **Then** nothing is sent.
4. **Given** a drag on the root cube or on a cube whose hinge cannot turn, **When** it lifts, **Then** nothing is sent
   and the description says why.

### User Story 2 - Choose and turn a hinge with taps (Priority: P1)

A player taps a cube to choose its hinge in the panel and double-taps a cube to turn its hinge a quarter turn forward
(one action).

**Why this priority**: taps are the precise way to pick a hinge in a folded chain.

**Independent Test**: scripted taps and double taps choose and turn exactly what an independent pick predicts.

**Acceptance Scenarios**:

1. **Given** any stage, **When** the player taps a non-root cube, **Then** its hinge becomes the chosen hinge and no
   kernel action is sent.
2. **Given** a level while playing, **When** the player double-taps a turnable cube, **Then** exactly one `+1` turn of
   its hinge is sent.

### User Story 3 - Look around the solid and come back (Priority: P1)

A player orbits the chain and its target with two fingers within bounds to see hidden cubes, and returns to the
authored view; the view never changes the game.

**Why this priority**: in three dimensions a folded chain hides cubes; seeing behind them is needed to plan a turn.

**Independent Test**: orbit stays within bounds at every aspect, the scene stays inside the view, and the digest never
changes.

### User Story 4 - Every move without gestures (Priority: P1)

A player who cannot touch precisely can do everything through the labelled panel (hinge − and +, turn − and +, undo,
redo, next level, "Reset view"), including winning every certified level.

**Independent Test**: all 100 certified witnesses are replayed through panel actions on the host and win.

### Edge Cases

- **A touch that never moves far enough:** a tap (below 10 points, lifted within 0.5 s); two taps on the same cube within
  0.35 s and 22 points are a double tap; two such taps on empty space reset the view; a press lifted at 0.5 s or later
  without moving does nothing.
- **A touch that moves 10 … 16 points:** neither a tap nor a drag; nothing changes.
- **A drag that comes back:** the pending turn follows the finger and clears when the projection falls below 24 points;
  only the state at release counts.
- **A drag on a cube that the nearer cube hides:** the front-most cube under the finger is picked, as drawn.
- **A drag on the root or on a hinge that swings nothing:** nothing is sent; the description says why.
- **A turn the kernel refuses or fails** (a collision, a sweep, the budget, the stage): sent; a refusal is logged and
  shown with its reason code, a failure ends the level as the kernel decides.
- **A finished play (won or failed):** gestures send no kernel action (a tap only chooses the hinge) and the description
  says the play is over (undo or next level); orbit still works.
- **A second finger during a gesture:** cancels it (nothing sent) and starts an orbit.
- **A cancelled touch:** changes nothing; a pending turn shown by a cancelled drag (cancelled touch or second finger) is
  cleared and nothing is sent.
- **Very small or very wide views:** picking and orbit work at every supported aspect.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G1504-001**: A drag that starts on a turnable non-root cube h while playing MUST show the pending step (the
  sign whose predicted on-screen motion of the tracked cube (the swinging cube farthest from the hinge line) has the larger projection of the
  finger's travel) once that projection reaches 24 points and, on release, MUST send exactly one `hinge.turn [h, step]`;
  below 24 points, on the root, on a hinge that swings nothing or outside playing it MUST send nothing.
- **FR-R02G1504-002**: A tap on a non-root cube MUST choose its hinge through `hinge.choose` (presentation only) in any
  stage; a double tap on a turnable cube while playing (within 0.35 s and 22 points) MUST send exactly one `+1` turn of
  its hinge.
- **FR-R02G1504-003**: Picking MUST be analytic and deterministic: the convex outline of each cube's eight corners
  projected through the drawn camera (orbit included), grown by 8 points, the front-most (drawn last) first; anything
  else is empty space.
- **FR-R02G1504-004**: Two-finger orbit MUST stay within yaw ±60° and pitch −20° … +35°, keep the scene inside the view with a 5 % margin
  at every aspect 0.4 … 2.5 and never enter the digest, the snapshot's game state or the kernel; a double tap on empty
  space or "Reset view" returns to the authored view.
- **FR-R02G1504-005**: Gestures on a finished play, cancelled touches and second fingers MUST send no kernel action.
- **FR-R02G1504-006**: The panel MUST keep every action available without gestures and gain "Reset view"; every
  certified witness MUST be replayable through panel actions.
- **FR-R02G1504-007**: Gestures MUST be tested on the host by scripted pointer sequences and on the simulator through
  the experience's pointer entry; existing tests pass; every new public name is documented; refusals are logged with
  their reason code (observability). Undo and redo stay the kernel's exact undo and redo through the panel.

### Key Entities

- **Gesture controller**: its state (idle, cube press, cube drag, empty press, orbiting, cancelled), the touched cube,
  the start and last points, the pending step, the press time and the last tap's time, place and target.
- **Orbit**: yaw and pitch offsets from the authored view.
- **Gesture action**: chooseHinge, pendingTurn, turn, clearPending, resetView, explain; turn and chooseHinge map onto
  the declared adapter controls `hinge.turn` and `hinge.choose`.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G1504-001**: For 500 seeded scripted taps and drags on certified levels at several sizes and orbits, the
  actions and choices equal an independent computation.
- **SC-R02G1504-002**: Second fingers, cancels and gestures on a finished play send no kernel action in every scripted
  case.
- **SC-R02G1504-003**: Orbit never changes the digest in every scripted case.
- **SC-R02G1504-004**: At every orbit within bounds and every aspect 0.4 … 2.5 the scene stays inside the view with a 5 %
  margin.
- **SC-R02G1504-005**: All 100 certified levels are won through panel actions alone.
- **SC-R02G1504-006**: Existing tests pass; the reference regression passes 7 of 7; each test under 10 seconds.
- **SC-R02G1504-007** {device}: after ImplementationLock-100, touch feel and latency are checked on D1/D2/D3.

## Assumptions

- Hints, failure explanations and progression come in R02-G15-05; announcements, haptics, sound and full accessibility
  in R02-G15-06; persistence in R02-G15-07. The snapshot schema stays 1 here (orbit, the chosen hinge and the pending
  turn are not saved).
- All gestures map onto the adapter's declared controls or onto presentation state; no new kernel action is added.
- Thresholds for taps, drags and double taps follow feature 434 (and 424) so every round-two game feels the same.
- Original design: all interaction and drawing are original code; no third-party assets or copied game designs.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Reconfigure hinged voxels (gesture-to-world turn) | FR-R02G1504-001, 002 |
| Gesture-to-world actions (analytic picking) | FR-R02G1504-003 |
| Camera behavior (orbit, reset) | FR-R02G1504-004 |
| Undo, accessible panel | FR-R02G1504-005, 006, 007 |
