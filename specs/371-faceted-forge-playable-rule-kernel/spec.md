# Feature Specification: R02-G08-01 — Faceted Forge: playable rule kernel

**Feature Branch**: `371-faceted-forge-playable-rule-kernel` (spec directory only; work on `main`)

**Created**: 2026-11-22

**Status**: Clarified

**Ledger gate**: R02-G08-01 (migration ledger, game feature of experience R02-G08) · ID namespace FR-R02G0801-###,
SC-R02G0801-###, T-R02G0801-###

**Input**: User description: the archived R02-G08-01 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Implement deterministic state transition and exact win/failure evaluation" for Faceted Forge, with the canonical
overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/371-faceted-forge-playable-rule-kernel`; FR-R02G0801-###, SC-R02G0801-###,
  T-R02G0801-###.
- **Packaging (ADR-0009):** Faceted Forge is experience R02-G08 (`r02-g08.faceted-forge`, free) inside the single
  VisualCore app. The source's `Apps/FacetedForge` and `Packages/GameModules/FacetedForgeCore` become the experience
  module `Packages/ExperiencesRound02/FacetedForge`; this feature adds its pure Core with tests. Catalog registration,
  adapter and renderer come in later features of R02-G08 and its gate X-R02-G08.
- **Superseded parts of the source prompt:** the price and "no IAP" (free under the shared purchase controller); the Round
  2 lock and per-round device campaign (ImplementationLock-100). The content count 84 (the catalog's "84
  solver-certified stages") is produced in R02-G08-02. **Device-only items:** none (pure logic). **Owner-only items:**
  none.
- **Exactness:** every kernel rule is decided in exact rational arithmetic on integer planes (no floating point
  decides a cut, a volume, a face count, a win or a failure), so every device decides the same; the catalog's 0.008333 s
  timestep is the presentation clock of later features and never decides a rule.
- **Shared features used:** R02-F03 (numbers) and R02-F23 (puzzle contract: the kernel's rules are a puzzle contract, so
  R02-G08-02 can certify levels).
- **Model:** feature 361 (Amethyst Escape's rule kernel) for structure, stored form, records and refusals.

## Clarifications

### Session 2026-11-22

Answered autonomously under the owner's standing delegation, safest well-supported option each time, following feature
361's answers where the games agree. Facts checked in code (read-only, 2026-11-22): `Packages/ExperiencesRound02` holds
Aurora Loom … Amethyst Escape as the pattern (Core with level, play, records with previous and next fingerprints, rules
as R02-F23 `PuzzleRules`, `StableHash` fingerprints, `r02-gNN.*` reason codes); no `FacetedForge*` name exists;
VisualCore has no exact fraction type, so the kernel carries its own; the catalog sets the timestep at 0.008333 s and
the content at 84 stages.

- Q: What are the crystal, the plane directions and the depths, exactly? → A: 13 directions with components in
  {−1, 0, 1}, each named in words: the three axes (x, y, z), the six face diagonals (x+y, x−y, x+z, x−z, y+z, y−z) and
  the four body diagonals (x+y+z, x+y−z, x−y+z, −x+y+z). A plane is a direction n and an integer depth d (n·p = d),
  d in −24 … 24. The crystal is the intersection of 4 … 14 half-spaces n·p ≤ d built from those directions (either
  sign), bounded and inside the box −6 … 6 on every axis, with a non-empty interior; its corners are integer points.
  Impact: FR-R02G0801-001, 002, 013; SC-R02G0801-001.
- Q: What does a cut do, and when is it refused? → A: `cut(piece, direction, depth)` splits piece k (by its number in
  the canonical order) by the plane: the two new pieces are the piece with n·p ≤ d added and with n·p ≥ d added (the
  "below" and "above" halves). A cut is refused as degenerate (`r02-g08.miss`) unless at least one corner of the piece
  lies strictly on each side of the plane, so both halves have an interior. Pieces are kept in canonical order: by
  volume descending, then face count descending, then the sorted list of their exact corners; pieces are named "piece
  1" … in that order with their share ("a quarter", "3/16") and face count. Impact: FR-R02G0801-002, 003, 013.
- Q: How are corners, faces, volumes and the truth metric computed exactly? → A: every number is a reduced fraction of
  64-bit integers with checked arithmetic (an overflow refuses the action as `r02-g08.action`; the bounds above keep
  every denominator small). A piece's corners are the points where three of its bounding planes meet and every other
  plane is satisfied; a face is a bounding plane with at least three corners on it, its corners ordered round the
  face; the face count is the number of faces. The volume is the sum of signed tetrahedra from the piece's first corner
  over a fan triangulation of each face. The truth metric holds after every cut: the volumes sum to the crystal's and
  every edge lies on exactly two faces. Shares are volume / crystal volume. Impact: FR-R02G0801-002, 005, 014;
  SC-R02G0801-003.
- Q: In which order are sliver, win and budget decided, and from which stages can the player go back? → A: every
  accepted cut spends one cut; refused actions, undo and redo spend nothing. After a cut: sliver first (a new piece
  whose share is below the level's sliver limit fails the level, naming the piece and the cut), then win (the multiset
  of (share, face count) equals the target: won), then budget (cuts spent equal to the budget: failed). Undo and redo
  restore the exact earlier state; a new cut clears the redo stack. Undo works in playing and paused; from failed, undo
  returns to playing (an honest retry, recorded); a won level is final and refuses undo. Impact: FR-R02G0801-004, 005,
  007, 008; SC-R02G0801-002, 004.
- Q: How are records, fingerprints and stored forms defined? → A: as in R02-G07-01: every accepted action appends a
  record (schema, level seed, cut index, kind, operands, previous and next fingerprints); the play fingerprint is the
  SHA-256 of the schema, the level fingerprint, the pieces in canonical order (each as its bounding planes and exact
  corners), the cuts spent, the stage and the failure; levels are JSON schema 1 with sorted keys (crystal half-spaces,
  budget, sliver limit as a fraction, target entries as share fractions and face counts, tutorial flag, seed, id) and a
  fingerprint, re-checked on decode; reason codes `r02-g08.level`, `.action`, `.stage`, `.stale`, `.miss`,
  `.newer-schema`, `.malformed`. Impact: FR-R02G0801-006 … 011; SC-R02G0801-002, 005.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Cut the crystal into the target pieces (Priority: P1) 🎯

A player looks at a glowing convex crystal and a target: a list of pieces, each with its share of the crystal's volume
and its number of faces. The player picks a piece, chooses a cutting plane from a fixed set of directions and a depth,
and commits the cut: the piece splits into two convex pieces. When the pieces match the target exactly, the level is
won.

**Why this priority**: this is the whole game.

**Independent Test**: from a constructed level, a known sequence of cuts wins on its last cut; after every cut the
pieces' volumes and face counts equal an independent computation from the level and the cuts, and the volumes always
sum to the crystal's.

**Acceptance Scenarios**:

1. **Given** a level and its known solution, **When** its cuts are applied, **Then** the level is won exactly on the cut
   that makes the pieces match the target.
2. **Given** any action sequence, **When** it is applied twice, **Then** every state and the outcome are the same.

### User Story 2 - Make a sliver or run out of cuts (Priority: P1)

A cut that leaves a piece thinner than the level allows (a sliver) fails the level; so does spending the last cut
without a win. The reason, the piece and the cut are named.

**Independent Test**: scripted sequences end failed with the named reason on the exact cut.

### User Story 3 - Undo, redo and replay (Priority: P1)

The player undoes and redoes every cut exactly; a recorded trace replays to the same states everywhere.

**Independent Test**: 500 seeded traces replay identically; undo restores exact fingerprints.

### User Story 4 - The life of a level and its stored form (Priority: P2)

A level loads, may show a tutorial, plays, pauses and ends; levels have a versioned stored form that refuses damage.

**Independent Test**: the state machine refuses actions in the wrong stage; levels round-trip and damaged forms are
refused.

### Edge Cases

- **A plane that misses the piece or only touches it** (every vertex on one side or on the plane): the cut is refused as
  degenerate and spends nothing; no piece with an empty interior or a face of fewer than three corners can arise.
- **A sliver exactly at the limit:** a piece whose volume equals the level's sliver limit is allowed; one strictly below
  fails the level.
- **Win on the last cut:** a cut that makes the pieces match the target on the last cut of the budget wins.
- **Pieces in a different order:** the target is a multiset; any order of equal pieces matches.
- **Zero cuts:** a level is never won before the first cut (the target always has at least two pieces).
- **Actions after the end:** every action is refused once the level is won or failed, except undo.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G0801-001**: A level MUST define a convex crystal (integer vertices in a bounded box), the cut budget, the
  sliver limit (a fraction of the crystal's volume) and the target: a multiset of pieces, each a fraction of the
  crystal's volume and a face count, whose fractions sum to one.
- **FR-R02G0801-002**: A cut MUST name one current piece and a plane from the fixed set of directions with an integer
  depth; it MUST split that piece into exactly two convex pieces whose volumes sum exactly to the piece's volume, and
  leave every other piece unchanged.
- **FR-R02G0801-003**: A cut whose plane does not pass through the piece's interior MUST be refused without change.
- **FR-R02G0801-004**: Every accepted cut MUST spend one cut from the budget; undo and redo MUST spend nothing.
- **FR-R02G0801-005**: The level MUST be won exactly on the cut after which the multiset of (volume fraction, face count)
  of the pieces equals the target; it MUST fail with a named reason when a cut leaves a piece below the sliver limit
  (sliver) or when the last cut of the budget is spent without a win (budget).
- **FR-R02G0801-006**: Every action MUST be validated (range, stage, previous fingerprint, budget) and refused without
  change when invalid.
- **FR-R02G0801-007**: Undo and redo MUST restore exact states and fingerprints; replaying a record trace MUST reproduce
  every state.
- **FR-R02G0801-008**: The level's life MUST follow a defined state machine (loading, tutorial, playing, paused, won,
  failed, result).
- **FR-R02G0801-009**: Levels MUST have a versioned stored form with a fingerprint; damaged, edited and newer forms MUST
  be refused.
- **FR-R02G0801-010**: The rules MUST be expressible as a puzzle contract (R02-F23).
- **FR-R02G0801-011**: Invalid requests MUST be refused with stable reason codes `r02-g08.*`; existing modules unchanged.
- **FR-R02G0801-012**: The source's invariants this kernel owns (time, input budget, goal, repeatability, undo, failure
  honesty, stability, save, renderer purity) MUST each have a named direct test and a seeded neighbouring-input check.
- **FR-R02G0801-013**: Every piece, plane direction and target entry MUST be identifiable without colour vision: the
  kernel names them in words (piece number, its share of the crystal as a fraction, its face count, the direction's
  name and the depth), so later features can show them as text and shapes.
- **FR-R02G0801-014**: Every piece MUST stay a closed convex solid: every edge lies on exactly two faces and the volumes
  of all pieces always sum to the crystal's volume (the truth metric).

### Key Entities

- **Level**: crystal vertices, cut budget, sliver limit, target pieces, tutorial flag, fingerprint.
- **Piece**: a convex solid given by its bounding planes; its exact vertices, faces, face count and volume.
- **Plane**: one of the fixed directions and an integer depth.
- **Action**: cut (piece, direction, depth), undo, redo.
- **Play**: stage, pieces in canonical order, cuts spent, records, undo and redo stacks.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G0801-001**: For 500 seeded constructed levels the known solution wins and every refused action is refused
  with its named reason.
- **SC-R02G0801-002**: For 500 seeded action traces, replay reproduces every fingerprint and the outcome; undo of every
  action restores the exact earlier state.
- **SC-R02G0801-003**: Over 500 seeded levels and cut sequences, every piece's volume and face count equal an independent
  computation, the volumes sum to the crystal's and every edge lies on exactly two faces.
- **SC-R02G0801-004**: Sliver and budget each fail on the exact cut with the reason named, including the boundary cases
  at the sliver limit and one cut either side of the budget.
- **SC-R02G0801-005**: Levels round-trip exactly; damaged, edited and newer forms are refused.
- **SC-R02G0801-006**: Existing tests pass; the reference regression passes 7 of 7; each test under 10 seconds.

## Assumptions

- "Planes n·x = d" is read as integer normals from a fixed set of directions and integer depths, so every corner of
  every piece has rational coordinates and every volume is an exact fraction.
- "Within tolerance" is read as exact equality of fractions (a tolerance of zero), which every device decides alike.
- "Reject degenerate tiny faces" is read as refusing any cut that does not pass through the piece's interior, so no
  degenerate face can arise; thinness is judged by the sliver limit on volume.
- Bevels, interiors and dispersion are drawn later from the kernel's exact pieces; the rules never use floating point.
- Levels and their certification come in R02-G08-02; drawing in R02-G08-03; gestures R02-G08-04.
- The game design is the project's own archived design; the code is original.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Deterministic state transition (planes split convex polyhedra, oriented intersections, signed-tetrahedra volume) | FR-R02G0801-002, 003, 004, 006, 007, 008 |
| Exact win/failure evaluation (volume vector and face-class multiset; slivers or cuts exhausted) | FR-R02G0801-005 |
| Truth metric: volume conservation and manifold/edge incidence | FR-R02G0801-014; SC-R02G0801-003 |
| Puzzle contract for certification | FR-R02G0801-010 |
| Invariants INV-01 … 05 and INV-07 … 10 (INV-06 content belongs to R02-G08-02; INV-11 is superseded by the free tier; INV-12 novelty to R02-G08-02) | FR-R02G0801-012 |
| Accessibility (colour independence) | FR-R02G0801-013 |

## Negative Requirements / Excluded scope

- No rendering, gestures, generator, solver certification, adapter, catalog registration or persistence in this
  feature; no continuous physics of the split; no device run before ImplementationLock-100.
