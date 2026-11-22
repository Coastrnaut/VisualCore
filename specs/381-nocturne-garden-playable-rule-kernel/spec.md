# Feature Specification: R02-G09-01 — Nocturne Garden: playable rule kernel

**Feature Branch**: `381-nocturne-garden-playable-rule-kernel` (spec directory only; work on `main`)

**Created**: 2026-11-22

**Status**: Clarified

**Ledger gate**: R02-G09-01 (migration ledger, game feature of experience R02-G09) · ID namespace FR-R02G0901-###,
SC-R02G0901-###, T-R02G0901-###

**Input**: User description: the archived R02-G09-01 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Implement deterministic state transition and exact win/failure evaluation" for Nocturne Garden, with the canonical
overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/381-nocturne-garden-playable-rule-kernel`; FR-R02G0901-###, SC-R02G0901-###,
  T-R02G0901-###.
- **Packaging (ADR-0009):** Nocturne Garden is experience R02-G09 (`r02-g09.nocturne-garden`, free) inside the single
  VisualCore app. The source's `Apps/NocturneGarden` and `Packages/GameModules/NocturneGardenCore` become the experience
  module `Packages/ExperiencesRound02/NocturneGarden`; this feature adds its pure Core with tests. Catalog registration,
  adapter and renderer come in later features of R02-G09 and its gate X-R02-G09.
- **Superseded parts of the source prompt:** the price and "no IAP" (free under the shared purchase controller); the
  Round 2 lock and per-round device campaign (ImplementationLock-100). The content count 76 (the catalog's "76
  solver-certified stages") is produced in R02-G09-02. **Device-only items:** none (pure logic). **Owner-only items:**
  none.
- **Exactness:** every kernel rule is decided in exact integer arithmetic on a grid (no floating point decides a shadow
  cell, an overlap, a win or a failure), so every device decides the same; the catalog's 0.016667 s timestep is the
  presentation clock of later features and never decides a rule.
- **Shared features used:** R02-F03 (numbers) and R02-F23 (puzzle contract: the kernel's rules are a puzzle contract, so
  R02-G09-02 can certify levels).
- **Model:** feature 371 (Faceted Forge's rule kernel) for structure, stored form, records and refusals.

## Clarifications

### Session 2026-11-22

Answered autonomously under the owner's standing delegation, safest well-supported option each time, following feature
371's answers where the games agree. Facts checked in code (read-only, 2026-11-22): `Packages/ExperiencesRound02` holds
Aurora Loom … Faceted Forge as the pattern (Core with level, play, records with previous and next fingerprints, rules
as R02-F23 `PuzzleRules`, `StableHash` fingerprints, `r02-gNN.*` reason codes); no `NocturneGarden*` name exists; the
catalog sets the timestep at 0.016667 s, the content at 76 stages and the controls "drag stems, pinch scale, slide sun
elevation".

- Q: What are the bed, the blooms, their outlines, sizes and the sun, exactly? → A: the bed is a grid of W × H cells, W
  in 16 … 32 and H in 12 … 24, cell (c, r) with c counted from the left and r from the ground row upward. There are six
  bloom kinds, each named in words (tulip, bell, star, fern, rose, lily), each a fixed simple polygon with integer
  vertices in a local frame whose origin is the stem's foot, the stem rising along +y, at most 16 vertices, at most 3
  cells wide and 6 cells tall at size 1. A bloom is planted at an anchor cell (its foot at that cell's bottom-left
  corner, so the foot is the lattice point (c, r)) with a size s in 1 … 3 (the outline scaled by s). The sun elevation e
  is one of four steps, 1 (high) … 4 (low), and stretches every shadow vertically by the factor f = e / 2 (1/2, 1, 3/2,
  2) about the bloom's foot: a vertex (x, y) of the scaled outline casts (c + x, r + f·y). Impact: FR-R02G0901-001, 002,
  003, 013; SC-R02G0901-001.
- Q: How does a shadow become cells, exactly? → A: a cell (c, r) of the bed is dark for a bloom when its centre
  (c + 1/2, r + 1/2) lies inside the bloom's cast polygon or on its boundary; with every coordinate doubled (and the
  factor's denominator cleared) the test is an exact integer winding-number test with boundary points counted as inside.
  The garden's shadow mask is the union over all planted blooms, clipped to the bed. The match is |M ∩ T| / |M ∪ T|
  over the mask M and target T (0 when both are empty), compared with the required fraction p / q by cross
  multiplication; the leak is |M ∩ F| over the forbidden cells F. Impact: FR-R02G0901-003, 005, 014; SC-R02G0901-003.
- Q: Which actions exist, what does each cost, and when is one refused? → A: `plant(kind, col, row, size)`,
  `move(bloom, col, row)`, `resize(bloom, size)`, `remove(bloom)` and `sun(elevation)`; each accepted action spends one
  move. Refused without change: an anchor outside the bed or a size or elevation out of range (`r02-g09.action`); a kind
  whose supply is used up (`r02-g09.supply`); a bloom number that does not exist (`r02-g09.action`); an action that
  changes nothing (moving to the same cell, the same size, the same elevation: `r02-g09.noop`); a wrong stage
  (`r02-g09.stage`) or a stale fingerprint (`r02-g09.stale`). Two blooms may share an anchor. Blooms are kept in
  canonical order (row, then column, then kind, then size) and named "bloom 1" … in that order with their kind, cell and
  size; removing a bloom returns it to the supply. Impact: FR-R02G0901-002, 004, 006, 011, 013.
- Q: In which order are leak, win and budget decided, and from which stages can the player go back? → A: after an
  accepted action: leak first (a leak above the allowance fails the level, naming the action and its bloom, or the sun),
  then win (match at least p / q and leak within the allowance: won), then budget (moves spent equal to the budget:
  failed). Undo and redo restore the exact earlier state; a new action clears the redo stack. Undo works in playing and
  paused; from failed, undo returns to playing (an honest retry, recorded); a won level is final and refuses undo. The
  boundary deviation (truth metric) is the symmetric grid Hausdorff distance in Chebyshev cells between the boundary
  cells of M and of T (a boundary cell is a cell of the set with a 4-neighbour outside it or at the bed's edge); it is
  reported after every action and never decides the outcome. Impact: FR-R02G0901-004, 005, 007, 008, 014;
  SC-R02G0901-002, 004.
- Q: How are records, fingerprints and stored forms defined? → A: as in R02-G08-01: every accepted action appends a
  record (schema, level seed, move index, kind, operands, previous and next fingerprints); the play fingerprint is the
  SHA-256 of the schema, the level fingerprint, the blooms in canonical order, the sun elevation, the moves spent, the
  stage and the failure; levels are JSON schema 1 with sorted keys (bed size, target and forbidden cells as sorted
  row-major indices, supply, size and elevation ranges, budget, required match as a fraction, leak allowance, opening sun
  elevation, tutorial flag, seed, id) and a fingerprint, re-checked on decode; reason codes `r02-g09.level`, `.action`,
  `.supply`, `.noop`, `.stage`, `.stale`, `.newer-schema`, `.malformed`. Impact: FR-R02G0901-006 … 011;
  SC-R02G0901-002, 005.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Cast the target silhouette (Priority: P1) 🎯

A player sees a garden bed, a target silhouette (the dark flower shape to make) and a few forbidden outline regions
around it. The player plants glowing blooms from the level's supply at grid positions and sizes and sets the sun's
elevation, which lengthens or shortens every shadow. The blooms' shadows together form a dark mask; when that mask
covers the target closely enough and keeps out of the forbidden regions, the level is won.

**Why this priority**: this is the whole game.

**Independent Test**: from a constructed level, a known arrangement wins on its last action; after every action the
shadow mask, its overlap with the target and with the forbidden regions equal an independent computation.

**Acceptance Scenarios**:

1. **Given** a level and its known arrangement, **When** its actions are applied, **Then** the level is won exactly on
   the action that makes the match good enough with no leak over the limit.
2. **Given** any action sequence, **When** it is applied twice, **Then** every state and the outcome are the same.

### User Story 2 - Leak into the forbidden outline or run out of moves (Priority: P1)

An action that lets the shadow spill into the forbidden regions beyond the level's allowance fails the level; so does
spending the last move without a win. The reason, the bloom and the action are named.

**Independent Test**: scripted sequences end failed with the named reason on the exact action.

### User Story 3 - Undo, redo and replay (Priority: P1)

The player undoes and redoes every action exactly; a recorded trace replays to the same states everywhere.

**Independent Test**: 500 seeded traces replay identically; undo restores exact fingerprints.

### User Story 4 - The life of a level and its stored form (Priority: P2)

A level loads, may show a tutorial, plays, pauses and ends; levels have a versioned stored form that refuses damage.

**Independent Test**: the state machine refuses actions in the wrong stage; levels round-trip and damaged forms are
refused.

### Edge Cases

- **A bloom placed partly outside the bed:** only the cells inside the bed count; a placement whose anchor lies outside
  the bed is refused (`r02-g09.action`).
- **An action that changes nothing:** moving a bloom to its own cell, resizing to its own size or setting the same sun
  elevation is refused (`r02-g09.noop`) and spends nothing.
- **Overlapping blooms:** shadows combine as a union; a cell is dark once whatever number of shadows cover it.
- **A match exactly at the requirement:** a match equal to the required fraction wins; one below does not.
- **A leak exactly at the allowance:** a leak equal to the allowance is allowed; one cell more fails the level.
- **Win on the last move:** an action that wins on the last move of the budget wins.
- **An empty bed:** a level is never won before the first bloom is planted.
- **Actions after the end:** every action is refused once the level is won or failed, except undo.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G0901-001**: A level MUST define the garden bed (a grid of cells), the target silhouette (a set of cells), the
  forbidden regions (a set of cells apart from the target), the bloom supply (kinds and counts), the allowed sizes and
  sun elevations, the move budget, the required match and the leak allowance.
- **FR-R02G0901-002**: Planting MUST place one bloom of a supplied kind at a grid cell with an allowed size; moving,
  resizing and removing a planted bloom and setting the sun elevation MUST change only what they name.
- **FR-R02G0901-003**: Each bloom's shadow MUST be its exact outline stretched by the sun elevation and turned into grid
  cells by a fixed, exact rule; the garden's shadow mask MUST be the union of all blooms' shadows within the bed.
- **FR-R02G0901-004**: Every accepted action MUST spend one move; undo and redo MUST spend nothing.
- **FR-R02G0901-005**: The level MUST be won exactly on the action after which the match (shared cells of mask and
  target divided by cells in either) reaches the required fraction and the leak (mask cells in the forbidden regions) is
  within the allowance; it MUST fail with a named reason when the leak exceeds the allowance (leak) or when the last
  move is spent without a win (budget).
- **FR-R02G0901-006**: Every action MUST be validated (range, supply, stage, previous fingerprint, budget) and refused
  without change when invalid.
- **FR-R02G0901-007**: Undo and redo MUST restore exact states and fingerprints; replaying a record trace MUST reproduce
  every state.
- **FR-R02G0901-008**: The level's life MUST follow a defined state machine (loading, tutorial, playing, paused, won,
  failed, result).
- **FR-R02G0901-009**: Levels MUST have a versioned stored form with a fingerprint; damaged, edited and newer forms MUST
  be refused.
- **FR-R02G0901-010**: The rules MUST be expressible as a puzzle contract (R02-F23).
- **FR-R02G0901-011**: Invalid requests MUST be refused with stable reason codes `r02-g09.*`; existing modules
  unchanged.
- **FR-R02G0901-012**: The source's invariants this kernel owns (time, input budget, goal, repeatability, undo, failure
  honesty, stability, save, renderer purity) MUST each have a named direct test and a seeded neighbouring-input check.
- **FR-R02G0901-013**: Every bloom, region and measure MUST be identifiable without colour vision: the kernel names them
  in words (bloom number, kind, cell, size, the sun elevation, the match as a fraction and the leak as a cell count), so
  later features can show them as text and shapes.
- **FR-R02G0901-014**: The shadow mask MUST be consistent: it equals the union of the blooms' shadows recomputed from
  scratch after every action, and the boundary deviation between mask and target (a contour distance measure) is
  computed exactly as the truth metric.

### Key Entities

- **Level**: bed size, target cells, forbidden cells, bloom supply, sizes, sun elevations, move budget, required match,
  leak allowance, tutorial flag, fingerprint.
- **Bloom**: kind, anchor cell, size; its exact outline and shadow cells.
- **Shadow mask**: the set of dark cells in the bed.
- **Action**: plant, move, resize, remove, set sun, undo, redo.
- **Play**: stage, planted blooms, sun elevation, moves spent, records, undo and redo stacks.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G0901-001**: For 500 seeded constructed levels the known arrangement wins and every refused action is refused
  with its named reason.
- **SC-R02G0901-002**: For 500 seeded action traces, replay reproduces every fingerprint and the outcome; undo of every
  action restores the exact earlier state.
- **SC-R02G0901-003**: Over 500 seeded levels and action sequences, every shadow mask, match, leak and boundary
  deviation equals an independent computation.
- **SC-R02G0901-004**: Leak and budget each fail on the exact action with the reason named, including the boundary cases
  at the leak allowance and one move either side of the budget.
- **SC-R02G0901-005**: Levels round-trip exactly; damaged, edited and newer forms are refused.
- **SC-R02G0901-006**: Existing tests pass; the reference regression passes 7 of 7; each test under 10 seconds.

## Assumptions

- "Orthographic projected polygon union rasterized into a deterministic low-resolution mask" is read as bloom outlines
  with lattice vertices, stretched by a rational sun factor and sampled at cell centres with exact integer tests.
- "IoU exceeds requirement" is read as "at least the required fraction", decided exactly on cell counts.
- "Boundary deviation" and the "contour Hausdorff proxy" are read as an exact grid distance between the mask's and the
  target's boundary cells, reported as the truth metric; the win uses the match and the leak, as the catalog states.
- Stems, leaves and the mist are drawn later from the kernel's exact blooms; the rules never use floating point.
- Levels and their certification come in R02-G09-02; drawing in R02-G09-03; gestures (drag stems, pinch scale, sun
  slider) in R02-G09-04.
- The game design is the project's own archived design; the code is original.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Deterministic state transition (projected polygon union rasterized into a mask) | FR-R02G0901-002, 003, 004, 006, 007, 008 |
| Exact win/failure evaluation (IoU over requirement, penalty pixels within budget; leak fails) | FR-R02G0901-005 |
| Truth metric: mask IoU and contour Hausdorff proxy | FR-R02G0901-014; SC-R02G0901-003 |
| Puzzle contract for certification | FR-R02G0901-010 |
| Invariants INV-01 … 05 and INV-07 … 10 (INV-06 content belongs to R02-G09-02; INV-11 is superseded by the free tier; INV-12 novelty to R02-G09-02) | FR-R02G0901-012 |
| Accessibility (colour independence) | FR-R02G0901-013 |

## Negative Requirements / Excluded scope

- No rendering, gestures, generator, solver certification, adapter, catalog registration or persistence in this
  feature; no soft shadows in the rules; no device run before ImplementationLock-100.

