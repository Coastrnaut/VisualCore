# Feature Specification: R02-G15-01 — Voxel Origami: playable rule kernel

**Feature Branch**: `441-voxel-origami-playable-rule-kernel` (spec directory only; work on `main`)

**Created**: 2026-11-24

**Status**: Draft

**Ledger gate**: R02-G15-01 (migration ledger, game feature of experience R02-G15) · ID namespace FR-R02G1501-###,
SC-R02G1501-###, T-R02G1501-###

**Input**: User description: the archived R02-G15-01 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Implement deterministic state transition and exact win/failure evaluation" for Voxel Origami, with the canonical
overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/441-voxel-origami-playable-rule-kernel`; FR-R02G1501-###, SC-R02G1501-###,
  T-R02G1501-###.
- **Packaging (ADR-0009):** Voxel Origami is experience R02-G15 (`r02-g15.voxel-origami`, free) inside the single
  VisualCore app. The source's `Apps/VoxelOrigami` and `Packages/GameModules/VoxelOrigamiCore` become the experience
  module `Packages/ExperiencesRound02/VoxelOrigami`; this feature adds its pure Core with tests. Catalog registration,
  adapter and renderer come in later features of R02-G15 and its gate X-R02-G15.
- **Superseded parts of the source prompt:** the price and "no IAP" (free under the shared purchase controller); the
  Round 2 lock and per-round device campaign (ImplementationLock-100). The content count 88 (the catalog's "88
  solver-certified stages") is a milestone inside the levels of R02-G15-02. **Device-only items:** none (pure logic).
  **Owner-only items:** none.
- **Exactness:** every kernel rule is decided in exact integer arithmetic on the cube lattice, so every device decides
  the same; the catalog's 0.008333 s timestep is the presentation clock of later features and never decides a rule.
- **Shared features used:** R02-F03 (numbers) and R02-F23 (puzzle contract: the kernel's rules are a puzzle contract,
  so R02-G15-02 can certify levels).
- **Model:** feature 431 (Moonlit Mechanism's rule kernel) for structure, stored form, records and refusals.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Fold a chain of hinged cubes into the target solid (Priority: P1) 🎯

A player sees a chain of luminous cubes joined by hinges and, beside it, the outline of a target solid. Each hinge turns
in quarter turns; turning one swings every cube beyond it to a new place on the cube lattice. When the cubes occupy
exactly the cells of the target solid (in any of the orientations the level allows, anywhere in space), the level is
won.

**Why this priority**: this is the whole game.

**Independent Test**: from a constructed level, a known sequence of hinge turns wins on its last turn; after every
action the position of every cube, the occupied cells and the closeness to the target equal an independent computation.

**Acceptance Scenarios**:

1. **Given** a level and its known actions, **When** they are applied, **Then** the level is won exactly on the last
   one.
2. **Given** any action sequence, **When** it is applied twice, **Then** every state and the outcome are the same.

### User Story 2 - A fold collides or the moves run out (Priority: P1)

A hinge turn fails the level when the swinging cubes would end in a cell another cube occupies, or pass through one on
the way; using up the action budget without a match fails the level too. Each failure names its reason, the hinge, and
the cubes and cell where it applies; the player can undo the failing turn and try again.

**Independent Test**: scripted sequences end failed with the named reason on the exact action.

### User Story 3 - Undo, redo and replay (Priority: P1)

The player undoes and redoes every action exactly; a recorded trace replays to the same states everywhere.

**Independent Test**: 500 seeded traces replay identically; undo restores exact fingerprints.

### User Story 4 - The life of a level and its stored form (Priority: P2)

A level loads, may show a tutorial, plays, pauses and ends; levels have a versioned stored form that refuses damage.

**Independent Test**: the state machine refuses actions in the wrong stage; levels round-trip and damaged forms are
refused.

### Edge Cases

- **An unknown hinge, a turn other than one quarter turn either way:** refused without cost.
- **A turn whose swinging cubes end exactly beside, but not inside, another cube's cell:** allowed.
- **A turn that would make two cubes share a cell, or sweep a cube through an occupied cell:** fails the level, naming
  the moving cube, the cube in the way and the cell; undo returns to playing.
- **A target matched only after a rotation the level does not allow:** not a win.
- **The last action of the budget:** a turn on it can still win; any other last action without a win fails the level.
- **A level already solved at load:** never accepted; every level needs at least one action to win.
- **Actions after the end:** every action is refused once the level is won or failed, except undo from failed.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G1501-001**: A level MUST define its cubes and their tree of hinges (every cube but the first attached to one
  earlier cube, face to face), the rest pose, the starting quarter turn of every hinge, the target solid, the
  orientations the match allows, the action budget and whether it shows a tutorial.
- **FR-R02G1501-002**: Turning a hinge by one quarter turn MUST swing exactly the cubes beyond it, every one landing on
  a lattice cell, computed exactly.
- **FR-R02G1501-003**: A hinge turn MUST fail the level when it would leave two cubes in one cell or when a swinging cube
  would pass through a cell occupied by a cube that does not swing, naming the reason, the hinge, the cubes and the cell.
- **FR-R02G1501-004**: Every hinge turn MUST spend one action; the level MUST be won exactly when, after an accepted
  turn, the occupied cells equal the target solid up to a translation and one of the level's allowed orientations.
- **FR-R02G1501-005**: Using up the budget without a win MUST fail the level with a named reason.
- **FR-R02G1501-006**: Every action MUST be validated (hinge, step, stage, previous fingerprint) and refused without
  change when invalid.
- **FR-R02G1501-007**: Undo and redo MUST restore exact states and fingerprints; replaying a record trace MUST reproduce
  every state.
- **FR-R02G1501-008**: The level's life MUST follow a defined state machine (loading, tutorial, playing, paused, won,
  failed, result).
- **FR-R02G1501-009**: Levels MUST have a versioned stored form with a fingerprint; damaged, edited and newer forms MUST
  be refused.
- **FR-R02G1501-010**: The rules MUST be expressible as a puzzle contract (R02-F23).
- **FR-R02G1501-011**: Invalid requests MUST be refused with stable reason codes `r02-g15.*`; existing modules
  unchanged.
- **FR-R02G1501-012**: The source's invariants this kernel owns (time, input budget, goal, repeatability, undo, failure
  honesty, stability, save, renderer purity) MUST each have a named direct test and a seeded neighbouring-input check.
- **FR-R02G1501-013**: Every cube, hinge and measure MUST be identifiable without colour vision: the kernel names them
  in words (cube and hinge numbers, each hinge's quarter turn, the cubes in place, actions left).
- **FR-R02G1501-014**: The truth metric MUST be computed exactly and reported after every action: collision-free
  occupancy (no cell held twice) and the canonical shape hash of the occupied cells, with how many cubes the best
  allowed alignment of the target covers.

### Key Entities

- **Level**: cubes, hinge tree, rest pose, starting turns, target solid, allowed orientations, budget, tutorial flag,
  fingerprint.
- **Hinge**: the parent cube, the child cube, the face direction between them, the quarter turn.
- **Pose**: every cube's lattice cell; the occupied cell set.
- **Shape report**: occupancy, canonical hash, best alignment and covered count, the outcome.
- **Action**: turn, undo, redo.
- **Play**: stage, quarter turns, actions spent, records, undo and redo stacks, failure.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G1501-001**: For 500 seeded constructed levels the known actions win and every refused action is refused with
  its named reason.
- **SC-R02G1501-002**: For 500 seeded action traces, replay reproduces every fingerprint and the outcome; undo of every
  action restores the exact earlier state.
- **SC-R02G1501-003**: Over 500 seeded levels and action sequences, every cube cell, collision decision, canonical hash,
  covered count and outcome equals an independent computation.
- **SC-R02G1501-004**: Failure happens on the exact action with the reason named, including one action either side of
  the budget, a cube one cell clear of and inside another's cell, and a sweep that just clears and just touches a cube.
- **SC-R02G1501-005**: Levels round-trip exactly; damaged, edited and newer forms are refused.
- **SC-R02G1501-006**: Existing tests pass; the reference regression passes 7 of 7; each test under 10 seconds.

## Assumptions

- "Tap hinge, drag arc to discrete angle" is choosing a hinge and turning it by quarter turns; "rotate view with two
  fingers" is presentation only; "undo" is the kernel's undo.
- "Self-collision or disconnected hierarchy on a move" is read as a turn that would put two cubes in one cell or sweep
  a cube through an occupied cell; how the hierarchy can or cannot come apart is settled in clarification.
- "Occupied voxel set matches target up to allowed global rotation" is exact equality of cell sets after a translation
  and one of the level's allowed orientations.
- "Collision-free occupancy and canonical polycube hash" is the exact truth metric of FR-R02G1501-014.
- Levels and their certification (A-star over hinge-angle lattice states with a swept collision filter) come in
  R02-G15-02; drawing in R02-G15-03; gestures in R02-G15-04.
- The game design is the project's own archived design; the code is original.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Deterministic state transition (hinge turns, budget) | FR-R02G1501-002, 004, 006, 007, 008 |
| Exact win/failure evaluation (target match, collisions) | FR-R02G1501-003, 004, 005 |
| Truth metric: collision-free occupancy and canonical polycube hash | FR-R02G1501-014; SC-R02G1501-003 |
| Puzzle contract for certification | FR-R02G1501-010 |
| Invariants INV-01 … 05 and INV-07 … 10 (INV-06 content and INV-12 novelty belong to R02-G15-02; INV-11 is superseded by the free tier) | FR-R02G1501-012 |
| Accessibility (colour independence) | FR-R02G1501-013 |

## Negative Requirements / Excluded scope

- No rendering, gestures, generator, solver certification, adapter, catalog registration or persistence in this
  feature; no floating point in the rules; no device run before ImplementationLock-100.
