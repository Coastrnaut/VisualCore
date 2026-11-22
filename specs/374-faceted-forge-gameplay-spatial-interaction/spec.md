# Feature Specification: R02-G08-04 — Faceted Forge: gameplay spatial interaction

**Feature Branch**: `374-faceted-forge-gameplay-spatial-interaction` (spec directory only; work on `main`)

**Created**: 2026-11-22

**Status**: Draft

**Ledger gate**: R02-G08-04 (migration ledger, game feature of experience R02-G08) · ID namespace FR-R02G0804-###,
SC-R02G0804-###, T-R02G0804-###

**Input**: User description: the archived R02-G08-04 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Implement native gesture-to-world actions, undo and camera behavior" for Faceted Forge (the design's controls: "drag
cut-plane rim and depth slider; tap commit for cinematic split"), with the canonical overrides of ADR-0009 and
Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/374-faceted-forge-gameplay-spatial-interaction`; FR-R02G0804-###,
  SC-R02G0804-###, T-R02G0804-###.
- **Packaging (ADR-0009):** the gestures live in the experience `r02-g08.faceted-forge` (a registered candidate since
  R02-G08-03) inside the one app; the source's `Apps/FacetedForge` and `Packages/GameModules` paths are superseded.
- **Superseded parts of the source prompt:** price, "no IAP" and the Round 2 lock. The source's "content count 84" is a
  milestone figure; the 100 certified levels of R02-G08-02 stand. **Device-only items:** touch feel and latency on
  D1/D2/D3, recorded as `{device}` tasks for after ImplementationLock-100. **Owner-only items:** none.
- **Shared features used:** R02-F14 (reversible history), R02-F22 (spatial controls and analytic picking), R02-F26
  (input and accessibility contract), the experience host's pointer events, and the kernel, content, adapter and
  renderer of R02-G08-01 … 03.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Pick a piece and see the cut plane on it (Priority: P1) 🎯

A player taps a piece of the opened crystal; it becomes the chosen piece and the ruby preview plane moves onto it at the
middle depth of the current direction. Nothing changes in the game.

**Why this priority**: every cut starts by choosing the piece.

**Independent Test**: scripted taps on pieces of certified levels choose exactly the piece an independent ray pick
predicts, or none; the digest never changes.

**Acceptance Scenarios**:

1. **Given** a level while playing, **When** the player taps a piece outside the preview plane, **Then** that piece
   becomes the chosen one and the preview moves onto it.
2. **Given** a tap on empty space, **When** it lifts, **Then** the choice does not change.

### User Story 2 - Tilt the plane by its rim and slide it to depth (Priority: P1)

A player drags the preview plane's rim: the plane tilts to follow the finger and snaps to the nearest of the 13 cut
directions. A player drags the depth slider (or the plane's interior) along the plane's normal: the plane slides through
the depths that cross the chosen piece, one step at a time. Both are previews: nothing changes in the game.

**Why this priority**: choosing the plane is the game's main decision.

**Independent Test**: scripted rim and depth drags produce exactly the direction and depth an independent computation
predicts; the digest never changes.

**Acceptance Scenarios**:

1. **Given** a chosen piece, **When** a drag starts on the preview rim and ends, **Then** the direction is the one of
   the 13 nearest to the dragged orientation and the depth moves to the nearest crossing one.
2. **Given** a chosen piece, **When** a drag starts on the preview interior or the depth slider and moves along the
   plane's projected normal, **Then** the depth changes by the number of whole steps dragged, clamped to the crossing
   depths.

### User Story 3 - Tap to commit the cut (Priority: P1)

A player taps the preview plane (or "Cut" in the panel) and the chosen piece splits along it; the two halves open apart
(the cinematic split is presentation only). A tap on the plane while the plane misses the piece sends nothing.

**Independent Test**: scripted taps on and off the preview send exactly one cut with the chosen piece, direction and
depth, or none.

### User Story 4 - Look around and come back (Priority: P2)

A player orbits the crystal with two fingers within bounds and returns to the authored view; the view never changes the
game.

**Independent Test**: orbit stays within bounds at every aspect, the scene stays inside the view, and the digest never
changes.

### User Story 5 - Every move without gestures (Priority: P1)

A player who cannot drag precisely can do everything through the labelled panel (piece picker, direction picker, depth
− and +, cut, undo, redo, next level, "Reset view"), including winning every certified level.

**Independent Test**: all 100 certified solutions are replayed through panel actions on the host and win.

### Edge Cases

- **A touch that never moves far enough:** a tap (see US1, US3); two taps on empty space within 0.35 s reset the view.
- **A touch that moves 10 … 16 points:** neither a tap nor a drag; nothing changes.
- **A finished play (won, failed or showing the result):** commits send nothing and the description says the play is
  over (undo or next level); picking, tilting, sliding and orbit still work.
- **A second finger during a drag:** cancels it (the choice returns to what it was at touch-down) and orbits.
- **A cancelled touch:** changes nothing.
- **A direction whose plane crosses the chosen piece at no integer depth:** the plane is not drawn and a commit sends
  nothing; the panel says the direction misses the piece.
- **A cut that makes a sliver or spends the last cut:** the kernel fails the play as its rules say; the failure is shown;
  undo returns to playing.
- **A piece hidden behind another piece:** picking takes the nearest piece hit along the touch ray; the panel picker
  reaches every piece.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G0804-001**: A tap (a touch moving less than 10 points) on a piece outside the preview MUST choose that piece
  (the preview moving to its middle crossing depth); on empty space it MUST change nothing; choosing is presentation
  only.
- **FR-R02G0804-002**: A drag (at least 16 points) that starts within the touch target of the preview rim MUST, on
  release, set the direction to the one of the 13 nearest the dragged orientation and the depth to the nearest crossing
  one; during the drag the previewed plane MUST be drawn and described.
- **FR-R02G0804-003**: A drag that starts on the preview interior or the depth slider MUST change the depth by whole
  steps along the plane's projected normal, clamped to the depths that cross the chosen piece.
- **FR-R02G0804-004**: A tap within the preview polygon while playing MUST send exactly one `piece.cut [piece,
  direction, depth]` with the current choice; otherwise a commit MUST send nothing.
- **FR-R02G0804-005**: Picking MUST be analytic and deterministic: the touch ray through the drawn camera against the
  opened pieces' faces, the preview polygon and its rim, with a 22-point minimum touch target; the preview wins at
  touch-down, then the nearest piece hit.
- **FR-R02G0804-006**: Two-finger orbit MUST stay within stated yaw and pitch bounds, keep the scene inside the view with
  a 5 % margin at every aspect 0.4 … 2.5 and never enter the digest, the snapshot or the kernel; a double tap on empty
  space or "Reset view" returns to the authored view.
- **FR-R02G0804-007**: The panel MUST keep every action available without gestures and gain "Reset view"; every
  certified solution MUST be replayable through panel actions.
- **FR-R02G0804-008**: Gestures MUST be tested on the host by scripted pointer sequences and on the simulator through the
  experience's pointer entry; existing tests pass; every new public name is documented; refusals are logged with their
  reason code (observability).

### Key Entities

- **Gesture controller**: state (idle, rim drag, depth drag, plane press, piece press, orbiting, cancelled), the choice
  at touch-down, last points, last tap time and place.
- **Orbit**: yaw and pitch offsets from the authored view.
- **Preview choice**: the chosen piece, direction and depth (presentation only, from R02-G08-03).
- **Gesture action**: choose(piece), tilt(direction), slide(depth), commit, resetView; only commit maps onto a declared
  control (`piece.cut`).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G0804-001**: For 500 seeded scripted taps and drags on certified levels at several sizes and orbits, the
  choices made and the cuts sent equal an independent computation of the touched piece, direction and depth.
- **SC-R02G0804-002**: Second fingers, cancels and commits on a finished play send no action in every scripted case.
- **SC-R02G0804-003**: Choosing, tilting, sliding and orbit never change the digest in every scripted case.
- **SC-R02G0804-004**: At every orbit within bounds and every aspect 0.4 … 2.5 the scene stays inside the view with a
  5 % margin.
- **SC-R02G0804-005**: All 100 certified levels are won through panel actions alone.
- **SC-R02G0804-006**: Existing tests pass; the reference regression passes 7 of 7; each test under 10 seconds.
- **SC-R02G0804-007** {device}: after ImplementationLock-100, touch feel and latency are checked on D1/D2/D3.

## Assumptions

- Hints, failure explanations and progression come in R02-G08-05; announcements, haptics and full accessibility in
  R02-G08-06; persistence in R02-G08-07. The snapshot schema stays 1 here (no schema migration in this feature; orbit
  and the preview choice are not saved).
- All gestures map onto the adapter's declared controls or onto presentation state; no new kernel action is added.
- Original design: all interaction and drawing are original code; no third-party assets or copied game designs.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Gesture-to-world actions (drag cut-plane rim and depth slider; tap commit for cinematic split) | FR-R02G0804-001 … 005 |
| Undo without ambiguity | FR-R02G0804-007 |
| Camera behaviour (constrained orbit, reset, no singularities) | FR-R02G0804-006 |
| Accessible alternative to every gesture | FR-R02G0804-007 |
| Deterministic tests, observability | FR-R02G0804-008; SC-R02G0804-001 … 005 |

## Negative Requirements / Excluded scope

- No free camera navigation, no gestures that change the rules, no hints, sounds or haptics, no device run before
  ImplementationLock-100, no availability before X-R02-G08.
