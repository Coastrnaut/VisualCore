# Feature Specification: R02-G15-04 — Voxel Origami: gameplay spatial interaction

**Feature Branch**: `444-voxel-origami-gameplay-spatial-interaction` (spec directory only; work on `main`)

**Created**: 2026-11-24

**Status**: Draft

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

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Turn a hinge by dragging its cube (Priority: P1) 🎯

A player puts a finger on a cube and drags it the way the cube should swing: while dragging, the pending quarter turn
of that cube's hinge is shown; on release the hinge turns that way, one action per quarter turn.

**Why this priority**: turning hinges is the game's only move; the chain folds only when a hinge turns.

**Independent Test**: scripted drags send exactly the hinge, the number and the sign of quarter turns an independent
computation predicts from the finger's travel and the drawn chain.

**Acceptance Scenarios**:

1. **Given** a level while playing, **When** the player drags a turnable cube far enough in the direction its +1 quarter
   turn moves it on screen and lifts, **Then** exactly one `+1` turn of that cube's hinge is sent.
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

- **A touch that never moves far enough:** a short, quick touch is a tap; two taps on the same cube close in time and
  place are a double tap; two such taps on empty space reset the view; a long press without movement does nothing.
- **A touch between a tap and a drag:** nothing changes.
- **A drag on a cube that the nearer cube hides:** the front-most cube under the finger is picked, as drawn.
- **A turn the kernel refuses or fails** (a collision, a sweep, the budget, the stage): sent; a refusal is logged and
  shown with its reason code, a failure ends the level as the kernel decides.
- **A finished play (won or failed):** gestures send no kernel action (a tap only chooses the hinge) and the description
  says the play is over (undo or next level); orbit still works.
- **A second finger during a gesture:** cancels it (nothing sent) and starts an orbit.
- **A cancelled touch:** changes nothing.
- **Very small or very wide views:** picking and orbit work at every supported aspect.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G1504-001**: A drag that starts on a turnable non-root cube while playing MUST show the pending turn and, on
  release, MUST send that cube's hinge turned by the step whose on-screen motion of the cube best matches the finger's
  travel, through the declared turn control; a drag below the threshold MUST send nothing.
- **FR-R02G1504-002**: A tap on a non-root cube MUST choose its hinge (no kernel action) in any stage; a double tap on a
  turnable cube while playing MUST send exactly one `+1` turn of its hinge.
- **FR-R02G1504-003**: Picking MUST be analytic and deterministic: the cubes projected through the drawn camera (orbit
  included), the front-most first, each with a stated touch target; anything else is empty space.
- **FR-R02G1504-004**: Two-finger orbit MUST stay within stated bounds, keep the scene inside the view with a 5 % margin
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
  the start and last points, the press time and the last tap's time, place and target.
- **Orbit**: yaw and pitch offsets from the authored view.
- **Gesture action**: choose hinge, pending turn, turn, reset view; the turn and the choice map onto declared adapter
  controls.

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
