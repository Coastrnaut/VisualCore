# Feature Specification: R02-G14-02 — Moonlit Mechanism: level generator and solver witness

**Feature Branch**: `432-moonlit-mechanism-level-generator-and-solver-witness` (spec directory only; work on
`main`)

**Created**: 2026-11-24

**Status**: Clarified

**Ledger gate**: R02-G14-02 (migration ledger, game feature of experience R02-G14) · ID namespace FR-R02G1402-###,
SC-R02G1402-###, T-R02G1402-###

**Input**: User description: the archived R02-G14-02 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Generate solvable seeded levels with certificates and difficulty metrics" for Moonlit Mechanism, with the
canonical overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/432-moonlit-mechanism-level-generator-and-solver-witness`;
  FR-R02G1402-###, SC-R02G1402-###, T-R02G1402-###.
- **Packaging (ADR-0009):** experience R02-G14 (`r02-g14.moonlit-mechanism`, free) in the one app; this feature
  extends the pure `MoonlitMechanismCore` of feature 431.
- **Superseded parts of the source prompt:** price and "no IAP"; the Round 2 lock and per-round device campaign.
  **Device-only items:** none (pure logic). **Owner-only items:** none.
- **Content count:** the canonical catalog is the 100-level manifest of the archived design (`python3
  scripts/planning_index.py levels --experience R02-G14`: 20 levels in each of bands 1 … 5, each with its planned seed
  and moves budget 8 … 19). The prompt's "content count 77" (the catalog's "77 solver-certified stages") is a milestone
  figure, as for the earlier round-two games.
- **Model:** feature 422 (Acoustic Constellator's content pipeline) for manifest, generator, witness files, digest and
  progression.

## Clarifications

### Session 2026-11-24

Answered autonomously under the owner's standing delegation, safest well-supported option each time, following feature
422's answers where the games agree. Facts checked (read-only, 2026-11-24): R02-G14-01's `MoonlitMechanismLevel` (2 … 5
gears of 6 … 20 teeth, mesh divisors ≥ 2, depth 1 … 3, slot offsets within ±8, wall 8 … 24 × 6 … 16, lamp heights
2 … 5, 2 … 6 key frames, 0 … 12 forbidden cells, allowance 0 … 4, budget 1 … 40), `MoonlitMechanismTrain`,
`MoonlitMechanismPlay` and `MoonlitMechanismRules`; R02-F24's `PuzzleCatalog.digest(id:identities:)` and the standard
`ProgressionRule` (drop at most 1, jump at most 3); `SeedDerivation.derive(_:index:)` and `SeededRandom`; the canonical
manifest's 100 entries (`planning_index.py levels --experience R02-G14`: bands 1 … 5 × 20, moves budgets 8 … 19). Every
action adds to one vector — the net handle turns t, the net lamp steps h and the net re-seat rᵢ of each gear — so
actions commute, and a lamp path that moves one way never leaves its range: a plan is a vector and its length is the
vector's L1 norm. The mesh alignments depend only on the re-seats (a turn moves meshing gears by +t and −t). The ranges
below were measured before they were written down: a prototype of this generator and solver on the real kernel over 60
candidates per band gave minimal plans in the band's range for 42, 35, 37, 14 and 23 of 60 (bands 1 … 5), with at most
760 runs of work and well under a second per band in a release build.

- Q: How is a level built from its manifest entry? → A: the 100 entries (number, planned seed, band, budget) are a table
  in `MoonlitMechanismManifest` with their provenance. Candidate c of entry n draws from `SeededRandom(seed:
  SeedDerivation.derive(plannedSeed, index: c))`, in this order: the wall (W 12 … 16, H 9 … 12); the gear count by band
  (2 … 3, 3, 3 … 4, 4, 4 … 5); the lamp heights by band (2 … 3, 3, 3 … 4, 4, 4 … 5); for each gear a parent (a drawn
  lower index) and a tooth count from (6, 8, 9, 10, 12, 14, 15, 16, 18, 20), redrawn until its divisor with the parent is
  at least 2; a solution set-up (phases and a lamp height); for each gear a blade pattern (each bit solid with chance 1
  in 3, bit 0 solid, the last bit open), a depth 1 … 3, a centre (column 3 … W − 4, row 2 … H − 5) and a slot table
  (slot k points the compass direction ⌊8k / T⌋ with a ray of 2 … 3 cells starting one cell out); the alignment values
  are the solution's sums; the key-frame count by band (2, 2 … 3, 3, 3 … 4, 4 … 5) with first turns 0 … 2 and gaps
  1 … 4, each target the solution's cast at that key frame (a candidate with an empty cast is skipped), key frame 0
  required and each later one required with chance 3 in 4; 2 … 6 forbidden cells drawn from the cells no solution key
  frame covers; allowance 0; then a scramble of the solution by band (2 … 3, 3 … 4, 4 … 6, 5 … 7, 7 … 9 random turns,
  re-seats and lamp steps the play accepts) gives the start. Budget = the manifest's; ids `moonlit-mechanism-NNN`;
  tutorial on levels 1 … 3; difficulty = band. A candidate whose start already wins, or that the solver does not
  certify with a minimal plan in its band's range (1 … 2, 2 … 3, 3 … 4, 4 … 5, 5 … 6 actions before the run) within its
  work bound, is skipped; at most 256 candidates, then `generation(n)`. Impact: FR-R02G1402-001; SC-R02G1402-001, 003,
  004.
- Q: How does the solver find a minimal plan, and what proves nothing shorter wins? → A: the solver tries plan vectors
  (t, h, r₁ … rₙ₋₁) by L1 norm c = 0, 1, 2, …, at each norm in a fixed order (each coordinate from −left to +left in the
  order t, h, r₁, …; the last coordinate +left before −left): a vector whose lamp height leaves the range is skipped, a
  vector that leaves a mesh misaligned is skipped without a run (the gear-ratio constraint), and every other vector is
  judged by the kernel's run of the set-up it reaches (the silhouette union against the targets). The first winning
  vector is the plan. Work = runs, counted and bounded at 400,000; over the bound the candidate is skipped. The
  minimality proof is that every vector of every smaller norm was tried and lost (their count is stored). The witness
  is |t| turns of t's sign, then each gear's |rᵢ| re-seats of rᵢ's sign in gear order, then |h| lamp steps of h's sign,
  then the run, replayed through the kernel's play. Impact: FR-R02G1402-002; SC-R02G1402-001, 002, 005.
- Q: What difficulty metrics are stored and what progression is required? → A: `MoonlitMechanismDifficulty` holds the
  witness action count (before the run), the gears, the meshes, the total teeth, the key frames and the required ones,
  the target cells (all key frames), the forbidden cells, the lamp heights, the vectors tried at smaller norms and the
  solver work. The catalog in manifest order keeps R02-F24's standard `ProgressionRule` (drop at most 1, jump at most 3)
  on the witness action count; the band ranges, each two values wide and meeting the next band's at one value, make
  band means non-decreasing. Impact: FR-R02G1402-003, 005; SC-R02G1402-004.
- Q: What is in a witness file and how is it checked? → A: `docs/games/moonlit-mechanism/levels/NNN.witness.json`, JSON
  schema 1 with sorted keys: number, the level's stored form, the actions, the state digest after every action (16 hex
  characters of the SHA-256 of the phases and the lamp height), the play fingerprints after `begin` (and
  `dismissTutorial` when the level has one) and after each action, the counterexample (the norm one below the plan and
  the number of vectors of that norm tried, none winning), the difficulty and the candidates skipped. A test rebuilds
  every witness and compares bytes; it writes the files only with `MOONLIT_MECHANISM_WRITE_WITNESSES=1`. Decoding
  refuses newer schemas, damaged files and witnesses that no longer replay. Impact: FR-R02G1402-004; SC-R02G1402-003,
  005.
- Q: How is the catalog identified, how long may certification take and how are refusals named? → A: the digest is
  `PuzzleCatalog<MoonlitMechanismRules>.digest(id: "moonlit-mechanism", identities:)` over the 100 level fingerprints in
  manifest order, pinned in a test. Certification tests are split into groups of 20 levels so each runs under 10 seconds
  on a debug host build (measured locally, not asserted on CI); generated levels are cached per process. New refusals:
  `generation(Int)` (`r02-g14.generation`) and `witness(String)` (`r02-g14.witness`). The independent check of
  SC-R02G1402-002 is a breadth-first search over every action sequence the play accepts (turns, re-seats and lamp steps,
  states merged by phases and lamp height), shorter than the plan, on the two levels with the fewest gears in each band:
  no reached set-up wins. Impact: FR-R02G1402-005, 006; SC-R02G1402-002, 006.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Every shipped level can be solved (Priority: P1) 🎯

A player opening any of the 100 levels can always win: some handle turns, gear re-seats and lamp steps within the
moves budget align every mesh and make the shadows match every required key frame without touching a forbidden cell,
and a run then wins. The game has proof of it for
every level, and proof that no fewer actions would do.

**Why this priority**: an unsolvable level breaks the game.

**Independent Test**: each level's stored witness actions, replayed from the start, win within the budget; every
action's resulting state equals the stored digest; the proof that fewer actions cannot win is re-checked.

**Acceptance Scenarios**:

1. **Given** any catalog level, **When** its witness is replayed, **Then** the level is won within the budget.
2. **Given** any catalog level, **When** any sequence of fewer actions than the witness is tried, **Then** no run wins.
3. **Given** a catalog level, **When** the solver runs again, **Then** it finds the same witness.

### User Story 2 - Levels come from their planned seeds (Priority: P1)

Each level is built from its manifest seed, band and budget the same way on every build; a changed rule or seed changes
the pinned fingerprints and fails the checks.

**Independent Test**: building the catalog twice gives identical levels; the catalog digest equals the pinned value.

### User Story 3 - Difficulty that means something (Priority: P2)

Each level carries difficulty metrics from the solver's actual result: the actions the witness needs, the gears and
meshes, the teeth, the key frames and required ones, the target and forbidden cells, the lamp heights, the allowance
and the solver's work. Harder bands mean larger trains, more key frames and finer timing of re-seats and lamp steps,
never faster reactions.

**Independent Test**: band by band, the mean witness action count does not fall; the catalog keeps the progression rule.

### User Story 4 - Honest witness files (Priority: P2)

For each level a witness file records the level, the winning actions, a digest of the state after every action and the
counterexample proof that fewer actions cannot win. Any edited or fake witness is caught.

**Independent Test**: all 100 witness files match what the generator and solver produce now, byte for byte; an edited
file is refused.

### Edge Cases

- **A seed whose candidate is unsuitable for its band:** the generator moves to the next candidate deterministically
  (bounded) and records how many it skipped; no candidate within the bound is a named refusal.
- **A candidate already won at its start, or needing no action:** never emitted.
- **More than one minimal plan:** allowed; the witness is the one the solver finds in its fixed order.
- **A plan needing more actions than the budget:** not emitted.
- **A search over its work bound:** the candidate is skipped (counted work, never timed).
- **Damaged, newer or edited witness files:** refused with a named reason.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G1402-001**: A generator MUST build each catalog level deterministically from its manifest number, seed, band
  and budget; only levels the solver certifies within the budget MAY be emitted.
- **FR-R02G1402-002**: A solver MUST find a minimal sequence of actions (turns, re-seats, lamp steps) after which a run
  wins, with its work bounded and counted, and MUST prove that no shorter sequence wins; every plan it reports MUST be replayed through
  the kernel.
- **FR-R02G1402-003**: Each level MUST carry difficulty metrics (witness actions, gears, meshes, teeth, key frames,
  required key frames, target and forbidden cells, lamp heights, allowance, solver work) derived from the level and the solver.
- **FR-R02G1402-004**: Each level MUST have a versioned witness record (level, actions, per-action state digests,
  counterexample proof); damaged, newer and edited files MUST be refused.
- **FR-R02G1402-005**: The catalog of 100 levels MUST have a digest pinned in tests and MUST satisfy the shared
  progression rule; band means of the witness action count never fall.
- **FR-R02G1402-006**: Invalid requests MUST be refused with stable reason codes; existing code MUST change only
  additively; every new public name is documented; the reference regression passes.

### Key Entities

- **Manifest entry**: number, planned seed, band, moves budget.
- **Minimality proof**: every set-up reachable in fewer actions, none of which a run wins.
- **Solver result**: the actions, the run, the work counted, the proof.
- **Difficulty**: witness actions, gears, meshes, teeth, key frames, cells, lamp heights, allowance, work.
- **Witness**: schema, the level's stored form, actions, per-action state digests, counterexample, skipped candidates.
- **Catalog**: the 100 levels in manifest order with a digest.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G1402-001**: All 100 catalog levels are won by replaying their witness within the budget.
- **SC-R02G1402-002**: The minimality proof equals an independent brute-force check on sampled catalog levels (at least
  two per band).
- **SC-R02G1402-003**: Building the catalog twice gives identical levels and the pinned digest; each witness file
  matches the regenerated witness byte for byte.
- **SC-R02G1402-004**: The mean witness action count does not fall from one band to the next; the catalog keeps its
  progression rule.
- **SC-R02G1402-005**: For every level, no sequence of fewer actions than its witness wins; edited, newer and damaged
  witness files are refused.
- **SC-R02G1402-006**: Existing tests pass unchanged; the reference regression passes 7 of 7; each unit test finishes in
  under 10 seconds on a debug host build, the catalog certification split as needed.

## Assumptions

- The 100 witness files live in `docs/games/moonlit-mechanism/levels/NNN.witness.json` (the manifest's "Required
  artifact"); they are regenerated only by a test run with an explicit opt-in and checked byte for byte on every other
  run.
- "Discretized phase search with gear ratio constraints and silhouette union metric" is read as: the solver searches
  the whole-tooth phases and lamp heights reachable by ever more actions, pruning set-ups whose meshes cannot be
  aligned within the remaining actions (the gear-ratio constraint), and judges each candidate with the kernel's run,
  whose shadow union against the targets is the silhouette metric.
- Levels are presented, hinted and played through later features (R02-G14-03 … 07); this feature draws nothing.
- The manifest's numbers, seeds, bands and budgets are copied from the project's own archived design; no third-party
  content is used.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Solvable seeded levels | FR-R02G1402-001, 002 |
| Solver: discretized phase search with gear ratio constraints and silhouette union metric | FR-R02G1402-002 |
| Truth metric: angular relation error and target-mask overlap per frame | FR-R02G1402-002, 003 |
| Certificates (witness, counterexample, per-action digests) | FR-R02G1402-004 |
| Difficulty metrics | FR-R02G1402-003, 005 |
| Invariants INV-06 content and INV-12 novelty | FR-R02G1402-002, 003 |
| Schema migration, error handling | FR-R02G1402-004, 006 |
| Deterministic tests | SC-R02G1402-002, 003 |
| No Stage One breakage | FR-R02G1402-006 |
