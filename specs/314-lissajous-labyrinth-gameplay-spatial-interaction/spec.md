# Feature Specification: R02-G02-04 — Lissajous Labyrinth: gameplay spatial interaction

**Feature Branch**: `314-lissajous-labyrinth-gameplay-spatial-interaction` (spec directory only; work on `main`)

**Created**: 2026-11-21

**Status**: Draft

**Ledger gate**: R02-G02-04 (migration ledger, game feature of experience R02-G02) · ID namespace FR-R02G0204-###,
SC-R02G0204-###, T-R02G0204-###

**Input**: User description: the archived R02-G02-04 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Implement native gesture-to-world actions, undo and camera behavior" for Lissajous Labyrinth, with the canonical
overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/314-lissajous-labyrinth-gameplay-spatial-interaction`; FR-R02G0204-###,
  SC-R02G0204-###, T-R02G0204-###.
- **Packaging (ADR-0009):** experience R02-G02 (`r02-g02.lissajous-labyrinth`, free; a registered candidate since
  R02-G02-03) in `Packages/ExperiencesRound02/LissajousLabyrinth`; this feature adds the touch controls to its Core
  (host-tested gesture logic) and Experience (presenter, scene highlights, panel).
- **Lesson of R02-G01-09 (owner standing rule: never ship an unwinnable panel):** the panel's dial steppers set pending
  values and Apply commits each changed dial as one action; today each tap is an action (level 1 needs 1 action, the
  steppers 7 taps, allowance 9).
- **Superseded parts of the source prompt:** price, "no IAP", the Round 2 lock and the per-round device campaign.
  **Device-only items:** gesture feel and touch-to-frame latency on D1/D2/D3 after ImplementationLock-100.
  **Owner-only items:** none.
- **Shared features used:** R02-F22 (spatial handles, picking, constrained drags, assistive steps), R02-F08 (geometry),
  the pointer tracker and pinch recognizer of VisualCoreScenes, and R02-G02-01 … 03.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Turn a dial on the figure to change the path (Priority: P1) 🎯

A player touches one of the four dial handles drawn beside the figure (two frequencies, two phases), turns it, sees the
value it would set, and on release the path changes by exactly one action.

**Why this priority**: this is how the game is played on a touch screen.

**Independent Test**: scripted touches on the dial handles produce exactly the action the release position implies, and
the kernel's state changes by that one action.

**Acceptance Scenarios**:

1. **Given** a level in play, **When** the player drags a dial handle around its ring and releases, **Then** exactly one
   `dial.set` action with the value under the finger is sent; a release on the current value sends nothing.
2. **Given** a frequency dial turned to a value that is not coprime with the other frequency, **When** released,
   **Then** the action is refused with its reason, announced, and the state is unchanged.

### User Story 2 - Look around without changing the puzzle (Priority: P1)

Two fingers orbit the camera around the figure within limits; a reset returns to the authored view; the puzzle never
changes.

**Independent Test**: orbiting to every limit and resetting changes no digest, and the figure stays inside the view.

### User Story 3 - Win with the panel alone (Priority: P1)

A player who cannot or does not use gestures (for example with VoiceOver) sets pending dial values with the panel's
steppers and applies them; every certified level can be won within its allowance in its certified shortest number of
actions.

**Independent Test**: for all 100 levels, setting the certified solution's dial values as pending values and applying
once wins in exactly the certified shortest number of actions.

### User Story 4 - Know what is selected and undo it (Priority: P2)

The selected dial is outlined and described; undo and redo revert and repeat the last action.

### Edge Cases

- **A second finger during a drag** switches to orbit and cancels the drag without an action.
- **A touch on empty space** starts nothing; **a cancelled touch** sends nothing.
- **Paused, won or failed play:** drags preview nothing and send nothing; orbit still works.
- **Apply past the allowance or after a win:** the first refused action stops the rest, is announced with its reason,
  and the remaining pending values are dropped; applied actions stay.
- **An outside change** (undo, redo, next level, restore) drops the pending values.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G0204-001**: Each of the four dials MUST have a handle drawn in the scene and pickable by touch (minimum touch
  radius of R02-F22).
- **FR-R02G0204-002**: Turning a dial handle MUST map the finger's angle to the dial's value range (frequencies 1 … 9,
  phases 0 … 15) and preview it; release MUST send exactly one action, or none on the current value.
- **FR-R02G0204-003**: Gestures MUST be arbitrated: one finger on a handle turns it; two fingers orbit; a second finger
  cancels a drag; empty space and paused or ended play send nothing.
- **FR-R02G0204-004**: The camera MUST orbit within stated limits, reset on request and never change the kernel's state
  or digest; the figure MUST stay inside the view at every orbit for aspects 0.4 … 2.5.
- **FR-R02G0204-005**: The selected dial MUST be outlined and described; undo and redo MUST be reachable from the panel.
- **FR-R02G0204-006**: The panel's steppers MUST set pending values without sending actions; Apply MUST commit each
  changed dial as one action in the order frequencyA, frequencyB, phaseA, phaseC, stop at the first refusal and drop the
  rest; Clear MUST drop them; an outside change MUST drop them; pending values MUST be announced.
- **FR-R02G0204-007**: Gesture logic MUST be deterministic and testable without a screen.
- **FR-R02G0204-008**: Existing tests MUST pass unchanged except where they drove the steppers; new public names are
  documented; the reference regression passes.

### Key Entities

- **Dial handle**: the dial, its ring centre and radius in the scene, its value range.
- **Gesture controller state**: idle, turning (dial, preview value), orbiting, with the selection.
- **Orbit**: azimuth and elevation within limits; reset to authored.
- **Pending values**: the four dial values set by the steppers and not yet applied.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G0204-001**: For 500 seeded scripted drags, each gesture ends in exactly the action its release position implies
  (or none).
- **SC-R02G0204-002**: Every arbitration case (second finger, cancel, empty space, paused, won, failed, refused action)
  ends with the stated outcome.
- **SC-R02G0204-003**: Orbiting to every limit and resetting changes no digest; the figure stays inside the view with a
  5 % margin at 7 aspects.
- **SC-R02G0204-004**: All 100 certified levels are won through pending values and one Apply in exactly their certified
  shortest number of actions.
- **SC-R02G0204-005**: On the simulator, the selected dial's outline is drawn and its description matches the state.
- **SC-R02G0204-006**: Existing tests pass; the reference regression passes 7 of 7; each test finishes in under 10 s.
- **SC-R02G0204-007** {device}: after ImplementationLock-100, gesture feel and touch-to-frame latency are recorded on
  D1/D2/D3.

## Assumptions

- Dial handles sit on rings beside the figure's bounding box, in the scene's world space, as Aurora Loom's anchors and
  dials do; the exact placement is a plan decision.
- Lissajous Labyrinth has no stars yet (progression is R02-G02-05); "certified shortest" is the solver's shortest.

## Traceability

| Source item (round2.md R2-G02-04) | Requirement |
|---|---|
| Native gesture-to-world actions | FR-R02G0204-001, 002, 003, 007 |
| Undo | FR-R02G0204-005 |
| Camera behaviour | FR-R02G0204-004 |
| Panel play (lesson of R02-G01-09) | FR-R02G0204-006 |
