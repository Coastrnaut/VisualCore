# Feature Specification: R02-G15-02 — Voxel Origami: level generator and solver witness

**Feature Branch**: `442-voxel-origami-level-generator-and-solver-witness` (spec directory only; work on
`main`)

**Created**: 2026-11-24

**Status**: Clarified

**Ledger gate**: R02-G15-02 (migration ledger, game feature of experience R02-G15) · ID namespace FR-R02G1502-###,
SC-R02G1502-###, T-R02G1502-###

**Input**: User description: the archived R02-G15-02 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Generate solvable seeded levels with certificates and difficulty metrics" for Voxel Origami, with the
canonical overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/442-voxel-origami-level-generator-and-solver-witness`;
  FR-R02G1502-###, SC-R02G1502-###, T-R02G1502-###.
- **Packaging (ADR-0009):** experience R02-G15 (`r02-g15.voxel-origami`, free) in the one app; this feature
  extends the pure `VoxelOrigamiCore` of feature 441.
- **Superseded parts of the source prompt:** price and "no IAP"; the Round 2 lock and per-round device campaign.
  **Device-only items:** none (pure logic). **Owner-only items:** none.
- **Content count:** the canonical catalog is the 100-level manifest of the archived design (`python3
  scripts/planning_index.py levels --experience R02-G15`: 20 levels in each of bands 1 … 5, each with its planned seed
  and moves budget 8 … 19). The prompt's "content count 88" (the catalog's "88 solver-certified stages") is a milestone
  figure, as for the earlier round-two games.
- **Model:** feature 432 (Moonlit Mechanism's content pipeline) for manifest, generator, witness files, digest and
  progression.

## Clarifications

### Session 2026-11-24

Answered autonomously under the owner's standing delegation, safest well-supported option each time, following feature
432's answers where the games agree. Facts checked (read-only, 2026-11-24): R02-G15-01's `VoxelOrigamiLevel` (4 … 12
cubes, quarter turns 0 … 3, orientations `fixed`, `upright`, `any`, budget 1 … 40, a start that does not match),
`VoxelOrigamiLattice` (poses, idle hinges, collision and exact sweep, canonical form), `VoxelOrigamiPlay` and
`VoxelOrigamiRules`; R02-F24's `PuzzleCatalog.digest(id:identities:)` and the standard `ProgressionRule` (drop at most
1, jump at most 3); `SeedDerivation.derive(_:index:)` and `SeededRandom`; the canonical manifest's 100 entries
(`planning_index.py levels --experience R02-G15`: bands 1 … 5 × 20, moves budgets 8 … 11, 10 … 13, 12 … 15, 14 … 17,
16 … 19 by band, control emphases `inspect collision`, `lock shape`, `fold hinge`, `select voxel`, `rotate assembly`, 20
each). The ranges below were measured before they were written down: a prototype of this generator and a breadth-first
solver on the real kernel (release build, 120 candidates per band) gave a minimal plan inside the band's range for 63,
44, 30, 18 and 9 candidates (bands 1 … 5) under `any`, 73, 54, 42, 21, 10 under `fixed` and 68, 53, 35, 21, 9 under
`upright`, with at most 3 670 turns tried per candidate and under 0.2 s per band of 120 candidates.

- Q: How is a level built from its manifest entry? → A: the 100 entries (number, planned seed, band, budget, control
  emphasis) are a table in `VoxelOrigamiManifest` with their provenance. Candidate c of entry n draws from
  `SeededRandom(seed: SeedDerivation.derive(plannedSeed, index: c))`, in this order: the cube count by band (5 … 6,
  6 … 7, 7 … 8, 8 … 9, 9 … 10); the tree (each non-root cube's parent a drawn lower index and its rest direction one of
  the six units, the whole tree redrawn up to 50 times until the rest pose is collision-free, else the candidate is
  skipped); the solution's quarter turns (one per hinge, 0 … 3; a colliding solution pose skips the candidate); the
  orientations by emphasis (`rotate assembly` → `any`, `lock shape` → `fixed`, the others → `upright`); the target (the
  solution's cells under a drawn rotation of that group and a drawn shift of −3 … 3 per axis, sorted); then a scramble
  of the solution by band (2 … 4, 4 … 6, 6 … 9, 8 … 12, 10 … 14 clear random turns, each a drawn hinge and step that the
  kernel accepts, at most eight draws per wanted turn) gives the start. Budget = the manifest's; ids `voxel-origami-NNN`;
  tutorial on levels 1 … 3; difficulty = band. A candidate whose start already matches, or that the solver does not
  certify with a minimal plan in its band's range (1 … 2, 2 … 3, 3 … 4, 4 … 5, 5 … 6 turns) within its work bound, is
  skipped; at most 256 candidates, then `generation(n)`. Impact: FR-R02G1502-001; SC-R02G1502-001, 003, 004.
- Q: How does the solver find a minimal plan, and what proves nothing shorter matches? → A: a breadth-first search over
  quarter-turn states from the start (the exact case of the catalog's A-star, with a zero heuristic): at each depth the
  states are expanded in the order they were reached, each state's moves in the order hinges ascending, step −1 then
  +1; a move is tried only on a hinge that would swing a cube, and only a turn the kernel's collision and exact sweep
  rule clear (the swept collision filter) reaches a state; states are merged by their quarter turns. The first reached
  state whose pose matches the target ends the search; the plan is its path. Work = turns tried, counted and bounded at
  300 000; over the bound the candidate is skipped. The minimality proof is that every state reachable in fewer turns
  was reached and none matched (the counts of states at each smaller depth are stored). The witness is the plan's
  turns, replayed through the kernel's play. Impact: FR-R02G1502-002; SC-R02G1502-001, 002, 005.
- Q: What difficulty metrics are stored and what progression is required? → A: `VoxelOrigamiDifficulty` holds the
  witness turn count, the cubes, the hinges that can turn at the start, the orientations, the states searched at smaller
  depths and the solver work. The catalog in manifest order keeps R02-F24's standard `ProgressionRule` (drop at most 1,
  jump at most 3) on the witness turn count; the band ranges, each two values wide and meeting the next band's at one
  value, make band means non-decreasing. Impact: FR-R02G1502-003, 005; SC-R02G1502-004.
- Q: What is in a witness file and how is it checked? → A: `docs/games/voxel-origami/levels/NNN.witness.json`, JSON
  schema 1 with sorted keys: number, the level's stored form, the actions, the state digest after every action (16 hex
  characters of the SHA-256 of the quarter turns), the play fingerprints after `begin` (and `dismissTutorial` when the
  level has one) and after each action, the counterexample (the depth one below the plan and the number of states
  reached at that depth, none matching), the difficulty and the candidates skipped. A test rebuilds every witness and
  compares bytes; it writes the files only with `VOXEL_ORIGAMI_WRITE_WITNESSES=1`. Decoding refuses newer schemas,
  damaged files and witnesses that no longer replay. Impact: FR-R02G1502-004; SC-R02G1502-003, 005.
- Q: How is the catalog identified, how long may certification take and how are refusals named? → A: the digest is
  `PuzzleCatalog<VoxelOrigamiRules>.digest(id: "voxel-origami", identities:)` over the 100 level fingerprints in
  manifest order, pinned in a test. Certification tests are split into groups of 20 levels so each runs under 10
  seconds on a debug host build (measured locally, not asserted on CI); generated levels are cached per process. New
  refusals: `generation(Int)` (`r02-g15.generation`) and `witness(String)` (`r02-g15.witness`). The independent check of
  SC-R02G1502-002 is a depth-first enumeration of every turn sequence the play accepts (no state merging), shorter than
  the plan, on the two levels with the fewest cubes in each band: none reaches a matching pose. Impact:
  FR-R02G1502-005, 006; SC-R02G1502-002, 006.

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
