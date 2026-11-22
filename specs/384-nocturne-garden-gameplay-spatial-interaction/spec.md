# Feature Specification: R02-G09-04 — Nocturne Garden: gameplay spatial interaction

**Feature Branch**: `384-nocturne-garden-gameplay-spatial-interaction` (spec directory only; work on `main`)

**Created**: 2026-11-22

**Status**: Clarified

**Ledger gate**: R02-G09-04 (migration ledger, game feature of experience R02-G09) · ID namespace FR-R02G0904-###,
SC-R02G0904-###, T-R02G0904-###

**Input**: User description: the archived R02-G09-04 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Implement native gesture-to-world actions, undo and camera behavior" for Nocturne Garden (the design's controls: "drag
stems, pinch scale, slide sun elevation; silhouette preview as exact diagnostic"), with the canonical overrides of
ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/384-nocturne-garden-gameplay-spatial-interaction`; FR-R02G0904-###,
  SC-R02G0904-###, T-R02G0904-###.
- **Packaging (ADR-0009):** the gestures live in the experience `r02-g09.nocturne-garden` (a registered candidate since
  R02-G09-03) inside the one app; the source's `Apps/NocturneGarden` and `Packages/GameModules` paths are superseded.
- **Superseded parts of the source prompt:** price, "no IAP" and the Round 2 lock. The source's "content count 76" is a
  milestone figure; the 100 certified levels of R02-G09-02 stand. **Device-only items:** touch feel and latency on
  D1/D2/D3, recorded as `{device}` tasks for after ImplementationLock-100. **Owner-only items:** none.
- **Shared features used:** R02-F14 (reversible history), R02-F22 (spatial controls and analytic picking), R02-F26
  (input and accessibility contract), the experience host's pointer events, and the kernel, content, adapter and
  renderer of R02-G09-01 … 03.

## Clarifications

### Session 2026-11-22

Answered autonomously under the owner's standing delegation, safest well-supported option each time, following feature
374's answers where the games agree. Facts checked in code (read-only, 2026-11-22): Faceted Forge's feature 374 solved
the same problem with a host-tested gesture controller in its Core (`FacetedForgeGestureController`) taking
`PointerEvent`s (id, phase began/moved/ended/cancelled, location in view points with the origin top-left, timestamp)
with the view size, the drawn snapshot and orbit, an analytic picker and a clamped orbit; tap below 10 points and 0.5 s,
drag from 16 points, double tap within 0.35 s and 22 points, orbit yaw 90° per view width and pitch 60° per view
height; Nocturne Garden's camera (`NocturneGardenSceneGeometry.camera(_:aspect:)`) looks from +z pitched 8° down at a
per-level bounding sphere; the bed lies in the plane z = 0 (cell size u = 2 / W), the blooms' heads at z = 0.35 … 0.39
drawn at 0.35·size·u, the lantern at x = 1.25; the adapter accepts `bloom.plant`, `bloom.move`, `bloom.resize`,
`bloom.remove`, `sun.set`, `play.undo`, `play.redo` and `level.next`; the panel's picks (kind, column, row, size,
bloom) are presentation state.

- Q: How is a touch picked? → A: at touch-down the touch ray through the drawn camera is tested, in this order: the
  lantern (its projected centre within 22 points), the blooms (the ray meets a bloom's head box at z = 0.37, or the
  bloom's projected foot or head centre lies within 22 points; the nearest to the eye first, ties to the lower index),
  then the bed (the cell whose square contains the ray's point on z = 0); anything else is empty space. A tap is a
  touch that moves less than 10 points and lifts within 0.5 s; a drag moves at least 16 points; 10 … 16 points is
  neither. Impact: FR-R02G0904-001, 004; SC-R02G0904-001.
- Q: What do taps and drags send? → A: a tap on a bed cell plants the panel's kind at its size with that cell as the
  anchor (`bloom.plant`) while playing; a tap on a bloom chooses it in the panel (presentation only); a tap on the
  lantern does nothing. A drag of a bloom keeps the grab offset: the target anchor is the bloom's anchor plus the
  whole-cell difference between the cells under the finger now and at touch-down; while dragging, the would-be shadow
  of the arrangement with the moved bloom (the kernel's own cell computation, `NocturneGardenMask.union`), its match
  and its leak are shown as the preview (a pale dashed outline of the would-be cells and a line "would match 12/16,
  leak 0 cells"); on release one `bloom.move` to the target (nothing when the target is the bloom's own anchor) or,
  when the finger's ray meets z = 0 outside the bed, one `bloom.remove`. A vertical drag on the lantern changes the
  elevation by one step per 48 points (down: lower sun, larger elevation), to the nearest of the level's allowed
  elevations, and on release sends one `sun.set` when it differs. Impact: FR-R02G0904-001 … 003; SC-R02G0904-001,
  003.
- Q: How do two fingers behave? → A: a second finger cancels any one-finger gesture (nothing sent, the preview dropped).
  If the first finger was on a bloom, the two fingers pinch that bloom: at release of either finger the scale (the
  current distance between the fingers over their distance when the second went down) gives the size nearest
  size·scale among the level's allowed sizes, and one `bloom.resize` is sent when it differs. Otherwise the fingers
  orbit: yaw ±35° about the y axis (90° per view width), pitch 0° … 30° down (authored 8°, 60° per view height); a
  third finger re-bases the midpoint; a double tap (two taps at most 0.35 s and 22 points apart) on empty space or
  "Reset view" returns to the authored view. The camera distance refits so the level's framing sphere stays inside the
  view with a 5 % margin at every orbit and aspect 0.4 … 2.5. Orbit is presentation only: not saved, so the snapshot
  schema stays 1. Impact: FR-R02G0904-003, 005; SC-R02G0904-002, 004.
- Q: What happens on a finished play or a refused action? → A: on a won, failed or result stage every gesture that
  would send an action sends nothing and the description says the play is over (undo or next level); choosing a bloom,
  previews and orbit still work. An action the kernel refuses (no supply left, an anchor outside the bed, a leak that
  fails the play is not a refusal) is refused by the adapter with its reason code, which the presenter logs and shows.
  Impact: FR-R02G0904-007; SC-R02G0904-002.
- Q: How is everything tested? → A: the Core gesture controller (`NocturneGardenGestureController`) with a picker
  (`NocturneGardenPicker`) takes pointer events with the view size and the drawn snapshot and orbit and returns the
  gesture actions (plant, move, remove, resize, sun, choose, resetView), the drag preview and the orbit; host tests feed
  500 seeded taps, drags, pinches and lantern drags on certified levels at several sizes and orbits and compare with an
  independent pick and step computed in the test; simulator tests send the same touches through the experience's
  pointer entry; a host test wins all 100 certified levels through panel actions (kind, column, row and size pickers,
  plant; bloom picker, move, resize, remove; sun − and +) by choosing each certified action's values. Impact:
  FR-R02G0904-006, 007; SC-R02G0904-001 … 005.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Plant a bloom where you touch (Priority: P1) 🎯

A player taps an empty place of the mist bed; a bloom of the chosen kind and size is planted with its foot at the cell
touched, and its shadow appears on the mist. The kind and size are chosen in the panel.

**Why this priority**: planting is the game's main action.

**Independent Test**: scripted taps on bed cells of certified levels plant exactly the bloom an independent pick
predicts, or send nothing.

**Acceptance Scenarios**:

1. **Given** a level while playing with supply left, **When** the player taps a bed cell not covered by a bloom,
   **Then** one plant of the chosen kind and size is sent with that cell as the anchor.
2. **Given** a tap outside the bed and off every bloom, **When** it lifts, **Then** nothing is sent.

### User Story 2 - Drag a stem to move a bloom, with an exact preview (Priority: P1)

A player drags a bloom by its stem or head; while dragging, the exact shadow the bloom would cast at the cell under the
finger is previewed on the mist (the silhouette preview as exact diagnostic), with the match and leak it would give. On
release the bloom moves there; released outside the bed, the bloom is removed.

**Why this priority**: arranging blooms is the puzzle.

**Independent Test**: scripted drags of blooms send exactly one move (or removal) to the cell an independent pick
predicts; the preview cells equal the kernel's cells of the moved bloom.

**Acceptance Scenarios**:

1. **Given** a planted bloom, **When** it is dragged and released over another bed cell, **Then** one move to that cell
   is sent, and the preview shown during the drag equals the shadow the kernel computes there.
2. **Given** a planted bloom, **When** it is released outside the bed, **Then** one removal is sent.

### User Story 3 - Pinch to resize, slide the sun (Priority: P1)

A player pinches a bloom to make it larger or smaller among the level's allowed sizes, and drags the lantern up or down
to change the sun's elevation; each change is one move.

**Independent Test**: scripted pinches and lantern drags send exactly the resize or sun change an independent
computation predicts, or nothing.

### User Story 4 - Look around and come back (Priority: P2)

A player orbits the garden with two fingers within bounds and returns to the authored view; the view never changes the
game.

**Independent Test**: orbit stays within bounds at every aspect, the scene stays inside the view, and the digest never
changes.

### User Story 5 - Every move without gestures (Priority: P1)

A player who cannot drag precisely can do everything through the labelled panel (kind, column, row, size and bloom
pickers, plant, move, resize, remove, sun − and +, undo, redo, next level, "Reset view"), including winning every
certified level.

**Independent Test**: all 100 certified solutions are replayed through panel actions on the host and win.

### Edge Cases

- **A touch that never moves far enough:** a tap; two taps on empty space within 0.35 s and 22 points reset the view.
- **A touch that moves 10 … 16 points:** neither a tap nor a drag; nothing changes.
- **A finished play (won, failed or showing the result):** gestures send nothing and the description says the play is
  over (undo or next level); orbit still works.
- **No supply left of the chosen kind:** a tap on the bed sends the plant, and the kernel refuses it with its reason,
  shown to the player.
- **A second finger during a drag:** cancels it (nothing sent) and starts a pinch (on a bloom) or an orbit (elsewhere).
- **A cancelled touch:** changes nothing.
- **A drag released over the cell it started from:** nothing is sent (the kernel would refuse a no-op).
- **A bloom hidden behind another bloom:** picking takes the nearest bloom along the touch ray; the panel picker reaches
  every bloom.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G0904-001**: A tap on a bed cell not covered by a bloom while playing MUST send exactly one plant of the
  panel's kind and size at that cell; a tap elsewhere MUST change nothing.
- **FR-R02G0904-002**: A drag that starts on a bloom MUST, while it lasts, preview the exact shadow cells, match and
  leak of that bloom at the cell under the finger, and on release send exactly one move to that cell (nothing if it is
  the bloom's own cell) or one removal if released outside the bed.
- **FR-R02G0904-003**: A two-finger pinch that starts on a bloom MUST send at most one resize to the allowed size
  nearest the pinch's scale; a vertical drag that starts on the lantern MUST send at most one sun change to the
  elevation it reaches.
- **FR-R02G0904-004**: Picking MUST be analytic and deterministic: the touch ray through the drawn camera against the
  bed plane and the blooms, with a minimum touch target; blooms and the lantern win over the bed.
- **FR-R02G0904-005**: Two-finger orbit elsewhere MUST stay within stated bounds, keep the scene inside the view with a
  5 % margin at every aspect 0.4 … 2.5 and never enter the digest, the snapshot or the kernel; a double tap on empty
  space or "Reset view" returns to the authored view.
- **FR-R02G0904-006**: The panel MUST keep every action available without gestures and gain "Reset view"; every
  certified solution MUST be replayable through panel actions.
- **FR-R02G0904-007**: Gestures MUST be tested on the host by scripted pointer sequences and on the simulator through the
  experience's pointer entry; existing tests pass; every new public name is documented; refusals are logged with their
  reason code (observability).

### Key Entities

- **Gesture controller**: state (idle, bed press, bloom press or drag, lantern drag, pinch, orbiting, cancelled), the
  touched bloom, the start and last points, the last tap time and place.
- **Orbit**: yaw and pitch offsets from the authored view.
- **Drag preview**: the moved bloom's would-be shadow cells, match and leak (presentation only).
- **Gesture action**: plant, move, remove, resize, sun, resetView; all but resetView map onto declared controls.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G0904-001**: For 500 seeded scripted taps, drags, pinches and lantern drags on certified levels at several
  sizes and orbits, the actions sent equal an independent computation.
- **SC-R02G0904-002**: Second fingers, cancels and gestures on a finished play send no action in every scripted case.
- **SC-R02G0904-003**: Previews and orbit never change the digest in every scripted case; every drag preview equals the
  kernel's shadow of the moved bloom.
- **SC-R02G0904-004**: At every orbit within bounds and every aspect 0.4 … 2.5 the scene stays inside the view with a
  5 % margin.
- **SC-R02G0904-005**: All 100 certified levels are won through panel actions alone.
- **SC-R02G0904-006**: Existing tests pass; the reference regression passes 7 of 7; each test under 10 seconds.
- **SC-R02G0904-007** {device}: after ImplementationLock-100, touch feel and latency are checked on D1/D2/D3.

## Assumptions

- Hints, failure explanations and progression come in R02-G09-05; announcements, haptics and full accessibility in
  R02-G09-06; persistence in R02-G09-07. The snapshot schema stays 1 here (orbit, picks and previews are not saved).
- All gestures map onto the adapter's declared controls or onto presentation state; no new kernel action is added.
- Original design: all interaction and drawing are original code; no third-party assets or copied game designs.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Gesture-to-world actions (drag stems, pinch scale, slide sun elevation) | FR-R02G0904-001 … 004 |
| Silhouette preview as exact diagnostic | FR-R02G0904-002; SC-R02G0904-003 |
| Undo without ambiguity | FR-R02G0904-006 |
| Camera behaviour (constrained orbit, reset, no singularities) | FR-R02G0904-005 |
| Accessible alternative to every gesture | FR-R02G0904-006 |
| Deterministic tests, observability | FR-R02G0904-007; SC-R02G0904-001 … 005 |

## Negative Requirements / Excluded scope

- No free camera navigation, no gestures that change the rules, no hints, sounds or haptics, no device run before
  ImplementationLock-100, no availability before X-R02-G09.
