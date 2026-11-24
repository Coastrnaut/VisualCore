# Feature Specification: R02-G13-04 — Acoustic Constellator: gameplay spatial interaction

**Feature Branch**: `424-acoustic-constellator-gameplay-spatial-interaction` (spec directory only; work on `main`)

**Created**: 2026-11-23

**Status**: Clarified

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

## Clarifications

### Session 2026-11-23

Answered autonomously under the owner's standing delegation, safest well-supported option each time, following feature
414's answers where the games agree. Facts checked in code (read-only, 2026-11-23): Harmonic Bridges' feature 414 solved
the same problem with a host-tested gesture controller in its Core taking `PointerEvent`s (id, phase
began/moved/ended/cancelled, location in view points with the origin top-left, timestamp) with the view size, the drawn
snapshot and orbit, an analytic picker and a clamped orbit; tap below 10 points and 0.5 s, drag from 16 points, double
tap within 0.35 s and 22 points, orbit 90° per view width and 60° per view height. Acoustic Constellator's camera
(`AcousticConstellatorSceneGeometry`) looks from eye (0, 2.0, 1.7) towards (0, 0, 0.2) at the box x −0.9 … 0.9,
z −0.7 … 1.25, y 0 … 0.3; star (gx, gy, gz) is at X = (gx − 5.5)·0.14, Z = (gy − 5.5)·0.11, Y = 0.15 + (gz − 5.5)·0.02;
links are spline strips between star centres rising 0.03 at the middle; the coherence gauge is 12 bars at z = 0.85
across x −0.6 … 0.6, the hold pips at z = 1.0 across x −0.4 … 0.4, the moves gauge at z = 1.15; the adapter accepts
`link.add` [a, b], `link.remove` [a, b], `star.nudge` [s, ±1], `constellation.listen`, `play.undo`, `play.redo` and
`level.next`; the panel's chosen star and partner are presentation state.

- Q: How is a touch picked? → A: at touch-down, every target is projected through the drawn camera (orbit included)
  into view points. In this order: a gauge target (a coherence bar or a hold pip whose centre is within 22 points of the
  touch; the nearest first, ties to the coherence bars and then the lower index), then a star (its centre within 22
  points; the nearest first, ties to the lower star index), then a link (the shortest distance from the touch to its
  projected spline, 16 segments, within 22 points; the nearest first, ties to the lower link index); anything else, the
  moves gauge and guides included, is empty space. A tap is a touch that moves less than 10 points and lifts within
  0.5 s; a drag moves at least 16 points; 10 … 16 points is neither, and a press lifted at 0.5 s or later without moving
  is neither. Impact: FR-R02G1304-002, 003, 004, 005; SC-R02G1304-001.
- Q: What do taps do? → A: a tap on a star while playing sends `star.nudge [s, 1]` and chooses star s (the partner moves
  to the next star, modulo the star count, when it equals s). A tap on a link chooses its stars as star and partner
  (presentation state, in any stage) and the description names the link, its gap at the shown tick and whether it is
  fixed; no action is sent. A tap on a gauge target sends `constellation.listen` while playing. A tap on empty space
  changes nothing, and two such taps within 0.35 s and 22 points reset the view. Impact: FR-R02G1304-002, 003, 004, 006;
  SC-R02G1304-001.
- Q: How does dragging a link work? → A: a drag that starts on a star previews a filament from that star's projected
  centre to the finger; the target is the other star whose projected centre is nearest the finger within 22 points
  (ties to the lower index), or none. On release while playing: no target sends nothing; an unlinked pair sends
  `link.add [a, b]` (a < b); a pair the player linked sends `link.remove [a, b]`; a pair joined by a fixed link sends
  nothing and the description says the link is fixed. The chosen star and partner follow the start and target stars.
  A link the kernel refuses (degree or link limit) is sent and refused with its reason code. A drag from a star on any
  stage other than playing previews nothing and sends nothing; a drag that starts on a link, a gauge or empty space sends
  nothing. Impact: FR-R02G1304-001; SC-R02G1304-001.
- Q: How do two fingers behave, and what happens on a finished play? → A: as feature 414: a second finger cancels any
  one-finger gesture (nothing sent) and orbits: yaw ±35° about the y axis (90° per view width), pitch −15° … +20° (60°
  per view height) about the authored view; a third finger re-bases the midpoint; a double tap on empty space or "Reset
  view" returns to the authored view. The camera refits its field of view so the authored box stays inside the view with
  a 5 % margin at every orbit and aspect 0.4 … 2.5. Orbit is presentation only: not saved, so the snapshot schema stays
  1. Gestures send kernel actions only while playing; on a won or failed play a star tap only chooses the star, link
  drags and gauge taps send nothing, and the description says the play is over (undo or next level); link inspection
  and orbit still work. Impact: FR-R02G1304-006, 008; SC-R02G1304-002, 004.
- Q: How is everything tested? → A: the Core gesture controller (`AcousticConstellatorGestureController`) with a picker
  (`AcousticConstellatorPicker`) takes pointer events with the view size, the drawn snapshot, the orbit and the chosen
  star and partner and returns the gesture actions (choose, choosePair, preview, link, unlink, nudge, listen, resetView)
  and the orbit; host tests feed 500 seeded taps and drags on certified levels at several sizes and orbits and compare
  with an independent pick computed in the test; simulator tests send the same touches through the experience's pointer
  entry; a host test wins all 100 certified levels through panel actions alone (star and partner steppers, link, nudge,
  listen). Impact: FR-R02G1304-007, 008; SC-R02G1304-001 … 005.

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

- **A touch that never moves far enough:** a tap (below 10 points, lifted within 0.5 s); two taps on empty space within
  0.35 s and 22 points reset the view; a press lifted at 0.5 s or later without moving does nothing.
- **A touch that moves 10 … 16 points:** neither a tap nor a drag; nothing changes.
- **A drag that ends on its own star, on empty space, or on a pair joined by a fixed link:** sends nothing.
- **A link, unlink, nudge or listen the kernel refuses** (a star's degree limit, the link limit, the budget, the
  stage): sent and refused with its reason code, which the presenter logs and shows.
- **A finished play (won or failed):** gestures send no kernel action (a star tap only chooses the star) and the
  description says the play is over (undo or next level); inspecting links and orbit still work.
- **A stage other than playing:** gestures send no kernel action.
- **A second finger during a gesture:** cancels it (nothing sent) and starts an orbit.
- **A cancelled touch:** changes nothing.
- **Overlapping targets near a touch:** gauge targets first, then the nearest star (ties to the lower index), then the
  nearest link (ties to the lower index), each within 22 points.

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
  projected through the drawn camera (orbit included), each with a 22-point touch target, in that order.
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
