# Feature Specification: R02-G22-02 — Mycelium Architect: level generator and solver witness

**Feature Branch**: `512-mycelium-architect-level-generator-and-solver-witness` (spec directory only; work on `main`)

**Created**: 2026-11-27

**Status**: Clarified

**Ledger gate**: R02-G22-02 (migration ledger, game feature of experience R02-G22) · ID namespace FR-R02G2202-###,
SC-R02G2202-###, T-R02G2202-###

**Input**: User description: the archived R02-G22-02 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Generate solvable seeded levels with certificates and difficulty metrics" for Mycelium Architect, with the canonical
overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/512-mycelium-architect-level-generator-and-solver-witness`; FR-R02G2202-###,
  SC-R02G2202-###, T-R02G2202-###.
- **Packaging (ADR-0009):** experience R02-G22 (`r02-g22.mycelium-architect`, free) in the one app; this feature extends
  the pure Mycelium Architect Core of feature 511 (module `Packages/ExperiencesRound02/MyceliumArchitect`). No app
  target, bundle identifier, scheme or store listing.
- **Superseded parts of the source prompt:** price and "no IAP"; the Round 2 lock and per-round device campaign.
  **Device-only items:** none (pure logic). **Owner-only items:** none.
- **Content count:** the canonical catalog is the 100-level manifest of the archived design (`python3
  scripts/planning_index.py levels --experience R02-G22`: 20 levels in each of bands 1 … 5, each with its planned seed
  and moves budget 8 … 11, 10 … 13, 12 … 15, 14 … 17, 16 … 19 by band, control emphases `steer growth`, `commit graph`,
  `place nutrient`, `seed filament` and `block toxin`, 20 each; required concepts `bounded branching graph`,
  `shortest-path nutrients`, `root terminal connectivity`, `toxic-zone avoidance` and `growth budget`, 20 each). The
  prompt's "content count 84" is a milestone figure inside that catalog, as for features 492 and 502.
- **Kernel extension (additive):** every manifest budget (8 … 19) lies inside feature 511's budget range 1 … 24. A level
  may declare placement sites, the only cells on which the player may place nutrients and blockers, so the solver
  searches, and proves minimality over, a bounded move space ("quantize … to legal values" in every manifest row). A
  level without sites keeps feature 511's behaviour, stored form and fingerprint.
- **Model:** feature 502 (Binary Gardens' content pipeline) and feature 492 (Mushroom Weather's) for manifest,
  generator, solver, witness files, digest and progression, adapted to the growth rules of feature 511.

## Clarifications

### Session 2026-11-27

Answered autonomously under the owner's standing delegation, safest well-supported option each time, following features
502 and 492 where the games agree. Facts checked (read-only, 2026-11-27): feature 511's specification, data model and
contract (`MyceliumArchitectLevel` with a 4 … 32 board, 1 … 6 terminals, 0 … 8 fixed nutrients, strength 1 … 8, reach
1 … 16, penalties 0 … 8, up to 6 placed nutrients and 6 blockers, 1 … 4 seeds with locked starting seeds, 1 … 128
pulses, nutrient budget 2 … 4094, weight limit 2 … budget, action budget 1 … 24; growth by pulses with ties to the
smaller turn, branching at consumed nutrients, weights 2 and 3; the judge starved → toxic → unreached → overweight;
`MyceliumArchitectPuzzle` whose moves are the legal placements, clears, seeds and unseeds while actions are left); the
kernel is drafted and tested (50 host tests) and is installed in the repository with R02-G22-01, before this feature's
implementation starts; R02-F24's `PuzzleCatalog.digest(id:identities:)` and the standard `ProgressionRule` (drop at most
1, jump at most 3); `SeedDerivation.derive(_:index:)` and `SeededRandom`; the canonical manifest's 100 entries (bands
1 … 5 × 20, budgets as above, five control emphases and five required concepts, 20 each). The search sizes below are
arithmetic bounds, not measurements; the first implementation task runs the real generator and solver over the real 100
entries and records in research.md R4 the largest candidate index per band, the work per level and for the catalog,
the witness lengths by band and the slowest level and group of five; a profile value changed there is written back into
this section, research.md, data-model.md and plan.md in the same commit.

- Q: How does the kernel change, and what is a placement site? → A: the level gains optional sites, 2 … 12 distinct
  empty cells (not the root, a terminal, a rock, a toxin or a fixed nutrient), stored in ascending (row, column); with
  sites, `nutrient(cell)` and `blocker(cell)` on a cell that is not a site are refused `r02-g22.action` ("not a site")
  by the play and are not moves of the puzzle contract; without sites (the default, omitted from the stored form) a
  level encodes, fingerprints and plays exactly as in feature 511. The level refuses "site count", "site" (off the
  board) and "site not empty" after feature 511's range and shared-cell checks and before "nothing placeable" and
  "already won". Every catalog level declares sites. Impact: FR-R02G2202-009; SC-R02G2202-007.
- Q: How is a level built from its manifest entry? → A: the 100 entries are a table in `MyceliumArchitectManifest` with
  their provenance. Candidate c of entry n draws from `SeededRandom(seed: SeedDerivation.derive(plannedSeed, index:
  c))`, in this order: the board (the band's width and height), the root (column 1 … 2, any row 1 … H − 2), rocks and
  toxins (each cell outside the root's 3 × 3 neighbourhood a rock with the band's ‰ and else a toxin with the band's ‰),
  the fixed nutrients (the band's count on empty cells), strength, reach, κ, ο and pulses (the band's ranges), the seed
  limit (the band's), the sites (the band's count of empty cells), the plan (the band's length p of actions, each a
  seed in a direction not yet seeded within the seed limit, a nutrient on a free site or a blocker on a free site; the
  emphasised kind first when the emphasis names one — `place nutrient` a nutrient, `block toxin` a blocker, `seed
  filament` a seed — the rest drawn uniformly among the kinds still possible), the starting seeds (0 … seed limit − plan
  seeds directions not in the plan, at least 1 when the plan has no seed). The winning arrangement is the starting
  seeds plus the plan. It is grown on a probe level with a placeholder terminal and the widest budget; the candidate is
  skipped unless that growth is neither toxic nor starved and grows at least 4 cells beyond the root. The terminals (the
  band's count) are the grown cells, other than sites and fixed nutrients, with the latest grown pulses (ties by cell
  order); nutrient budget = grown weight + the band's budget slack, weight limit = grown weight + the band's limit slack
  (at most the budget). Band profiles (width × height, rock ‰, toxin ‰, terminals, sites, fixed nutrients, seed limit,
  strength, reach, κ, ο, pulses, budget slack, limit slack, plan p): band 1 (8 × 8, 80, 30, 1, 4, 0, 1, 4 … 8, 4 … 8,
  1 … 2, 0 … 1, 48, 4 … 8, 2 … 6, 1), band 2 (9 … 10, 90, 40, 1 … 2, 5, 0 … 1, 2, 3 … 8, 4 … 8, 1 … 3, 0 … 2, 64, 3 … 6,
  1 … 4, 2), band 3 (10 … 12, 100, 50, 2, 6, 0 … 1, 2, 3 … 7, 4 … 10, 1 … 3, 0 … 2, 80, 2 … 5, 0 … 3, 3), band 4 (12 … 14,
  110, 60, 2 … 3, 6, 1 … 2, 2, 2 … 7, 5 … 10, 2 … 4, 1 … 2, 96, 1 … 4, 0 … 2, 3), band 5 (14 … 16, 120, 70, 3, 6, 1 … 2,
  2, 2 … 6, 5 … 12, 2 … 4, 1 … 3, 112, 0 … 3, 0 … 1, 4). Placement limits are the plan's nutrient and blocker counts
  plus 1 (at most 6); budget = the manifest's; ids `mycelium-architect-NNN`; tutorial on levels 1 … 3; difficulty =
  band. A candidate is skipped when the level rules refuse it (including a start that already wins), its board (size,
  root, rocks, toxins) equals the previous level's, the solver's minimal plan is not p, or the plan does not win through
  the play; at most 64 candidates, then `generation(n)`. Impact: FR-R02G2202-001, 007; SC-R02G2202-001, 003, 004.
- Q: How does the solver find a minimal plan, and what proves nothing shorter wins? → A: breadth-first over
  arrangements by the number of actions from the start (the shortest path in the graph of arrangements). Depth 0 is the
  start. Depth d + 1 takes the arrangements of depth d in ascending order of their loss (ties keep their discovery order)
  and, from each, the puzzle contract's moves in its fixed order (research R14 of feature 511), skipping arrangements
  already reached at any depth (reachability, never pruning by outcome); each new arrangement is judged on discovery by
  the kernel's growth. Loss = Σ over terminals not reached of 16 × the Chebyshev distance to the nearest grown cell
  + max(0, weight − limit) + 1 024 when the growth is toxic or starved. The first winning arrangement ends the search;
  the plan is its path of moves, then `run`, replayed through the play, whose report must agree. Work = arrangements
  judged, bounded at 20 000 per candidate as a guard (over it the candidate is skipped; counted, never timed). Search
  depth: at most the band's p. The minimality proof is the count of arrangements at each smaller depth, every one
  judged and none winning. Impact: FR-R02G2202-002; SC-R02G2202-001, 002, 005.
- Q: What difficulty metrics are stored and what progression is required? → A: `MyceliumArchitectDifficulty` holds the
  witness length, the terminals, the board cells, the toxins, the sites, the move space (the number of moves from the
  start), the arrangements judged at smaller depths, the solver work and the nearest miss (the smallest loss among the
  arrangements judged at smaller depths, the start included). The catalog keeps R02-F24's standard `ProgressionRule` on
  the witness length; band means do not fall (by construction 1, 2, 3, 3, 4). Impact: FR-R02G2202-003, 005;
  SC-R02G2202-004.
- Q: What is in a witness file, how is the catalog identified and how is certification split? → A:
  `docs/games/mycelium-architect/levels/NNN.witness.json`, JSON schema 1 with sorted keys: number, the level's stored
  form, the actions (the plan, then `run`), the state digest after every action (16 hex characters of the SHA-256 of the
  arrangement and the actions spent), the play fingerprints after `begin` (and `dismissTutorial` when the level has one)
  and after each action, the terminal report (the truth metric: each terminal reached with its pulse and path weight,
  the total branch cost against budget and limit, the node count, the forbidden-zone hits (the first toxic entry or
  none), the outcome), the counterexample (the depth one below the plan, the number of arrangements at that depth, none
  winning, and the nearest miss: its loss, its arrangement and its first failure in words), the difficulty and the
  candidates skipped. A test rebuilds every witness and compares bytes; it writes the files only with
  `MYCELIUM_ARCHITECT_WRITE_WITNESSES=1`. Decoding refuses newer schemas (`r02-g22.newer-schema`), damaged files and
  witnesses that no longer replay (`r02-g22.witness`). The digest is `PuzzleCatalog<MyceliumArchitectPuzzle>.digest(id:
  "mycelium-architect", identities:)` over the 100 fingerprints, pinned in a test. Certification tests are split into
  20 groups of 5 levels, each under 10 s on a debug host build (measured locally, not asserted on CI); generated levels
  are cached per process. New refusals: `generation(Int)` (`r02-g22.generation`) and `witness(String)`
  (`r02-g22.witness`). The independent check of SC-R02G2202-002 enumerates every action sequence shorter than the plan
  through the puzzle contract's moves, with no visited set and no loss ordering, on the two levels with the smallest
  move space in each band: none wins, and the arrangements first reached at each length equal the solver's count.
  INV-06 and INV-12 get `testMyceliumArchitectContentBoundary` and `testMyceliumArchitectNoveltyBoundary`, each with a
  seeded neighbouring-input check. Impact: FR-R02G2202-004, 005, 006, 008; SC-R02G2202-002, 003, 005, 006, 007.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Every shipped level can be solved (Priority: P1) 🎯

A player opening any of the 100 levels can always win: some placement of nutrients and blockers and some seeds at the
root, within the moves budget, grow a network that reaches every terminal within the weight limit without touching
toxin or running out of nutrient. The game has proof of it for every level, and proof that no fewer actions would do.

**Why this priority**: an unsolvable level breaks the game.

**Independent Test**: each level's stored witness actions, replayed from the start, win on the run within the budget;
every action's resulting state equals the stored digest; the proof that fewer actions cannot win is re-checked.

**Acceptance Scenarios**:

1. **Given** any catalog level, **When** its witness is replayed and the growth is run, **Then** the level is won within
   the budget.
2. **Given** any catalog level, **When** any arrangement reachable with fewer actions than the witness is run, **Then**
   none wins.
3. **Given** a catalog level, **When** the solver runs again, **Then** it finds the same witness.

### User Story 2 - Levels come from their planned seeds (Priority: P1)

Each level is built from its manifest seed, band and budget the same way on every build; a changed rule or seed changes
the pinned fingerprints and fails the checks.

**Independent Test**: building the catalog twice gives identical levels; the catalog digest equals the pinned value.

**Acceptance Scenarios**:

1. **Given** the manifest, **When** the catalog is built twice, **Then** every level and the digest are identical.
2. **Given** a manifest entry whose candidates are unsuitable, **When** the generator runs, **Then** it moves to the
   next candidate deterministically and records how many it skipped.

### User Story 3 - Difficulty that means something (Priority: P2)

Each level carries difficulty metrics from the solver's actual result: the actions the witness needs, the terminals,
the board size, the toxins near the network, the sites and move space, the arrangements searched and the solver's work.
Harder bands mean more terminals, tighter weight limits and more placements working together, never faster reactions.

**Independent Test**: band by band, the mean witness length does not fall; the catalog keeps the progression rule.

**Acceptance Scenarios**:

1. **Given** the catalog, **When** the witness lengths are averaged per band, **Then** no band's mean is below the
   previous band's.

### User Story 4 - Honest witness files (Priority: P2)

For each level a witness file records the level, the winning actions, a digest of the state after every action, the
terminal growth report (root-to-terminal connectivity, total branch cost and forbidden-zone hits) and the
counterexample proof that fewer actions cannot win, with the nearest miss and why it fails. Any edited or fake witness
is caught.

**Independent Test**: all 100 witness files match what the generator and solver produce now, byte for byte; an edited
file is refused.

**Acceptance Scenarios**:

1. **Given** the 100 witness files, **When** the witnesses are regenerated, **Then** every file matches byte for byte.
2. **Given** a witness file with one changed character, a newer schema or a damaged body, **When** it is decoded,
   **Then** it is refused with a named reason.

### Edge Cases

- **A seed whose candidate is unsuitable for its band:** the generator moves to the next candidate deterministically
  (at most 64) and records how many it skipped; no candidate within the bound is a named refusal.
- **A candidate whose starting arrangement already wins:** never emitted (the kernel refuses it).
- **More than one minimal arrangement:** allowed; the witness is the one the solver finds in its fixed order.
- **Adjacent levels with the same board:** the later candidate is skipped.
- **A plan needing more actions than the budget, or a search over its work bound:** the candidate is skipped (counted
  work, never timed).
- **A placement on a cell that is not a site, in a level with sites:** refused by the play and absent from the solver's
  moves.
- **A weight exactly at the budget or the limit:** decided exactly by the kernel's integer rules; the generator and
  solver add no tolerance.
- **Damaged, newer or edited witness files:** refused with a named reason.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G2202-001**: A generator MUST build each catalog level deterministically from its manifest number, seed, band
  and budget, from a winning arrangement drawn first; only levels the kernel accepts and the solver certifies within the
  budget MAY be emitted.
- **FR-R02G2202-002**: A solver MUST find a minimal sequence of actions after which running the growth wins, by a bounded
  search over arrangements by the number of actions from the start (the source's graph shortest path over arrangements,
  each judged by feature 511's deterministic branching growth and the target topology check), with reachability checks
  (never pruning by outcome) and a growth loss guiding the order, with its work bounded and counted, and MUST prove that
  no shorter sequence wins; every plan it reports MUST be replayed through the kernel's play.
- **FR-R02G2202-003**: Each level MUST carry difficulty metrics (witness length, terminals, board cells, toxins, sites,
  move space, arrangements searched, solver work, nearest miss) derived from the level and the solver.
- **FR-R02G2202-004**: Each level MUST have a versioned witness record (level, actions, per-action state digests,
  terminal growth report with connectivity, branch cost and forbidden-zone hits, counterexample proof with the nearest
  miss and its failure); damaged, newer and edited files MUST be refused.
- **FR-R02G2202-005**: The catalog of 100 levels MUST have a digest pinned in tests and MUST satisfy the shared
  progression rule; band means of the witness length never fall.
- **FR-R02G2202-006**: Invalid requests MUST be refused with stable reason codes `r02-g22.*`; existing code MUST change
  only additively; every new public name is documented; the reference regression passes.
- **FR-R02G2202-007**: Each emitted level MUST differ from its neighbours in the manifest (its fingerprint differs and
  its board is not the previous level's), so adjacent seeds give genuinely different puzzles.
- **FR-R02G2202-008**: The content invariant (every level has a replaying witness and its difficulty reflects the
  solver's actual work) and the novelty invariant (the mechanic is checked, not its name: every witness consists only of
  placements and seeds decided by gradient growth, and removing any one action of the witness makes the run fail) MUST
  each have a named direct test and a seeded neighbouring-input check.
- **FR-R02G2202-009**: A level MAY declare placement sites; with them, nutrients and blockers MUST be placed only on
  sites and placements elsewhere MUST be refused; a level without sites MUST encode, fingerprint and play exactly as in
  feature 511.

### Key Entities

- **Manifest entry**: number, planned seed, band, moves budget, control emphasis, required concept.
- **Band profile**: board size, rocks and toxins, terminals, sites, field and penalty ranges, pulses, budget slack, plan
  length.
- **Minimality proof**: every arrangement reachable with fewer actions, none of which wins.
- **Solver result**: the actions, the work counted, the proof, the nearest miss.
- **Difficulty**: witness length, terminals, board cells, toxins, sites, move space, arrangements searched, work,
  nearest miss.
- **Witness**: schema, the level's stored form, actions, per-action state digests, terminal growth report,
  counterexample, difficulty, skipped candidates.
- **Catalog**: the 100 levels in manifest order with a digest.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G2202-001**: All 100 catalog levels are won by replaying their witness and running the growth, within the
  budget.
- **SC-R02G2202-002**: The minimality proof equals an independent brute-force check on sampled catalog levels (at least
  two per band).
- **SC-R02G2202-003**: Building the catalog twice gives identical levels and the pinned digest; each witness file
  matches the regenerated witness byte for byte.
- **SC-R02G2202-004**: The mean witness length does not fall from one band to the next; the catalog keeps its
  progression rule.
- **SC-R02G2202-005**: For every level, no arrangement reachable with fewer actions than its witness wins; edited, newer
  and damaged witness files are refused.
- **SC-R02G2202-006**: Existing tests pass unchanged; the reference regression passes 7 of 7; each unit test finishes in
  under 10 seconds on a debug host build, the catalog certification split as needed.
- **SC-R02G2202-007**: The content and novelty boundary tests pass on all 100 levels with their neighbouring-input
  checks; a level with sites round-trips with its fingerprint and refuses an off-site placement, and a level without
  them keeps its feature-511 fingerprint.

## Assumptions

- The 100 witness files live in `docs/games/mycelium-architect/levels/NNN.witness.json` (the manifest's "Required
  artifact"); they are regenerated only by a test run with an explicit opt-in and checked byte for byte otherwise.
- "Graph shortest path plus deterministic branching-growth heuristic and target topology check" is read as: the solver
  searches arrangements breadth-first by action count (the shortest path in the graph of arrangements), judges each with
  the kernel's deterministic branching growth, and accepts the first whose grown network reaches every terminal within
  the limit (the topology check); a loss built from shortest-path distances on the lattice only orders the search.
- The manifest's required concepts are covered by the kernel's rules: `bounded branching graph` by the node cap and the
  budget, `shortest-path nutrients` by the field's gradient, `root terminal connectivity` by the won rule, `toxic-zone
  avoidance` by the toxic failure and `growth budget` by the nutrient budget. The rows' "keep … outside the admissible
  zone" phrases (`thin lines flicker`, `exponential branch growth`, `cyclic graph mistaken for tree`, `toxic crossing`,
  `nutrient negative`) are met by later rendering features, the single branch per consumed nutrient, the tree rule
  (no cell grown twice), the toxic failure and the non-negative field.
- Levels are presented, hinted and played through later features (R02-G22-03 … 07); this feature draws nothing.
- Accessibility and observability: every generated level is named in words by feature 511's kernel; the witness files
  and difficulty metrics are the content pipeline's observable record; skipped candidates are counted, not hidden.
- The manifest's numbers, seeds, bands and budgets are copied from the project's own archived design; no third-party
  content is used.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Solvable seeded levels | FR-R02G2202-001, 002 |
| Solver: graph shortest path plus branching-growth heuristic and topology check | FR-R02G2202-002 |
| Truth metric: connectivity, total branch cost, forbidden-zone hits | FR-R02G2202-004 |
| Certificates (witness, counterexample, per-action digests) | FR-R02G2202-004 |
| Difficulty metrics | FR-R02G2202-003, 005 |
| Different puzzle from adjacent seeds | FR-R02G2202-007 |
| Quantize controls to legal values | FR-R02G2202-009 |
| Invariants INV-06 (content) and INV-12 (novelty) | FR-R02G2202-008; SC-R02G2202-007 |
| Schema migration, error handling | FR-R02G2202-004, 006, 009 |
| Deterministic tests | SC-R02G2202-002, 003 |
| No Stage One breakage | FR-R02G2202-006 |

## Negative Requirements / Excluded scope

- No rendering, gestures, hints, adapter, catalog registration or persistence in this feature; no platform floating
  point in the generator or solver; no timed search bound; no content beyond the 100 manifest entries; no device run
  before ImplementationLock-100.
