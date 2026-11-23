# Feature Specification: R02-G12-04 — Harmonic Bridges: gameplay spatial interaction

**Feature Branch**: `414-harmonic-bridges-gameplay-spatial-interaction` (spec directory only; work on `main`)

**Created**: 2026-11-23

**Status**: Draft

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

- **A touch that never moves far enough:** a tap; two taps on empty space within a short interval and distance reset the
  view.
- **A touch that moves between the tap and drag distances:** neither a tap nor a drag; nothing changes.
- **A drag that ends at the string's current peg, or on a locked string:** sends nothing.
- **A drag beyond peg 1 or 12:** the preview stops at the bound.
- **A finished play (won or failed):** gestures send no kernel action and the description says the play is over (undo
  or next level); plucking (choosing a string) and orbit still work.
- **A stage other than playing:** gestures send no kernel action.
- **A tuning or test the kernel refuses:** sent and refused with its reason, shown to the player.
- **A second finger during a gesture:** cancels it (nothing sent) and starts an orbit.
- **A cancelled touch:** changes nothing.
- **Overlapping strings near a touch:** the nearest string wins; ties go to the lower string index.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G1204-001**: A tap on a string MUST choose that string at its current peg (presentation state) and describe
  its resonance in the shown step; it MUST send no kernel action.
- **FR-R02G1204-002**: A drag from an unlocked string while playing MUST preview a peg that follows the drag in whole
  steps, clamped to 1 … 12, and on release MUST send exactly one tuning of that string to the previewed peg through the
  declared tune control, or nothing when the peg is unchanged.
- **FR-R02G1204-003**: A tap on the goal island or the step pips while playing MUST send exactly one crossing test.
- **FR-R02G1204-004**: Picking MUST be analytic and deterministic: the touch ray through the drawn camera against the
  string and island planes, with a minimum touch target for strings, islands and pips.
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
- **Gesture action**: choose, tune, test, resetView; tune and test map onto declared kernel controls.

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
