# Feature Specification: R02-G06-04 — Chrono Constellator: gameplay spatial interaction

**Feature Branch**: `354-chrono-constellator-gameplay-spatial-interaction` (spec directory only; work on `main`)

**Created**: 2026-11-21

**Status**: Draft

**Ledger gate**: R02-G06-04 (migration ledger, game feature of experience R02-G06) · ID namespace FR-R02G0604-###,
SC-R02G0604-###, T-R02G0604-###

**Input**: User description: the archived R02-G06-04 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Implement native gesture-to-world actions, undo and camera behavior" for Chrono Constellator (the design's controls:
"scrub timeline; drag a star start marker; record and rewind without ambiguity"), with the canonical overrides of
ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/354-chrono-constellator-gameplay-spatial-interaction`; FR-R02G0604-###,
  SC-R02G0604-###, T-R02G0604-###.
- **Packaging (ADR-0009):** the gestures live in the experience `r02-g06.chrono-constellator` (a registered candidate
  since R02-G06-03) inside the one app; the source's `Apps/ChronoConstellator` and `Packages/GameModules` paths are
  superseded.
- **Superseded parts of the source prompt:** price, "no IAP" and the Round 2 lock. The source's "content count 78" is a
  milestone figure; the 100 certified levels of R02-G06-02 stand. **Device-only items:** touch feel and latency on
  D1/D2/D3, recorded as `{device}` tasks for after ImplementationLock-100. **Owner-only items:** none.
- **Shared features used:** R02-F14 (deterministic timeline and reversible history), R02-F22 (spatial controls and
  analytic picking), R02-F26 (input and accessibility contract), the experience host's pointer events, and the kernel,
  content, adapter and renderer of R02-G06-01 … 03.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Drag a star's start marker (Priority: P1) 🎯

Before replaying, a player drags a star along its silver loop and lets go on another cell of that loop; the star now
starts there. While dragging, the cell the star would start on is highlighted and named; exactly one start-phase change
is made when the finger lifts.

**Why this priority**: changing a star's start phase is the game's main move.

**Independent Test**: scripted drags from stars to loop cells of certified levels produce exactly the phase change an
independent picking computation predicts, or none.

**Acceptance Scenarios**:

1. **Given** a level at tick 0, **When** a drag starts on a star and ends over another cell of that star's loop,
   **Then** exactly one start-phase change of that star to that cell's loop position is sent on release.
2. **Given** a drag that starts on empty space, a target or a track, or ends off the star's loop, **When** it is
   released, **Then** no start-phase change is sent.
3. **Given** a replay in progress (tick above 0), **When** a star is dragged, **Then** nothing is sent and the player is
   told that edits are made at tick 0 (rewind first).

### User Story 2 - Scrub the timeline (Priority: P1)

A player drags along the timeline bar at the near edge of the sky to move the replay to a tick; the stars and ribbons
follow. Scrubbing back rewinds and replays to the chosen tick, so the shown state is always the deterministic replay.

**Why this priority**: seeing the motion at any tick is how the player finds the alignment.

**Independent Test**: scripted scrubs to seeded ticks end at the tick an independent computation predicts with the
digest equal to a plain replay of the same timeline to that tick.

**Acceptance Scenarios**:

1. **Given** a play at tick t, **When** the player scrubs to a later tick t′, **Then** the replay advances to t′ (or stops
   at the deciding tick).
2. **Given** a play at tick t, **When** the player scrubs to an earlier tick t′, **Then** the replay rewinds and advances
   to t′, ending in the same state as a fresh replay to t′.

### User Story 3 - Record a hold and rewind (Priority: P1)

A player records a short hold for a star (the star waits for some ticks) with a gesture on the star, removes it again,
and rewinds to tick 0 at any time; every change can be undone and redone.

**Independent Test**: scripted hold and release gestures send exactly the hold or release actions predicted; rewind
returns to tick 0 keeping the timeline; undo and redo restore the digests.

### User Story 4 - Look around and come back (Priority: P2)

A player orbits the sky with two fingers within bounds and returns to the authored view; the view never changes the
game.

**Independent Test**: orbit stays within bounds at every aspect, the scene stays inside the view, and the digest never
changes.

### User Story 5 - Every move without gestures (Priority: P1)

A player who cannot drag precisely can do everything through the labelled panel (star picker, phase − and +, hold add
and remove, steps, run, rewind, undo, redo, next level), including winning every certified level.

**Independent Test**: all 100 certified witnesses are replayed through panel actions on the host and win.

### Edge Cases

- **A touch that never moves far enough:** a tap; it selects the star under it in the panel and sends nothing.
- **A second finger during a drag or scrub:** cancels it (nothing sent) and orbits.
- **A cancelled touch:** sends nothing.
- **Won or failed play:** star drags and holds send nothing; scrubbing and rewind follow the kernel's rules (a won play
  is final, a failed play may rewind); orbit still works.
- **A star whose loop cells are hidden behind its own node:** picking prefers the star node at touch-down and the loop
  cell under the finger at release.
- **The edit budget is used up:** the kernel refuses the change and the refusal is shown; nothing else changes.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G0604-001**: At tick 0, a drag that starts on a star and ends over another cell of that star's loop MUST send
  exactly one start-phase change of that star on release; any other drag MUST send no phase change.
- **FR-R02G0604-002**: A drag along the timeline bar MUST move the replay to the tick under the finger on release by
  stepping forward or by rewinding and stepping; the resulting state MUST equal a plain replay to that tick.
- **FR-R02G0604-003**: A hold gesture on a star at tick 0 MUST record or remove a hold for that star with the kernel's
  hold and release actions; rewind, undo and redo MUST be reachable without gestures.
- **FR-R02G0604-004**: Picking MUST be analytic and deterministic: the touch ray through the drawn camera against the
  star nodes, the loop cells and the timeline bar, with a minimum touch target.
- **FR-R02G0604-005**: Two-finger orbit MUST stay within bounded yaw and pitch, keep the scene inside the view at every
  aspect 0.4 … 2.5 and never enter the digest, the snapshot or the kernel; a reset returns to the authored view.
- **FR-R02G0604-006**: While dragging, the candidate cell or tick MUST be highlighted and described; nothing changes in
  the kernel until release.
- **FR-R02G0604-007**: The panel MUST keep every action available without gestures and gain "Reset view"; every
  certified witness MUST be replayable through panel actions.
- **FR-R02G0604-008**: Gestures MUST be tested on the host by scripted pointer sequences and on the simulator through
  the experience's pointer entry; existing tests pass; every new public name is documented; refusals are logged with
  their reason code (observability).

### Key Entities

- **Gesture controller**: state (idle, star drag, scrub, hold press, orbiting, cancelled), picked star, start point,
  last points.
- **Orbit**: yaw and pitch offsets from the authored view.
- **Gesture action**: phase(star, offset), scrub(tick), hold(star, start, length), release(star, start) or resetView,
  each mapped onto the declared controls.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G0604-001**: For 500 seeded scripted drags, scrubs and taps on certified levels at several sizes and orbits,
  the actions sent equal an independent computation of the touched star, cell or tick.
- **SC-R02G0604-002**: Second fingers, cancels and edits after tick 0 send no edit in every scripted case.
- **SC-R02G0604-003**: Scrubbing to any tick ends in the same digest as a plain replay to that tick in every scripted
  case.
- **SC-R02G0604-004**: At every orbit within bounds and every aspect 0.4 … 2.5 the scene stays inside the view with a
  5 % margin, and the digest never changes.
- **SC-R02G0604-005**: All 100 certified levels are won through panel actions alone.
- **SC-R02G0604-006**: Existing tests pass; the reference regression passes 7 of 7; each test under 10 seconds.
- **SC-R02G0604-007** {device}: after ImplementationLock-100, touch feel and latency are checked on D1/D2/D3.

## Assumptions

- Hints, failure explanations and progression come in R02-G06-05; announcements, haptics and full accessibility in
  R02-G06-06; persistence in R02-G06-07. The snapshot schema stays 1 here (no schema migration in this feature; the
  orbit is not saved).
- All gestures map onto the adapter's declared controls; no new kernel action is added.
- Original design: all interaction and drawing are original code; no third-party assets or copied game designs.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Gesture-to-world actions (drag a star start marker, scrub the timeline, record holds) | FR-R02G0604-001 … 004 |
| Undo, record and rewind without ambiguity | FR-R02G0604-003, 007 |
| Camera behaviour (constrained orbit, reset, no singularities) | FR-R02G0604-005 |
| Accessible alternative to every gesture | FR-R02G0604-007 |
| Deterministic tests, observability | FR-R02G0604-008; SC-R02G0604-001 … 005 |

## Negative Requirements / Excluded scope

- No free camera navigation, no gestures that change the rules, no hints, sounds or haptics, no device run before
  ImplementationLock-100, no availability before X-R02-G06.
