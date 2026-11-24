# Feature Specification: R02-G15-02 — Voxel Origami: level generator and solver witness

**Feature Branch**: `442-voxel-origami-level-generator-and-solver-witness` (spec directory only; work on
`main`)

**Created**: 2026-11-24

**Status**: Draft

**Ledger gate**: R02-G15-02 (migration ledger, game feature of experience R02-G15) · ID namespace FR-R02G1502-###,
SC-R02G1502-###, T-R02G1502-###

**Input**: User description: the archived R02-G15-02 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Generate solvable seeded levels with certificates and difficulty metrics" for Voxel Origami, with the
canonical overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/442-voxel-origami-level-generator-and-solver-witness`;
  FR-R02G1502-###, SC-R02G1502-###, T-R02G1502-###.
- **Packaging (ADR-0009):** experience R02-G15 (`r02-g14.voxel-origami`, free) in the one app; this feature
  extends the pure `VoxelOrigamiCore` of feature 441.
- **Superseded parts of the source prompt:** price and "no IAP"; the Round 2 lock and per-round device campaign.
  **Device-only items:** none (pure logic). **Owner-only items:** none.
- **Content count:** the canonical catalog is the 100-level manifest of the archived design (`python3
  scripts/planning_index.py levels --experience R02-G15`: 20 levels in each of bands 1 … 5, each with its planned seed
  and moves budget 8 … 19). The prompt's "content count 88" (the catalog's "88 solver-certified stages") is a milestone
  figure, as for the earlier round-two games.
- **Model:** feature 432 (Voxel Origami's content pipeline) for manifest, generator, witness files, digest and
  progression.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Every shipped level can be solved (Priority: P1) 🎯

A player opening any of the 100 levels can always win: some hinge turns within the moves budget fold the cubes into the
target solid without any collision. The game has proof of it for
every level, and proof that no fewer actions would do.

**Why this priority**: an unsolvable level breaks the game.

**Independent Test**: each level's stored witness actions, replayed from the start, win within the budget; every
action's resulting state equals the stored digest; the proof that fewer actions cannot win is re-checked.

**Acceptance Scenarios**:

1. **Given** any catalog level, **When** its witness is replayed, **Then** the level is won within the budget.
2. **Given** any catalog level, **When** any sequence of fewer turns than the witness is tried, **Then** none matches the
   target.
3. **Given** a catalog level, **When** the solver runs again, **Then** it finds the same witness.

### User Story 2 - Levels come from their planned seeds (Priority: P1)

Each level is built from its manifest seed, band and budget the same way on every build; a changed rule or seed changes
the pinned fingerprints and fails the checks.

**Independent Test**: building the catalog twice gives identical levels; the catalog digest equals the pinned value.

### User Story 3 - Difficulty that means something (Priority: P2)

Each level carries difficulty metrics from the solver's actual result: the turns the witness needs, the cubes and
hinges, the allowed orientations, the states searched and the solver's work. Harder bands mean longer chains and more
folds in the right order, never faster reactions.

**Independent Test**: band by band, the mean witness turn count does not fall; the catalog keeps the progression rule.

### User Story 4 - Honest witness files (Priority: P2)

For each level a witness file records the level, the winning actions, a digest of the state after every action and the
counterexample proof that fewer actions cannot win. Any edited or fake witness is caught.

**Independent Test**: all 100 witness files match what the generator and solver produce now, byte for byte; an edited
file is refused.

### Edge Cases

- **A seed whose candidate is unsuitable for its band:** the generator moves to the next candidate deterministically
  (bounded) and records how many it skipped; no candidate within the bound is a named refusal.
- **A candidate already matching at its start, or needing no turn:** never emitted.
- **More than one minimal plan:** allowed; the witness is the one the solver finds in its fixed order.
- **A plan needing more actions than the budget:** not emitted.
- **A search over its work bound:** the candidate is skipped (counted work, never timed).
- **Damaged, newer or edited witness files:** refused with a named reason.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G1502-001**: A generator MUST build each catalog level deterministically from its manifest number, seed, band
  and budget; only levels the solver certifies within the budget MAY be emitted.
- **FR-R02G1502-002**: A solver MUST find a minimal sequence of hinge turns after which the cubes match the target, with
  its work bounded and counted, and MUST prove that no shorter sequence matches; every plan it reports MUST be replayed
  through the kernel.
- **FR-R02G1502-003**: Each level MUST carry difficulty metrics (witness turns, cubes, hinges, allowed orientations,
  states searched, solver work) derived from the level and the solver.
- **FR-R02G1502-004**: Each level MUST have a versioned witness record (level, actions, per-action state digests,
  counterexample proof); damaged, newer and edited files MUST be refused.
- **FR-R02G1502-005**: The catalog of 100 levels MUST have a digest pinned in tests and MUST satisfy the shared
  progression rule; band means of the witness turn count never fall.
- **FR-R02G1502-006**: Invalid requests MUST be refused with stable reason codes; existing code MUST change only
  additively; every new public name is documented; the reference regression passes.

### Key Entities

- **Manifest entry**: number, planned seed, band, moves budget.
- **Minimality proof**: every pose reachable in fewer turns, none of which matches the target.
- **Solver result**: the turns, the work counted, the proof.
- **Difficulty**: witness turns, cubes, hinges, orientations, states searched, work.
- **Witness**: schema, the level's stored form, actions, per-action state digests, counterexample, skipped candidates.
- **Catalog**: the 100 levels in manifest order with a digest.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G1502-001**: All 100 catalog levels are won by replaying their witness within the budget.
- **SC-R02G1502-002**: The minimality proof equals an independent brute-force check on sampled catalog levels (at least
  two per band).
- **SC-R02G1502-003**: Building the catalog twice gives identical levels and the pinned digest; each witness file
  matches the regenerated witness byte for byte.
- **SC-R02G1502-004**: The mean witness turn count does not fall from one band to the next; the catalog keeps its
  progression rule.
- **SC-R02G1502-005**: For every level, no sequence of fewer actions than its witness wins; edited, newer and damaged
  witness files are refused.
- **SC-R02G1502-006**: Existing tests pass unchanged; the reference regression passes 7 of 7; each unit test finishes in
  under 10 seconds on a debug host build, the catalog certification split as needed.

## Assumptions

- The 100 witness files live in `docs/games/voxel-origami/levels/NNN.witness.json` (the manifest's "Required
  artifact"); they are regenerated only by a test run with an explicit opt-in and checked byte for byte on every other
  run.
- "A-star over hinge-angle lattice states with swept AABB collision filter" is read as: the solver searches the hinge
  quarter-turn states reachable by ever more clear turns (each turn filtered by the kernel's collision and exact sweep
  rule), level by level, so the first match found is minimal; a search with a zero heuristic is A-star's exact case.
- Levels are presented, hinted and played through later features (R02-G15-03 … 07); this feature draws nothing.
- The manifest's numbers, seeds, bands and budgets are copied from the project's own archived design; no third-party
  content is used.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Solvable seeded levels | FR-R02G1502-001, 002 |
| Solver: A-star over hinge-angle lattice states with swept AABB collision filter | FR-R02G1502-002 |
| Truth metric: collision-free occupancy and canonical polycube hash | FR-R02G1502-002, 003 |
| Certificates (witness, counterexample, per-action digests) | FR-R02G1502-004 |
| Difficulty metrics | FR-R02G1502-003, 005 |
| Invariants INV-06 content and INV-12 novelty | FR-R02G1502-002, 003 |
| Schema migration, error handling | FR-R02G1502-004, 006 |
| Deterministic tests | SC-R02G1502-002, 003 |
| No Stage One breakage | FR-R02G1502-006 |
