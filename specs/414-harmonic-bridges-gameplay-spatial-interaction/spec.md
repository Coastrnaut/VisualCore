# Feature Specification: R02-G12-04 — Harmonic Bridges: gameplay spatial interaction

**Feature Branch**: `414-harmonic-bridges-gameplay-spatial-interaction` (spec directory only; work on `main`)

**Created**: 2026-11-23

**Status**: Clarified

**Ledger gate**: R02-G12-04 (migration ledger, game feature of experience R02-G12) · ID namespace FR-R02G1204-###,
SC-R02G1204-###, T-R02G1204-###

**Input**: User description: the archived R02-G12-04 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Gameplay spatial interaction" for Harmonic Bridges ("Implement native gesture-to-world actions, undo and camera
behavior"; catalog controls "pluck to audition frequency, drag tuning peg, tap freeze to test walkway"), with the
canonical overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/414-harmonic-bridges-gameplay-spatial-interaction`; FR-R02G1204-###,
  SC-R02G1204-###, T-R02G1204-###.
- **Packaging (ADR-0009):** the gestures live in the experience `r02-g12.harmonic-bridges` (a registered candidate since
  R02-G12-03) inside the one app; the source's `Apps/HarmonicBridges` and `Packages/GameModules` paths are superseded.
- **Superseded parts of the source prompt:** price, "no IAP" and the Round 2 lock. The source's "content count 82" is a
  milestone figure; the 100 certified levels of R02-G12-02 stand. **Device-only items:** touch feel and latency on
  D1/D2/D3, recorded as `{device}` tasks for after ImplementationLock-100. **Owner-only items:** none.
- **Shared features used:** R02-F14 (reversible history), R02-F22 (spatial controls and analytic picking), R02-F26
  (input and accessibility contract), the experience host's pointer events, and the kernel, content, adapter and
  renderer of R02-G12-01 … 03.
- **Model:** feature 404 (Echo Cartographer's gameplay spatial interaction) for the gesture controller, picker, orbit
  and panel.

## Clarifications

### Session 2026-11-23

Answered autonomously under the owner's standing delegation, safest well-supported option each time, following feature
404's answers where the games agree. Facts checked in code (read-only, 2026-11-23): Echo Cartographer's feature 404
solved the same problem with a host-tested gesture controller in its Core taking `PointerEvent`s (id, phase
began/moved/ended/cancelled, location in view points with the origin top-left, timestamp) with the view size, the drawn
snapshot and orbit, an analytic picker and a clamped orbit; tap below 10 points and 0.5 s, drag from 16 points, double
tap within 0.35 s and 22 points, orbit 90° per view width and 60° per view height. Harmonic Bridges' camera
(`HarmonicBridgesSceneGeometry`) looks from eye (0, 1.9, 1.6) towards (0, 0, 0.1) at the box x −1 … 1, z −0.7 … 1.0,
y 0 … 0.2; island (gx, gy) is at X = (gx − 7.5)·0.12, Z = (gy − 4.5)·0.12 with its top centre at y = 0.1; strings run
between island top centres at y = 0.1; the step pips are squares 0.06 wide at z = 0.8, y = 0 across x −0.3 … 0.3; the
adapter accepts `string.tune` [string, peg], `crossing.test`, `play.undo`, `play.redo` and `level.next`; the panel's
chosen string and peg are presentation state.

- Q: How is a touch picked? → A: at touch-down, every target is projected through the drawn camera (orbit included)
  into view points. In this order: a step pip (its centre within 22 points of the touch; the nearest first, ties to the
  lower step), then the goal island (its top centre within 22 points), then a string (the shortest distance from the
  touch to the projected segment between its islands' top centres within 22 points; the nearest first, ties to the lower
  string index); anything else, other islands included, is empty space. A tap is a touch that moves less than 10 points
  and lifts within 0.5 s; a drag moves at least 16 points; 10 … 16 points is neither, and a press lifted at 0.5 s or later
  without moving is neither. Impact: FR-R02G1204-001, 003, 004; SC-R02G1204-001.
- Q: What do taps do? → A: a tap on a string chooses it at its current peg (presentation state, in any stage) and the
  description names the string, the modes it sings in the shown step and how many of its five samples reach the
  threshold; no action is sent. A tap on a pip or on the goal island sends `crossing.test` while playing. A tap on empty
  space changes nothing, and two such taps within 0.35 s and 22 points reset the view. Impact: FR-R02G1204-001, 003,
  005; SC-R02G1204-001.
- Q: How does dragging a peg work? → A: a drag that starts on a string retunes it: the previewed peg is the string's
  current peg plus the upward movement since touch-down divided by 24 points, rounded to the nearest whole number
  (halves away from zero) and clamped to 1 … 12; the chosen string and peg follow the preview. On release while playing
  it sends `string.tune [string, peg]` when the string is unlocked and the previewed peg differs from the current one;
  otherwise nothing, and for a locked string the description says it is locked. A drag from a locked string, or any
  drag on a stage other than playing, chooses the string at its current peg and previews nothing. A drag that starts on
  a pip, the goal or empty space sends nothing. Impact: FR-R02G1204-002; SC-R02G1204-001.
- Q: How do two fingers behave, and what happens on a finished play? → A: as feature 404: a second finger cancels any
  one-finger gesture (nothing sent) and orbits: yaw ±35° about the y axis (90° per view width), pitch −15° … +20° (60°
  per view height) about the authored view; a third finger re-bases the midpoint; a double tap on empty space or "Reset
  view" returns to the authored view. The camera refits its field of view so the authored box stays inside the view with
  a 5 % margin at every orbit and aspect 0.4 … 2.5. Orbit is presentation only: not saved, so the snapshot schema stays
  1. Gestures send kernel actions only while playing; on a won or failed play tuning drags and test taps send nothing
  and the description says the play is over (undo or next level); plucking (choosing) and orbit still work. A tuning or
  test the kernel refuses is refused by the adapter with its reason code, which the presenter logs and shows. Impact:
  FR-R02G1204-005, 007; SC-R02G1204-002, 004.
- Q: How is everything tested? → A: the Core gesture controller (`HarmonicBridgesGestureController`) with a picker
  (`HarmonicBridgesPicker`) takes pointer events with the view size, the drawn snapshot, the orbit and the chosen string
  and returns the gesture actions (choose, preview, tune, test, resetView) and the orbit; host tests feed 500 seeded taps
  and drags on certified levels at several sizes and orbits and compare with an independent pick computed in the test;
  simulator tests send the same touches through the experience's pointer entry; a host test wins all 100 certified
  levels through panel actions alone (string and peg steppers, tune, test). Impact: FR-R02G1204-006, 007;
  SC-R02G1204-001 … 005.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Pluck a string to audition it (Priority: P1) 🎯

A player taps a string; it becomes the panel's chosen string at its current peg and its resonance in the shown step is
described (the modes it sings and whether its samples reach the threshold), without spending an action.

**Why this priority**: choosing and hearing a string is how every tuning starts; it must cost nothing.

**Independent Test**: scripted taps on strings of certified levels choose exactly the string an independent pick
predicts and send no kernel action.

**Acceptance Scenarios**:

1. **Given** a level while playing, **When** the player taps a string, **Then** that string becomes the chosen string
   at its current peg and no action is spent.
2. **Given** a tap away from every string, island and pip, **When** it lifts, **Then** nothing changes.

### User Story 2 - Drag a tuning peg (Priority: P1)

A player drags from a string to retune it: the peg previewed follows the drag in whole steps within 1 … 12, and lifting
the finger tunes the string to the previewed peg, spending one action.

**Why this priority**: tuning is the game's move; the catalog names dragging the peg as its control.

**Independent Test**: scripted drags send exactly one tuning of the dragged string to the peg an independent computation
predicts, or nothing when the peg is unchanged or the string is locked.

**Acceptance Scenarios**:

1. **Given** an unlocked string, **When** the player drags from it and lifts with a previewed peg different from its
   current peg, **Then** exactly one tuning of that string to that peg is sent.
2. **Given** a locked string or a drag that ends at the current peg, **When** it lifts, **Then** nothing is sent and the
   description says why.

### User Story 3 - Tap freeze to test the walkway (Priority: P1)

A player taps the goal island or the row of step pips to freeze the window and test the crossing over every step.

**Why this priority**: testing is how a level is won or lost.

**Independent Test**: scripted taps on the goal or a pip send exactly one test.

### User Story 4 - Look around and come back (Priority: P2)

A player orbits the bridges with two fingers within bounds and returns to the authored view; the view never changes the
game.

**Independent Test**: orbit stays within bounds at every aspect, the scene stays inside the view, and the digest never
changes.

### User Story 5 - Every move without gestures (Priority: P1)

A player who cannot touch precisely can do everything through the labelled panel (string and peg steppers, tune, test,
undo, redo, next level, "Reset view"), including winning every certified level.

**Independent Test**: all 100 certified witnesses are replayed through panel actions on the host and win.

### Edge Cases

- **A touch that never moves far enough:** a tap (below 10 points, lifted within 0.5 s); two taps on empty space within
  0.35 s and 22 points reset the view; a press lifted at 0.5 s or later without moving does nothing.
- **A touch that moves 10 … 16 points:** neither a tap nor a drag; nothing changes.
- **A drag that ends at the string's current peg, or on a locked string:** sends nothing.
- **A drag beyond peg 1 or 12:** the preview stops at the bound (24 points of upward movement per peg).
- **A finished play (won or failed):** gestures send no kernel action and the description says the play is over (undo
  or next level); plucking (choosing a string) and orbit still work.
- **A stage other than playing:** gestures send no kernel action.
- **A tuning or test the kernel refuses:** sent and refused with its reason, shown to the player.
- **A second finger during a gesture:** cancels it (nothing sent) and starts an orbit.
- **A cancelled touch:** changes nothing.
- **Overlapping targets near a touch:** pips first, then the goal island, then the nearest string (ties to the lower
  string index), each within 22 points.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G1204-001**: A tap on a string MUST choose that string at its current peg (presentation state) and describe
  its resonance in the shown step; it MUST send no kernel action.
- **FR-R02G1204-002**: A drag from an unlocked string while playing MUST preview a peg that follows the drag in whole
  steps, clamped to 1 … 12, and on release MUST send exactly one tuning of that string to the previewed peg through the
  declared tune control, or nothing when the peg is unchanged.
- **FR-R02G1204-003**: A tap on the goal island or the step pips while playing MUST send exactly one crossing test.
- **FR-R02G1204-004**: Picking MUST be analytic and deterministic: pips, the goal island's top centre and string
  segments projected through the drawn camera (orbit included), each with a 22-point touch target, in that order.
- **FR-R02G1204-005**: Two-finger orbit MUST stay within stated bounds, keep the scene inside the view with a 5 % margin
  at every aspect 0.4 … 2.5 and never enter the digest, the snapshot or the kernel; a double tap on empty space or
  "Reset view" returns to the authored view.
- **FR-R02G1204-006**: The panel MUST keep every action available without gestures and gain "Reset view"; every
  certified witness MUST be replayable through panel actions.
- **FR-R02G1204-007**: Gestures MUST be tested on the host by scripted pointer sequences and on the simulator through the
  experience's pointer entry; existing tests pass; every new public name is documented; refusals are logged with their
  reason code (observability). Undo and redo stay the kernel's exact undo and redo through the panel.

### Key Entities

- **Gesture controller**: state (idle, string press, peg drag, target press, orbiting, cancelled), the touched string or
  target, the start and last points, the previewed peg, the press time, the last tap time and place.
- **Orbit**: yaw and pitch offsets from the authored view.
- **Gesture action**: choose, preview, tune, test, resetView; tune and test map onto declared kernel controls.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G1204-001**: For 500 seeded scripted taps and drags on certified levels at several sizes and orbits, the
  actions and choices equal an independent computation.
- **SC-R02G1204-002**: Second fingers, cancels and gestures on a finished play send no kernel action in every scripted
  case.
- **SC-R02G1204-003**: Orbit never changes the digest in every scripted case.
- **SC-R02G1204-004**: At every orbit within bounds and every aspect 0.4 … 2.5 the scene stays inside the view with a 5 %
  margin.
- **SC-R02G1204-005**: All 100 certified levels are won through panel actions alone.
- **SC-R02G1204-006**: Existing tests pass; the reference regression passes 7 of 7; each test under 10 seconds.
- **SC-R02G1204-007** {device}: after ImplementationLock-100, touch feel and latency are checked on D1/D2/D3.

## Assumptions

- Hints, failure explanations and progression come in R02-G12-05; announcements, haptics, the audible audition and full
  accessibility in R02-G12-06; persistence in R02-G12-07. The snapshot schema stays 1 here (orbit, chosen string and
  previewed peg are not saved).
- All gestures map onto the adapter's declared controls or onto presentation state; no new kernel action is added.
- Original design: all interaction and drawing are original code; no third-party assets or copied game designs.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Pluck to audition frequency | FR-R02G1204-001 |
| Drag tuning peg | FR-R02G1204-002 |
| Tap freeze to test walkway | FR-R02G1204-003 |
| Gesture-to-world actions (analytic picking) | FR-R02G1204-004 |
| Camera behavior (constrained orbit, reset) | FR-R02G1204-005 |
| Undo | FR-R02G1204-006, 007 |
