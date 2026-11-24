# Feature Specification: R02-G13-04 — Acoustic Constellator: gameplay spatial interaction

**Feature Branch**: `424-acoustic-constellator-gameplay-spatial-interaction` (spec directory only; work on `main`)

**Created**: 2026-11-23

**Status**: Draft

**Ledger gate**: R02-G13-04 (migration ledger, game feature of experience R02-G13) · ID namespace FR-R02G1304-###,
SC-R02G1304-###, T-R02G1304-###

**Input**: User description: the archived R02-G13-04 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Gameplay spatial interaction" for Acoustic Constellator ("Implement native gesture-to-world actions, undo and camera
behavior"; catalog controls "drag links between 3D stars, tap a node to phase nudge, orbit to inspect"), with the
canonical overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/424-acoustic-constellator-gameplay-spatial-interaction`; FR-R02G1304-###,
  SC-R02G1304-###, T-R02G1304-###.
- **Packaging (ADR-0009):** the gestures live in the experience `r02-g13.acoustic-constellator` (a registered candidate
  since R02-G13-03) inside the one app; the source's `Apps/AcousticConstellator` and `Packages/GameModules` paths are
  superseded.
- **Superseded parts of the source prompt:** price, "no IAP" and the Round 2 lock. The source's "content count 85" is a
  milestone figure; the 100 certified levels of R02-G13-02 stand. **Device-only items:** touch feel and latency on
  D1/D2/D3, recorded as `{device}` tasks for after ImplementationLock-100. **Owner-only items:** none.
- **Shared features used:** R02-F14 (reversible history), R02-F22 (spatial controls and analytic picking), R02-F26
  (input and accessibility contract), the experience host's pointer events, and the kernel, content, adapter and
  renderer of R02-G13-01 … 03.
- **Model:** feature 414 (Harmonic Bridges' gameplay spatial interaction) for the gesture controller, picker, orbit and
  panel.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Drag a link between two stars (Priority: P1) 🎯

A player drags from one star to another: a filament follows the finger, the star under the finger is marked as the
target, and lifting the finger on that star links the two stars, spending one action; dragging along an existing link
the player placed removes it.

**Why this priority**: linking is the game's main move, and the catalog names dragging links as its control.

**Independent Test**: scripted drags send exactly one link or unlink of the pair an independent pick predicts, or nothing
when the drag ends away from a second star.

**Acceptance Scenarios**:

1. **Given** two unlinked stars while playing, **When** the player drags from one and lifts on the other, **Then**
   exactly one link of that pair is sent.
2. **Given** a link the player placed, **When** the player drags from one of its stars and lifts on the other, **Then**
   exactly one unlink of that pair is sent.
3. **Given** a drag that ends on empty space, on the same star or on a fixed link's pair, **When** it lifts, **Then**
   nothing is sent and the description says why.

### User Story 2 - Tap a star to nudge its phase (Priority: P1)

A player taps a star to nudge its starting phase forward one step, spending one action; the star becomes the panel's
chosen star.

**Why this priority**: nudging is the game's second move, named by the catalog.

**Independent Test**: scripted taps on stars send exactly one forward nudge of the star an independent pick predicts.

**Acceptance Scenarios**:

1. **Given** a level while playing, **When** the player taps a star, **Then** exactly one nudge of that star by +1 is
   sent and it becomes the chosen star.
2. **Given** a tap away from every star, link and gauge, **When** it lifts, **Then** nothing changes.

### User Story 3 - Listen by touching the gauges (Priority: P1)

A player taps the coherence gauge or the hold pips to listen: the constellation drifts through the window and the verdict
is decided.

**Why this priority**: listening is how a level is won or lost.

**Independent Test**: scripted taps on the gauges send exactly one listen.

### User Story 4 - Inspect a link (Priority: P2)

A player taps a link to choose its two stars as the panel's star and partner, and the description names the link and
its gap at the shown tick; no action is spent.

**Independent Test**: scripted taps on links choose exactly the pair an independent pick predicts and send nothing.

### User Story 5 - Look around and come back (Priority: P2)

A player orbits the constellation with two fingers within bounds and returns to the authored view; the view never
changes the game.

**Independent Test**: orbit stays within bounds at every aspect, the scene stays inside the view, and the digest never
changes.

### User Story 6 - Every move without gestures (Priority: P1)

A player who cannot touch precisely can do everything through the labelled panel (star and partner steppers, link,
unlink, nudge − and +, listen, undo, redo, next level, "Reset view"), including winning every certified level.

**Independent Test**: all 100 certified witnesses are replayed through panel actions on the host and win.

### Edge Cases

- **A touch that never moves far enough:** a tap; two taps on empty space close together reset the view; a long press
  without movement does nothing.
- **A touch that moves a little but not enough to drag:** neither a tap nor a drag; nothing changes.
- **A drag that ends on its own star, on empty space, or on a pair joined by a fixed link:** sends nothing.
- **A drag that would exceed a star's degree limit or the link limit:** sent and refused by the kernel with its reason,
  shown to the player.
- **A finished play (won or failed):** gestures send no kernel action and the description says the play is over (undo
  or next level); inspecting links and orbit still work.
- **A stage other than playing:** gestures send no kernel action.
- **A second finger during a gesture:** cancels it (nothing sent) and starts an orbit.
- **A cancelled touch:** changes nothing.
- **Overlapping targets near a touch:** a fixed order decides (gauges, then stars, then links), each with a touch target
  of fixed size.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G1304-001**: A drag from a star while playing MUST show the filament to the finger and mark the target star,
  and on release on a second star MUST send exactly one link of that pair through the declared link control when the
  pair is unlinked, or exactly one unlink through the declared unlink control when the player placed that link; it MUST
  send nothing otherwise.
- **FR-R02G1304-002**: A tap on a star while playing MUST send exactly one nudge of that star by +1 through the declared
  nudge control and choose it as the panel's star.
- **FR-R02G1304-003**: A tap on the coherence gauge or the hold pips while playing MUST send exactly one listen.
- **FR-R02G1304-004**: A tap on a link MUST choose its two stars as the panel's star and partner and describe the link;
  it MUST send no kernel action.
- **FR-R02G1304-005**: Picking MUST be analytic and deterministic: the gauges, the star centres and the link curves
  projected through the drawn camera (orbit included), each with a touch target of fixed size, in that order.
- **FR-R02G1304-006**: Two-finger orbit MUST stay within stated bounds, keep the scene inside the view with a 5 % margin
  at every aspect 0.4 … 2.5 and never enter the digest, the snapshot or the kernel; a double tap on empty space or
  "Reset view" returns to the authored view.
- **FR-R02G1304-007**: The panel MUST keep every action available without gestures and gain "Reset view"; every
  certified witness MUST be replayable through panel actions.
- **FR-R02G1304-008**: Gestures MUST be tested on the host by scripted pointer sequences and on the simulator through the
  experience's pointer entry; existing tests pass; every new public name is documented; refusals are logged with their
  reason code (observability). Undo and redo stay the kernel's exact undo and redo through the panel.

### Key Entities

- **Gesture controller**: state (idle, star press, link drag, target press, link press, orbiting, cancelled), the
  touched star, link or gauge, the start and last points, the target star of a drag, the press time, the last tap time
  and place.
- **Orbit**: yaw and pitch offsets from the authored view.
- **Gesture action**: choose, choosePair, preview, link, unlink, nudge, listen, resetView; link, unlink, nudge and listen
  map onto declared kernel controls.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G1304-001**: For 500 seeded scripted taps and drags on certified levels at several sizes and orbits, the
  actions and choices equal an independent computation.
- **SC-R02G1304-002**: Second fingers, cancels and gestures on a finished play send no kernel action in every scripted
  case.
- **SC-R02G1304-003**: Orbit never changes the digest in every scripted case.
- **SC-R02G1304-004**: At every orbit within bounds and every aspect 0.4 … 2.5 the scene stays inside the view with a 5 %
  margin.
- **SC-R02G1304-005**: All 100 certified levels are won through panel actions alone.
- **SC-R02G1304-006**: Existing tests pass; the reference regression passes 7 of 7; each test under 10 seconds.
- **SC-R02G1304-007** {device}: after ImplementationLock-100, touch feel and latency are checked on D1/D2/D3.

## Assumptions

- Hints, failure explanations and progression come in R02-G13-05; announcements, haptics, sound and full accessibility
  in R02-G13-06; persistence in R02-G13-07. The snapshot schema stays 1 here (orbit, the chosen pair and the drag
  preview are not saved).
- All gestures map onto the adapter's declared controls or onto presentation state; no new kernel action is added. A
  backward nudge stays a panel action (twelve forward steps make a full turn, but each costs an action).
- Original design: all interaction and drawing are original code; no third-party assets or copied game designs.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Drag links between 3D stars | FR-R02G1304-001 |
| Tap a node to phase nudge | FR-R02G1304-002 |
| Listen (verdict) through the scene | FR-R02G1304-003 |
| Gesture-to-world actions (analytic picking, inspection) | FR-R02G1304-004, 005 |
| Camera behavior (orbit to inspect, reset) | FR-R02G1304-006 |
| Undo | FR-R02G1304-007, 008 |
