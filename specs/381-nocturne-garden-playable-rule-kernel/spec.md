# Feature Specification: R02-G09-01 — Nocturne Garden: playable rule kernel

**Feature Branch**: `381-nocturne-garden-playable-rule-kernel` (spec directory only; work on `main`)

**Created**: 2026-11-22

**Status**: Draft

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
- **Superseded parts of the source prompt:** the price and "no IAP" (free under the shared purchase controller); the Round
  2 lock and per-round device campaign (ImplementationLock-100). The content count 76 (the catalog's "76
  solver-certified stages") is produced in R02-G09-02. **Device-only items:** none (pure logic). **Owner-only items:**
  none.
- **Exactness:** every kernel rule is decided in exact integer arithmetic on a grid (no floating point decides a shadow
  cell, an overlap, a win or a failure), so every device decides the same; the catalog's 0.016667 s timestep is the
  presentation clock of later features and never decides a rule.
- **Shared features used:** R02-F03 (numbers) and R02-F23 (puzzle contract: the kernel's rules are a puzzle contract, so
  R02-G09-02 can certify levels).
- **Model:** feature 371 (Faceted Forge's rule kernel) for structure, stored form, records and refusals.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Cast the target silhouette (Priority: P1) 🎯

A player sees a garden bed, a target silhouette (the dark flower shape to make) and a few forbidden outline regions
around it. The player plants glowing blooms from the level's supply at grid positions and sizes and sets the sun's
elevation, which lengthens or shortens every shadow. The blooms' shadows together form a dark mask; when that mask covers
the target closely enough and keeps out of the forbidden regions, the level is won.

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
  the bed is refused.
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
- **FR-R02G0901-005**: The level MUST be won exactly on the action after which the match (shared cells of mask and target
  divided by cells in either) reaches the required fraction and the leak (mask cells in the forbidden regions) is
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
- **FR-R02G0901-011**: Invalid requests MUST be refused with stable reason codes `r02-g09.*`; existing modules unchanged.
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
- **SC-R02G0901-003**: Over 500 seeded levels and action sequences, every shadow mask, match, leak and boundary deviation
  equals an independent computation.
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
