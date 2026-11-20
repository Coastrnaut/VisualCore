# Feature Specification: R02-G03-01 — Wave Knot Keeper: playable rule kernel

**Feature Branch**: `321-wave-knot-keeper-playable-rule-kernel` (spec directory only; work on `main`)

**Created**: 2026-11-20

**Status**: Clarified

**Ledger gate**: R02-G03-01 (migration ledger, game feature of experience R02-G03) · ID namespace FR-R02G0301-###,
SC-R02G0301-###, T-R02G0301-###

**Input**: User description: the archived R02-G03-01 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Implement deterministic state transition and exact win/failure evaluation" for Wave Knot Keeper, with the canonical
overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/321-wave-knot-keeper-playable-rule-kernel`; FR-R02G0301-###, SC-R02G0301-###,
  T-R02G0301-###.
- **Packaging (ADR-0009):** Wave Knot Keeper is experience R02-G03 (`r02-g03.wave-knot-keeper`, free) inside the single
  VisualCore app. The source's `Apps/WaveKnotKeeper` and `Packages/GameModules/WaveKnotKeeperCore` become the experience
  module `Packages/ExperiencesRound02/WaveKnotKeeper`; this feature adds its pure Core with tests. Catalog registration,
  adapter and renderer come in later features of R02-G03 and its gate X-R02-G03.
- **Superseded parts of the source prompt:** the price and "no IAP" (free under the shared purchase controller); the Round
  2 lock and per-round device campaign (ImplementationLock-100); the source's "content count 72" (the canonical catalog is
  the 100-level manifest, generated in R02-G03-02). **Device-only items:** none (pure logic). **Owner-only items:** none.
- **Shared features used:** R02-F03 (numbers) and R02-F23 (puzzle contract: the kernel's rules are a `PuzzleRules`, so
  R02-G03-02 can certify levels).

## Clarifications

### Session 2026-11-20

Answered autonomously under the owner's standing delegation, safest well-supported option each time. Facts checked in
code (read-only audit, 2026-11-20): `Packages/ExperiencesRound02` holds Aurora Loom and Lissajous Labyrinth as the
pattern (Core with level, play, records with previous and next fingerprints, rules as R02-F23 `PuzzleRules`, `StableHash`
fingerprints, `r02-gNN.*` reason codes); no `WaveKnotKeeper*` name exists.

- Q: How is the rope represented exactly? → A: a closed polygon of 6 … 16 control points with integer coordinates in
  −16 … 16 on each axis; segment i joins point i to point i + 1 (the last to the first). No two control points coincide.
  The drawn spline (later features) passes through these points; all rules use the polygon, in exact integers.
  Impact: FR-R02G0301-001; SC-R02G0301-003.
- Q: When is a move legal? → A: a move shifts one control point P by one unit along ±x, ±y or ±z to P′, inside the
  bounds and not onto another point. With neighbours A and B, the move sweeps the triangles A-P-P′ and P-P′-B; it is
  refused (`r02-g03.move("crossing")`) when either triangle intersects any segment not adjacent to P (decided exactly in
  integers: segment-triangle intersection with orientation tests), unless both P and P′ lie inside one crossing gate (an
  axis-aligned integer box), where strands may pass. Impact: FR-R02G0301-002; SC-R02G0301-001.
- Q: What decides a win, and what is the knot signature? → A: the rope is projected onto the xy-plane. For every pair of
  non-adjacent segments whose projections cross at a single interior point, a crossing is counted with sign +1 or −1 by
  the right-hand rule of the over-strand (larger z at the crossing) and under-strand directions. The summary is the
  crossing count and the writhe (sum of signs); the signature is the crossing count and writhe together. A projection is
  degenerate when two non-adjacent projected segments overlap collinearly, touch at an endpoint, or have equal z at a
  crossing; a degenerate projection never wins. The level is won exactly when the projection is not degenerate and the
  summary equals the target (crossing count, writhe). Impact: FR-R02G0301-003; SC-R02G0301-003.
- Q: What is the tension bound and how is failure decided? → A: the tension is the sum over segments of the squared
  length (an integer). A move that would make it exceed the level's bound is refused (`r02-g03.move("tension")`); the
  level fails when the allowance is spent without a win, with the final summary as the explanation. Impact:
  FR-R02G0301-003; SC-R02G0301-004.
- Q: How are records, fingerprints and stored forms defined? → A: as in R02-G02-01: every accepted move, undo and redo
  appends a record (schema, level seed, tick, kind, point, direction, previous and next fingerprints); the play
  fingerprint is the SHA-256 of the schema, level fingerprint, points, moves spent and stage; levels are JSON schema 1
  with sorted keys and a fingerprint, re-checked on decode; reason codes `r02-g03.level`, `.move`, `.stage`, `.stale`,
  `.allowance`, `.newer-schema`, `.malformed`. Impact: FR-R02G0301-004 … 009; SC-R02G0301-002, 005.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Untie the knot (Priority: P1) 🎯

A player moves the control points of a closed glowing rope one lattice step at a time; the rope may never pass through
itself except through the level's crossing gates; when its projected crossings and knot signature match the target, the
level is won.

**Why this priority**: this is the whole game.

**Independent Test**: from a constructed level whose target is reachable, a known sequence of moves wins; every move that
would pass a strand through another outside a gate is refused.

**Acceptance Scenarios**:

1. **Given** a level and its known solution, **When** the moves are applied, **Then** the level is won exactly after the
   last move.
2. **Given** a move whose path would cut through another part of the rope outside a crossing gate, **When** it is
   attempted, **Then** it is refused with a named reason and nothing changes.

### User Story 2 - Run out of moves or overstretch (Priority: P1)

Spending the move allowance without matching the target, or stretching the rope beyond its tension bound, fails the
level with the reason shown.

**Independent Test**: scripted plays end failed with the named reason.

### User Story 3 - Undo, redo and replay (Priority: P1)

Every move can be undone and redone exactly; a recorded trace replays to the same states everywhere.

**Independent Test**: 500 seeded traces replay identically; undo restores exact fingerprints.

### User Story 4 - The life of a level and its stored form (Priority: P2)

A level loads, may show a tutorial, plays, pauses and ends; levels have a versioned stored form that refuses damage.

**Independent Test**: the state machine refuses actions in the wrong stage; levels round-trip and damaged forms are
refused.

### Edge Cases

- **A move that changes nothing, leaves the lattice bounds, or makes two control points coincide:** refused.
- **A move through a crossing gate:** allowed; it may change the crossings.
- **A rope whose crossings match but whose signature does not:** not won.
- **Degenerate projections (two crossings at one point, a vertical segment):** decided by an exact rule, the same on
  every device.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G0301-001**: A level MUST define a closed rope of control points on an integer lattice, the crossing gates,
  the target (projected crossing count and signature), the tension bound and the move allowance.
- **FR-R02G0301-002**: Every move MUST move one control point by one lattice step; it MUST be refused when the swept
  rope would pass through any non-adjacent part of itself outside a crossing gate, decided exactly in integers.
- **FR-R02G0301-003**: The level MUST be won exactly when the projected signed crossings and the knot signature equal the
  target; it MUST fail when the allowance is spent without a win or a move exceeds the tension bound.
- **FR-R02G0301-004**: Every action MUST be validated (range, bounds, stage, previous fingerprint, allowance) and
  refused without change when invalid.
- **FR-R02G0301-005**: Undo and redo MUST restore exact states and fingerprints; replaying a record trace MUST reproduce
  every state.
- **FR-R02G0301-006**: The level's life MUST follow a defined state machine (loading, tutorial, playing, paused, won,
  failed, result).
- **FR-R02G0301-007**: Levels MUST have a versioned stored form with a fingerprint; damaged, edited and newer forms MUST
  be refused.
- **FR-R02G0301-008**: The rules MUST be expressible as a puzzle contract (R02-F23).
- **FR-R02G0301-009**: Invalid requests MUST be refused with stable reason codes `r02-g03.*`; existing modules unchanged.
- **FR-R02G0301-010**: The source's invariants this kernel owns (time, input budget, goal, repeatability, undo, failure
  honesty, stability, save) MUST each have a named direct test and a seeded neighbouring-input check.

### Key Entities

- **Level**: control points, crossing gates, target, tension bound, allowance, tutorial flag, fingerprint.
- **Move**: control point index, direction (one of six lattice steps).
- **Play**: stage, points, moves spent, records, undo and redo stacks.
- **Crossing summary**: projected crossings with signs, crossing count, signature.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G0301-001**: For 500 seeded constructed levels the known solution wins and every single refused move is
  refused with its named reason.
- **SC-R02G0301-002**: For 500 seeded action traces, replay reproduces every fingerprint and the outcome; undo of every
  move restores the exact earlier state.
- **SC-R02G0301-003**: The crossing evaluation is invariant under translating the whole rope and equal to an independent
  brute-force projection count on 500 seeded ropes.
- **SC-R02G0301-004**: Spending the allowance or exceeding the tension bound fails with the reason named.
- **SC-R02G0301-005**: Levels round-trip exactly; damaged, edited and newer forms are refused.
- **SC-R02G0301-006**: Existing tests pass; the reference regression passes 7 of 7; each test under 10 seconds.

## Assumptions

- The smooth spline drawn later passes through the control points; the rules use the closed control polygon, which the
  rope's drawn form follows, so exactness does not depend on floating point.
- Levels and their certification come in R02-G03-02; drawing in R02-G03-03; gestures R02-G03-04.
- The game design is the project's own archived design; the code is original.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Deterministic state transition | FR-R02G0301-002, 004, 005, 006 |
| Exact win/failure evaluation | FR-R02G0301-003 |
| Minimum clearance and crossing gates | FR-R02G0301-002 |
| Puzzle contract for certification | FR-R02G0301-008 |
| Invariants INV-01 … INV-08 | FR-R02G0301-010 |

## Negative Requirements / Excluded scope

- No rendering, gestures, generator, solver certification, adapter, catalog registration or persistence in this
  feature; no device run before ImplementationLock-100.
