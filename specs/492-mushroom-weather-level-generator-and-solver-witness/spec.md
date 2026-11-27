# Feature Specification: R02-G20-02 — Mushroom Weather: level generator and solver witness

**Feature Branch**: `492-mushroom-weather-level-generator-and-solver-witness` (spec directory only; work on `main`)

**Created**: 2026-11-26

**Status**: Clarified

**Ledger gate**: R02-G20-02 (migration ledger, game feature of experience R02-G20) · ID namespace FR-R02G2002-###,
SC-R02G2002-###, T-R02G2002-###

**Input**: User description: the archived R02-G20-02 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Generate solvable seeded levels with certificates and difficulty metrics" for Mushroom Weather, with the canonical
overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/492-mushroom-weather-level-generator-and-solver-witness`; FR-R02G2002-###,
  SC-R02G2002-###, T-R02G2002-###.
- **Packaging (ADR-0009):** experience R02-G20 (`r02-g20.mushroom-weather`, free) in the one app; this feature extends
  the pure `MushroomWeatherCore` of feature 491. No app target, bundle identifier, scheme or store listing.
- **Superseded parts of the source prompt:** price and "no IAP"; the Round 2 lock and per-round device campaign.
  **Device-only items:** none (pure logic). **Owner-only items:** none.
- **Content count:** the canonical catalog is the 100-level manifest of the archived design (`python3
  scripts/planning_index.py levels --experience R02-G20`: 20 levels in each of bands 1 … 5, each with its planned seed
  and moves budget 8 … 19, control emphases `route humidity`, `commit season`, `place fungus`, `adjust mist vent` and
  `open canopy`, 20 each). The prompt's "content count 76" is a milestone figure, as for the earlier round-two games.
- **Kernel extension (additive):** the manifest's budgets reach 19, above feature 491's budget range 1 … 12, so the
  range widens to 1 … 24; and a level may declare its pod sites, the cells where spore pods may be placed (placements
  elsewhere are refused), so the solver searches, and proves minimality over, the whole move space of a level. A level
  without sites keeps feature 491's behaviour, stored form and fingerprint.
- **Model:** feature 482 (Microscopic Aurora's content pipeline) for manifest, generator, solver, witness files, digest
  and progression, adapted to the weather rules of feature 491: a move places, moves or removes a pod, sets a vent or
  the moonlight, and the run ends the level.

## Clarifications

### Session 2026-11-26

Answered autonomously under the owner's standing delegation, safest well-supported option each time, following feature
482's answers where the games agree. Facts checked (read-only, 2026-11-26): R02-G20-01's `MushroomWeatherLevel` (6 … 12
by 6 … 14 cells, humidity 0 … M, M 1000 … 10000, run 20 … 200 cycles, K 5 … T, 1 … 6 pod slots, 0 … 6 vents, 1 … 6
colonies, budget 1 … 12, a starting arrangement that must not win), `MushroomWeatherForest` (a report depends only on the
set of pod cells, the vent states and the moonlight), `MushroomWeatherPlay` and `MushroomWeatherPuzzle` (its move list
reaches 1,017 actions, within R02-F23's branching budget of 1,024); R02-F24's `PuzzleCatalog.digest(id:identities:)` and
the standard `ProgressionRule` (drop at most 1, jump at most 3); `SeedDerivation.derive(_:index:)` and `SeededRandom`;
the canonical manifest's 100 entries (bands 1 … 5 × 20, budgets 8 … 19, five control emphases, 20 each). The ranges
below were measured before they were written down: a prototype of this generator and solver on the real kernel, run
over the real 100 manifest entries, certified every entry within candidate index 2, with at most 1,128 arrangements
judged for one level (1,115 for an accepted level) and 24,947 for the whole catalog (21.2 s in a debug build, at most
1.14 s for one level and 3.53 s for a group of five); witness lengths by band were 2, 3, 3, 4 and 5, with no
progression drop or jump; two full runs were identical; an independent breadth-first search over the puzzle's moves on
levels 1, 2, 21, 22, 41, 42, 61, 62, 81 and 82 reproduced the solver's counts per depth and found no shorter win.
Earlier profiles were rejected: plans 2, 3, 3, 4, 5 with vents and sites anywhere needed up to candidate index 42 and
5.4 s for one level, because most candidates were reducible; requiring vents and sites next to a colony fixed it.

- Q: How does the kernel change, and how is a level built from its manifest entry? → A: the kernel widens the budget
  range to 1 … 24 and gains optional pod sites: a level may list 2 … 8 distinct floor cells without a colony as its
  sites; with sites, a pod placed on any other cell is refused `r02-g20.action` ("not a site") by the play and is not
  a move of the puzzle contract, and every starting pod must stand on a site; a level without sites encodes,
  fingerprints and plays exactly as in feature 491 (the field is omitted). The level refuses, in order after "pods
  share a cell", "sites" (count), "sites duplicate", "site off floor", "site on colony" and "pod not on a site". The 100
  entries are a table in `MushroomWeatherManifest` with their provenance. Candidate c of entry n draws from
  `SeededRandom(seed: SeedDerivation.derive(plannedSeed, index: c))`, in this order: rows, columns; the blocked count and
  cells; the starting humidity of each floor cell in row-major order (0 … 200); D (4 … 12); each floor cell's rate
  (20 … 60); the pod rules (release 10 … 30, grown release min(80, r + 0 … 30), threshold 800 … 4000); the colony cells;
  the vents, each on a "near" cell (a floor cell without a colony within one step, diagonals included, of a colony),
  open rate 120 … 200, closed rate 0 … 30, a starting state; the starting moonlight (0 … 3); M (1000 … 2000); T
  (30 … 40); K (6 … 10); the sites (the near cells that are not vents, up to the band's count); the winning choice (pod
  count k from max(1, plan − V − 1) … min(plan, P, S), the rest a moonlight change when it exceeds the vents and the
  remaining vent toggles, picked by partial shuffles); a margin per colony; each colony's sensitivity. The level starts
  with no pod. Each colony's band is its minimum and maximum over the last K cycles of the winning run, widened by its
  margin and clamped to 0 … M; a sensitive colony's floor is min(low·3/4, its lowest value over the winning run).
  Band profiles (rows, columns, blocked, vents, slots, colonies, sites, plan, margin): band 1 (6 … 7, 6 … 7, 2 … 5, 1,
  2, 2, 4, 2, 4 … 6), band 2 (6 … 8, 6 … 8, 3 … 6, 2, 2, 3, 4, 3, 3 … 5), band 3 (7 … 8, 7 … 9, 3 … 7, 2, 3, 3, 5, 3,
  2 … 4), band 4 (7 … 9, 8 … 10, 4 … 8, 3, 3, 4, 6, 4, 1 … 3), band 5 (8 … 9, 8 … 10, 4 … 8, 3, 4, 5, 6, 5, 1 … 2). Budget
  = the manifest's; ids `mushroom-weather-NNN`; tutorial on levels 1 … 3; difficulty = band. A candidate is skipped when
  there are too few near cells, the winning run fails, the level rules refuse it (including a start that already wins),
  the winning choice still wins with any one action removed ("reducible"), its floor and colonies equal the previous
  level's (FR-R02G2002-007), the solver's minimal plan is not the band's plan length, or the plan does not win through
  the play; at most 64 candidates, then `generation(n)`. Impact: FR-R02G2002-001, 007; SC-R02G2002-001, 003, 004.
- Q: How does the solver find a minimal plan, and what proves nothing shorter wins? → A: a report depends only on the
  set of pod cells, the vent states and the moonlight, and from a start with no pod the fewest actions reaching an
  arrangement are its pod count plus the vents it toggles plus one when the moonlight differs (a move replaces a
  removal and a placement, so this is exact); for a level without sites or with a starting pod the solver returns no
  plan. The solver judges depth 0 (the start), then every arrangement at distance 1, 2, …; within a depth by pod count
  ascending, then vent count ascending, then pod site combinations and vent combinations in lexicographic order, then
  the new moonlight ascending, skipping the start's. Depths below the last are judged in that fixed order; the last
  depth is ordered by the band loss of each arrangement's parent (the arrangement without its last action: the
  moonlight change, else the last vent toggle, else the last pod), ties keeping the fixed order: loss = Σ over colonies
  of max(0, low − h, h − high) for its humidity after the last cycle run plus K − min(K, final run), plus M per colony
  when the run fails `dried` or `mold`. The first winning arrangement ends the search; the plan is its placements in slot
  order, then its vent toggles, then its moonlight change, then `run`, replayed through the kernel's play, whose report
  must agree. Work = arrangements judged, counted and bounded at 1,500, above the largest search space up to a plan
  depth (band 5: 1 + 12 + 63 + 192 + 378 = 1,144), as a guard. The minimality proof is the count of arrangements at each
  smaller depth, every one judged and none winning. Impact: FR-R02G2002-002; SC-R02G2002-001, 002, 005.
- Q: What difficulty metrics are stored and what progression is required? → A: `MushroomWeatherDifficulty` holds the
  witness length (actions), the colonies, the narrowest band (high − low), the pod sites, the vents, the arrangements
  judged at smaller depths, the solver work and the nearest miss (the smallest band loss among the arrangements judged
  at smaller depths). The catalog in manifest order keeps R02-F24's standard `ProgressionRule` (drop at most 1, jump at
  most 3) on the witness length; band means must not fall (measured above: 2, 3, 3, 4, 5). Impact: FR-R02G2002-003, 005;
  SC-R02G2002-004.
- Q: What is in a witness file and how is it checked? → A: `docs/games/mushroom-weather/levels/NNN.witness.json`, JSON
  schema 1 with sorted keys: number, the level's stored form (with its sites), the actions (the plan, then `run`), the
  state digest after every action (16 hex characters of the SHA-256 of the arrangement and the actions spent), the play
  fingerprints after `begin` (and `dismissTutorial` when the level has one) and after each action, the terminal report
  (the ledger totals of the run — total at the start, released, evaporated, total at the end — and each colony's final
  run, longest run and first cycle out of band, and the cycles run), the counterexample (the depth one below the plan,
  the number of arrangements at that depth, none winning, and the nearest miss), the difficulty and the candidates
  skipped. A test rebuilds every witness and compares bytes; it writes the files only with
  `MUSHROOM_WEATHER_WRITE_WITNESSES=1`. Decoding refuses newer schemas, damaged files and witnesses that no longer
  replay. Impact: FR-R02G2002-004; SC-R02G2002-003, 005.
- Q: How is the catalog identified, how long may certification take and how are refusals named? → A: the digest is
  `PuzzleCatalog<MushroomWeatherPuzzle>.digest(id: "mushroom-weather", identities:)` over the 100 level fingerprints in
  manifest order, pinned in a test. Certification tests are split into 20 groups of 5 levels so each runs under 10
  seconds on a debug host build (measured locally, not asserted on CI); generated levels are cached per process, since
  level n's neighbour rule needs level n − 1. New refusals: `generation(Int)` (`r02-g20.generation`) and
  `witness(String)` (`r02-g20.witness`). The independent check of SC-R02G2002-002 runs a breadth-first search over the
  puzzle contract's moves (place, move, remove, vent, moonlight) with no loss ordering on the two levels with the
  fewest sites, then fewest colonies, in each band (ties by level number), reproducing the per-depth counts with no
  win below the plan length. The two existing kernel tests that use 13 as an out-of-range budget move to 25. Impact:
  FR-R02G2002-006; SC-R02G2002-002, 006.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Every shipped level can be solved (Priority: P1) 🎯

A player opening any of the 100 levels can always win: some arrangement of pods, vents and moonlight within the moves
budget gives a run in which every colony ends in its band without a sensitive colony drying out or a cell turning to
mold. The game has proof of it for every level, and proof that no fewer actions would do.

**Why this priority**: an unsolvable level breaks the game.

**Independent Test**: each level's stored witness actions, replayed from the start, win on the run within the budget;
every action's resulting state equals the stored digest; the proof that fewer actions cannot win is re-checked.

**Acceptance Scenarios**:

1. **Given** any catalog level, **When** its witness is replayed and the weather is run, **Then** the level is won
   within the budget.
2. **Given** any catalog level, **When** any arrangement reachable with fewer actions than the witness is run, **Then**
   none wins.
3. **Given** a catalog level, **When** the solver runs again, **Then** it finds the same witness.

### User Story 2 - Levels come from their planned seeds (Priority: P1)

Each level is built from its manifest seed, band and budget the same way on every build; a changed rule or seed changes
the pinned fingerprints and fails the checks.

**Why this priority**: reproducible content is what the witnesses, the digest and every later feature rely on.

**Independent Test**: building the catalog twice gives identical levels; the catalog digest equals the pinned value.

**Acceptance Scenarios**:

1. **Given** the manifest, **When** the catalog is built twice, **Then** every level and the digest are identical.
2. **Given** a manifest entry whose candidates are unsuitable, **When** the generator runs, **Then** it moves to the
   next candidate deterministically and records how many it skipped.

### User Story 3 - Difficulty that means something (Priority: P2)

Each level carries difficulty metrics from the solver's actual result: the actions the witness needs, the number of
colonies, the narrowest band, the number of pod sites and vents, the arrangements searched and the solver's work. Harder
bands mean more colonies with narrower bands and more actions working together, never faster reactions.

**Why this priority**: the five bands must feel like a progression.

**Independent Test**: band by band, the mean witness length does not fall; the catalog keeps the progression rule.

**Acceptance Scenarios**:

1. **Given** the catalog, **When** the witness lengths are averaged per band, **Then** no band's mean is below the
   previous band's.

### User Story 4 - Honest witness files (Priority: P2)

For each level a witness file records the level, the winning actions, a digest of the state after every action, the
terminal weather report (the humidity conservation ledger and the colony survival intervals) and the counterexample
proof that fewer actions cannot win. Any edited or fake witness is caught.

**Why this priority**: the certificates are the release evidence for the content.

**Independent Test**: all 100 witness files match what the generator and solver produce now, byte for byte; an edited
file is refused.

**Acceptance Scenarios**:

1. **Given** the 100 witness files, **When** the witnesses are regenerated, **Then** every file matches byte for byte.
2. **Given** a witness file with one changed character, a newer schema or a damaged body, **When** it is decoded,
   **Then** it is refused with a named reason.

### Edge Cases

- **A seed whose candidate is unsuitable for its band:** the generator moves to the next candidate deterministically
  (bounded) and records how many it skipped; no candidate within the bound is a named refusal.
- **A candidate whose starting arrangement already wins, or that dries out or molds with every arrangement:** never
  emitted (the kernel refuses the first; the solver finds no plan for the second).
- **More than one minimal setting:** allowed; the witness is the one the solver finds in its fixed order.
- **Adjacent levels with the same floor and colonies:** the later candidate is skipped (FR-R02G2002-007).
- **A plan needing more actions than the budget:** not emitted.
- **A search over its work bound:** the candidate is skipped (counted work, never timed).
- **A colony exactly on a band edge, a cell exactly at the mold bound, a growth integral at its threshold:** decided
  exactly by the kernel's integer rules; the generator and solver add no tolerance.
- **A two-pod plan whose second pod would land on the first's site:** impossible by construction; the witness places
  pods on distinct sites in slot order.
- **Damaged, newer or edited witness files:** refused with a named reason.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G2002-001**: A generator MUST build each catalog level deterministically from its manifest number, seed, band
  and budget; only levels the kernel accepts and the solver certifies within the budget MAY be emitted.
- **FR-R02G2002-002**: A solver MUST find a minimal sequence of actions after which running the weather wins, by a
  search over arrangements (pod sites, vent states, moonlight) by the number of actions from the start, each judged by
  the exact grid diffusion of feature 491 with its bounded evapotranspiration, with reachability checks skipping
  arrangements already reached at a smaller depth (never pruning by outcome) and a band loss guiding the order, with its work bounded and counted, and
  MUST prove that no shorter sequence wins; every plan it reports MUST be replayed through the kernel's play.
- **FR-R02G2002-003**: Each level MUST carry difficulty metrics (witness length, colonies, narrowest band, pod sites,
  vents, arrangements searched, solver work) derived from the level and the solver.
- **FR-R02G2002-004**: Each level MUST have a versioned witness record (level, actions, per-action state digests,
  terminal weather report with its ledger and colony survival intervals, counterexample proof); damaged, newer and
  edited files MUST be refused.
- **FR-R02G2002-005**: The catalog of 100 levels MUST have a digest pinned in tests and MUST satisfy the shared
  progression rule; band means of the witness length never fall.
- **FR-R02G2002-006**: Invalid requests MUST be refused with stable reason codes `r02-g20.*`; existing code MUST change
  only additively; every new public name is documented; the reference regression passes.
- **FR-R02G2002-007**: Each emitted level MUST differ from its neighbours in the manifest (its fingerprint and its floor
  and colonies are not those of the previous level), so adjacent seeds give genuinely different puzzles.

### Key Entities

- **Manifest entry**: number, planned seed, band, moves budget, control emphasis.
- **Minimality proof**: every arrangement reachable with fewer actions, none of which wins.
- **Solver result**: the actions, the work counted, the proof.
- **Difficulty**: witness length, colonies, narrowest band, pod sites, vents, arrangements searched, work.
- **Witness**: schema, the level's stored form, actions, per-action state digests, terminal weather report,
  counterexample, skipped candidates.
- **Catalog**: the 100 levels in manifest order with a digest.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G2002-001**: All 100 catalog levels are won by replaying their witness and running the weather, within the
  budget.
- **SC-R02G2002-002**: The minimality proof equals an independent brute-force check on sampled catalog levels (at least
  two per band).
- **SC-R02G2002-003**: Building the catalog twice gives identical levels and the pinned digest; each witness file
  matches the regenerated witness byte for byte.
- **SC-R02G2002-004**: The mean witness length does not fall from one band to the next; the catalog keeps its
  progression rule.
- **SC-R02G2002-005**: For every level, no arrangement reachable with fewer actions than its witness wins; edited, newer
  and damaged witness files are refused.
- **SC-R02G2002-006**: Existing tests pass unchanged, except feature 491's two out-of-range budget cases (the level
  test and the input-budget invariant), which move from 13 to 25 with the widened range; the reference regression passes
  7 of 7; each unit test finishes in under 10 seconds on a debug host build, the catalog certification split as needed.

## Assumptions

- The 100 witness files live in `docs/games/mushroom-weather/levels/NNN.witness.json` (the manifest's "Required
  artifact"); they are regenerated only by a test run with an explicit opt-in and checked byte for byte on every other
  run.
- "Grid diffusion with bounded evapotranspiration and reachability checks" is read as: the solver enumerates the
  arrangements reachable by actions (pod sites, vent states, moonlight levels) by the number of actions from the start,
  judging each with the kernel's exact run (whose evaporation is bounded below 35 % a cycle), skips arrangements that
  are reachable at a shallower depth (reachability), and orders those at each depth by a band loss (how far the colonies
  end from their bands), so the first win found is minimal and the loss only speeds the search.
- The source constraints "keep unstable diffusion timestep, negative humidity, growth update tied to FPS, spore density
  excessive and small mushrooms invisible outside the admissible zone" are read as: the kernel's fixed-step integer law
  is stable by construction (D ≤ 12 over 64) and never negative; growth counts cycles, never frames; a level has at most
  six pods; colony and pod cells are named in words, so none depends on being seen.
- Levels are presented, hinted and played through later features (R02-G20-03 … 07); this feature draws nothing.
- Accessibility and observability: every generated level is named in words by feature 491's kernel (pods, vents,
  colonies, cells, humidity against each band), so no level depends on colour; the witness files and the difficulty
  metrics are the content pipeline's observable record, and skipped candidates are counted, not hidden.
- The manifest's numbers, seeds, bands and budgets are copied from the project's own archived design; no third-party
  content is used.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Solvable seeded levels | FR-R02G2002-001, 002 |
| Solver: grid diffusion with bounded evapotranspiration and reachability checks | FR-R02G2002-002 |
| Truth metric: humidity conservation ledger and colony survival intervals | FR-R02G2002-004 |
| Certificates (witness, counterexample, per-action digests) | FR-R02G2002-004 |
| Difficulty metrics | FR-R02G2002-003, 005 |
| Different puzzle from adjacent seeds | FR-R02G2002-007 |
| Schema migration, error handling | FR-R02G2002-004, 006 |
| Deterministic tests | SC-R02G2002-002, 003 |
| No Stage One breakage | FR-R02G2002-006 |
