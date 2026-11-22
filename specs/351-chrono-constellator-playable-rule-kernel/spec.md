# Feature Specification: R02-G06-01 — Chrono Constellator: playable rule kernel

**Feature Branch**: `351-chrono-constellator-playable-rule-kernel` (spec directory only; work on `main`)

**Created**: 2026-11-21

**Status**: Draft

**Ledger gate**: R02-G06-01 (migration ledger, game feature of experience R02-G06) · ID namespace FR-R02G0601-###,
SC-R02G0601-###, T-R02G0601-###

**Input**: User description: the archived R02-G06-01 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Implement deterministic state transition and exact win/failure evaluation" for Chrono Constellator, with the canonical
overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/351-chrono-constellator-playable-rule-kernel`; FR-R02G0601-###, SC-R02G0601-###,
  T-R02G0601-###.
- **Packaging (ADR-0009):** Chrono Constellator is experience R02-G06 (`r02-g06.chrono-constellator`, free) inside the
  single VisualCore app. The source's `Apps/ChronoConstellator` and `Packages/GameModules/ChronoConstellatorCore` become
  the experience module `Packages/ExperiencesRound02/ChronoConstellator`; this feature adds its pure Core with tests.
  Catalog registration, adapter and renderer come in later features of R02-G06 and its gate X-R02-G06.
- **Superseded parts of the source prompt:** the price and "no IAP" (free under the shared purchase controller); the Round
  2 lock and per-round device campaign (ImplementationLock-100). The content count 78 (the catalog's "78
  solver-certified stages") is produced in R02-G06-02. **Device-only items:** none (pure logic). **Owner-only items:**
  none.
- **Exactness:** every kernel rule is decided in integers (cells, phases and a fixed tick of 1/120 s, the catalog's
  0.008333 s timestep), so every device decides the same; nothing is integrated in floating point.
- **Shared features used:** R02-F03 (numbers) and R02-F23 (puzzle contract: the kernel's rules are a puzzle contract, so
  R02-G06-02 can certify levels).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Bring every star to its target on the same tick (Priority: P1) 🎯

A player looks at a small sky grid where a few stars each travel round their own fixed loop. The player sets where on
its loop each star starts and records short holds on the timeline (a star waits in place for a few ticks), then replays
the timeline; when every star stands on its own target cell on the same tick, the constellation is complete and the
level is won.

**Why this priority**: this is the whole game.

**Independent Test**: from a constructed level, a known timeline wins at the expected tick; every tick's star positions
equal an independent computation from the loops, the start phases and the holds.

**Acceptance Scenarios**:

1. **Given** a level and its known solution, **When** its timeline is replayed, **Then** the level is won exactly at the
   first tick on which every star stands on its target.
2. **Given** any timeline, **When** it is replayed twice, **Then** every tick's positions and the outcome are the same.

### User Story 2 - Collide or run out of time (Priority: P1)

Two stars on the same cell on the same tick, while the constellation is not complete, fail the level (a collision);
so does reaching the tick limit without a win. The reason, the stars and the cell are named.

**Independent Test**: scripted timelines end failed with the named reason at the exact tick.

### User Story 3 - Edit, rewind, undo, redo and replay (Priority: P1)

The player edits the timeline only at the start, replays it tick by tick or to the end, rewinds without ambiguity to the
start, and undoes and redoes every action exactly; a recorded trace replays to the same states everywhere.

**Independent Test**: 500 seeded traces replay identically; undo restores exact fingerprints.

### User Story 4 - The life of a level and its stored form (Priority: P2)

A level loads, may show a tutorial, plays, pauses and ends; levels have a versioned stored form that refuses damage.

**Independent Test**: the state machine refuses actions in the wrong stage; levels round-trip and damaged forms are
refused.

### Edge Cases

- **A hold at the very end:** a hold that would run past the tick limit is refused when it is entered.
- **Two stars meet on targets:** stars on their own (distinct) targets never collide; two stars cannot share a target.
- **Crossing on an edge:** two stars swapping neighbouring cells on one tick do not collide (only the same cell on the
  same tick counts), so the rule is decided from cells alone.
- **Win and collision on the same tick:** a complete constellation has every star on a distinct target, so a collision
  and a win never coincide.
- **Zero-time:** a level is never won at tick 0, even when the start phases already place every star on its target.
- **Editing during a replay:** refused until the timeline is rewound to the start.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G0601-001**: A level MUST define a small rectangular sky grid, two or more stars each with a closed loop of
  neighbouring cells (its orbit) and a target cell on that loop, the edit budget and the tick limit.
- **FR-R02G0601-002**: Each tick MUST move every star one cell along its loop unless the timeline holds it on that tick;
  positions are computed from the loop, the star's start phase and its holds alone.
- **FR-R02G0601-003**: The timeline MUST be an event log of tick-indexed actions (start phases and holds) that replays
  with a fixed step; the same timeline MUST give the same positions on every tick on every device.
- **FR-R02G0601-004**: Setting a star's start phase or adding or removing a hold MUST spend edits from the budget and be
  allowed only at the start of the timeline; stepping and rewinding MUST spend nothing.
- **FR-R02G0601-005**: The level MUST be won exactly at the first tick after the start on which every star stands on its
  own target; it MUST fail with a named reason when two stars stand on the same cell on the same tick before a win
  (collision), or when the tick limit is reached without a win (time).
- **FR-R02G0601-006**: Every action MUST be validated (range, stage, previous fingerprint, budget) and refused without
  change when invalid.
- **FR-R02G0601-007**: Undo and redo MUST restore exact states and fingerprints; replaying a record trace MUST reproduce
  every state.
- **FR-R02G0601-008**: The level's life MUST follow a defined state machine (loading, tutorial, playing, paused, won,
  failed, result).
- **FR-R02G0601-009**: Levels MUST have a versioned stored form with a fingerprint; damaged, edited and newer forms MUST
  be refused.
- **FR-R02G0601-010**: The rules MUST be expressible as a puzzle contract (R02-F23).
- **FR-R02G0601-011**: Invalid requests MUST be refused with stable reason codes `r02-g06.*`; existing modules unchanged.
- **FR-R02G0601-012**: The source's invariants this kernel owns (time, input budget, goal, repeatability, undo, failure
  honesty, stability, save, renderer purity) MUST each have a named direct test and a seeded neighbouring-input check.
- **FR-R02G0601-013**: Each star MUST be identifiable without colour vision: the kernel names every star, its loop and its
  target in words and positions, so later features can show them as text and shapes.

### Key Entities

- **Level**: grid size, stars (loop, target), edit budget, tick limit, tutorial flag, fingerprint.
- **Timeline**: start phase per star and the holds (star, tick, length), with the edits spent.
- **Action**: phase (star, offset), hold (star, tick, length), release (hold), step (ticks), rewind, undo, redo.
- **Play**: stage, tick, timeline, star positions, edits spent, records, undo and redo stacks.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G0601-001**: For 500 seeded constructed levels the known solution wins and every refused action is refused
  with its named reason.
- **SC-R02G0601-002**: For 500 seeded action traces, replay reproduces every fingerprint and the outcome; undo of every
  action restores the exact earlier state.
- **SC-R02G0601-003**: Over 500 seeded levels and timelines run to their tick limit, every tick's star positions equal an
  independent brute-force computation from the loops, phases and holds.
- **SC-R02G0601-004**: Collision and time each fail at the exact tick with the reason named, including the boundary cases
  one tick either side of each limit.
- **SC-R02G0601-005**: Levels round-trip exactly; damaged, edited and newer forms are refused.
- **SC-R02G0601-006**: Existing tests pass; the reference regression passes 7 of 7; each test under 10 seconds.

## Assumptions

- "Stable target topology" is read as: the target constellation (each star's target cell and so the shape they form)
  is fixed by the level and never changes during play, and a win needs every star on its own distinct target at once.
- Ribbons, trails and glow are drawn later from the kernel's integers; the rules never use floating point.
- Levels and their certification come in R02-G06-02; drawing in R02-G06-03; gestures R02-G06-04.
- The game design is the project's own archived design; the code is original.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Deterministic state transition (event log of tick-indexed actions, fixed-step replay) | FR-R02G0601-002, 003, 004, 006, 007, 008 |
| Exact win/failure evaluation (same-tick alignment; collision in the synchronisation window) | FR-R02G0601-005 |
| Truth metric: tick-accurate replay hash and synchronised target occupancy | FR-R02G0601-003, 007; SC-R02G0601-002, 003 |
| Signed snapshots | FR-R02G0601-007, 009 (fingerprints) |
| Puzzle contract for certification | FR-R02G0601-010 |
| Invariants INV-01 … 05 and INV-07 … 10 (INV-06 content belongs to R02-G06-02; INV-11 is superseded by the free tier; INV-12 novelty to R02-G06-02) | FR-R02G0601-012 |
| Accessibility (colour independence) | FR-R02G0601-013 |

## Negative Requirements / Excluded scope

- No rendering, gestures, generator, solver certification, adapter, catalog registration or persistence in this
  feature; no continuous orbital integration; no device run before ImplementationLock-100.
