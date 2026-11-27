# Tasks: R02-G21-02 — Binary Gardens: level generator and solver witness

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G21-02 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G21-02 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Test seed
2_502, neighbouring-input checks seed 2_507; tests stay short (< 10 s each; catalog certification in 20 groups of 5
levels, measured locally, never asserted on CI). No {owner} or {device} tasks (pure logic); no GLSL.

## Phase 1: Setup

- [X] T-R02G2102-001 Baselines after R02-G21-01 is recorded, on the committed tree before any source edit of this — Verified 2026-11-27: baseline-host, baseline-timing, baseline-round02-1, -2 (with BinaryGardens), -3c, -3e, -3f exit=0 (.autonomy/migration/checks/R02-G21-02.baseline-*.json)
  feature: `--name baseline-host`, `--name baseline-timing`, `--name baseline-round02-1`, `-2`, `-3c`, `-3e`, `-3f`
  (the round-two filters of quickstart.md, chunk 2 `'MoonlitMechanism|AcousticConstellator|HarmonicBridges|BinaryGardens'`);
  the rendering baseline is R02-G21-01's rendering runs (exit 0)

## Phase 2: Foundational

- [ ] T-R02G2102-002 Kernel extension (lead): before editing, record one literal fingerprint of a hand level from the
  unchanged kernel (pinned in the new test); then in `Packages/ExperiencesRound02/BinaryGardens/Core/BinaryGardensLevel.swift`
  add `phaseSteps` and an optional `phaseStep` ("g ∈ {1, 2, 3, 4, 6, 8, 12, 16, 24} (default 1)"; refusals "after
  "nothing adjustable", before "separation" and "already won": "phase step" (not a listed divisor), "phase off grid" (a
  starting phase not a multiple of g); g = 1 omitted from the stored form, so every feature-501 level keeps its bytes
  and fingerprint"; trailing `phaseStep: Int = 1` on the public init and the internal probe, a `phaseStep` parameter on the
  internal `init(…, refusingAWin:)`, passed through `Content(level:)` and `Content.level()`; `Content.phaseStep: Int?`;
  `allowsPhase(_:)`); in `Core/BinaryGardensSky.swift` refuse in `changed` "`.action("off the phase grid")` for a phase
  step not a multiple of g, after "phase out of range" and before "locked"" and require phases on the grid in
  `isWellFormed`; in `Core/BinaryGardensPuzzle.swift` list "phase candidates 0, g, 2g, … < 48" only; add
  `generation(Int)` ("r02-g21.generation") and `witness(String)` ("r02-g21.witness") to `Core/BinaryGardensError.swift`;
  create `CoreTests/BinaryGardensPhaseStepTests.swift` (the pinned fingerprint and byte-identical stored form of a level
  without a step, round trip and fingerprint with a step, "phase step" and "phase off grid" refused in that order, the
  play's and the puzzle's "off the phase grid" refusal, move lists on the grid); feature 501's tests unchanged (no
  budget widening); `--name host`

## Phase 3: Story 1 — every shipped level can be solved (P1) 🎯

**Independent test**: each catalog level's witness actions, replayed from the start, win on the run within the budget;
no arrangement reachable with fewer actions wins.

- [ ] T-R02G2102-003 [US1] Manifest, difficulty, solver and generator, measured first (lead): create
  `Packages/ExperiencesRound02/BinaryGardens/Core/BinaryGardensManifest.swift` (the 100 entries "number 1 … 100,
  planned seed, band 1 … 5, budget 8 … 19, emphasis" copied from `python3 scripts/planning_index.py levels --experience
  R02-G21`, "20 per band; budgets 8 … 11, 10 … 13, 12 … 15, 14 … 17, 16 … 19 by band; emphases `adjust orbit`, `phase
  twin stars`, `set luminosity`, `watch world`, `commit light window`, 20 each", provenance round2.md section 6.21.18),
  `Core/BinaryGardensDifficulty.swift` (`BinaryGardensControl` "seven cases in fixed order: star 1 ring, phase,
  luminosity; star 2 ring, phase, luminosity; tilt"; `BinaryGardensPlan` "the first winning arrangement of the
  breadth-first sweep; size = actions.count ≥ 1"; `BinaryGardensDifficulty` actions, worlds, narrowest band, tightest
  window, adjustable, move space, arrangements searched, work, nearest miss; `puzzleDifficulty`),
  `Core/BinaryGardensSolver.swift` (breadth-first by actions from the start; "depth d + 1 expands depth d in ascending
  loss (ties: discovery order) with BinaryGardensPuzzle(level:).moves(in:), skipping arrangements already reached at any depth";
  loss "Σ over worlds of [Σ over ticks 1 … 48 of max(0, c_lo − F, F − c_hi) + max(0, B_lo − I, I − B_hi) +
  1000 · max(0, W − window)]"; work = arrangements judged, bounded at 5,000; search depth at most the band's p, never the
  budget; `replayWins`) and `Core/BinaryGardensGenerator.swift` (band profiles of clarification Q1; candidates from
  `SeedDerivation.derive(plannedSeed, index: c)` in its drawing order and research R15's details; bounds of research
  R12 in exact integer arithmetic; the skip rules "separation not kept within 16 redraws, c_lo = 0, λ_hi > 200 000,
  refused by the level rules, reducible", the neighbour rule (ring radii and worlds equal to the previous level's),
  "no plan within the work bound, plan size ≠ p, replay through the play does not win"; at most 64 candidates then
  `generation(n)`; ids `binary-gardens-NNN`; tutorial on 1 … 3; difficulty = band; `catalog()` in manifest order;
  `catalogDigest`); then, in an isolated copy (no source edits in the working tree while a chain runs), the
  **profile measurement** of research R4: build the whole catalog once in a debug host build with a temporary
  measurement test printing per level the accepted candidate index, the work, the witness length, the arrangements by
  depth and the elapsed time (removed before commit; elapsed time printed, never asserted), and record in research.md
  R4 the largest accepted candidate index per band, the entries needing more than candidate 0, the work per level
  (largest per band) and for the catalog, the witness lengths by band (must be 1, 2, 3, 3, 4), the slowest level and
  group of five and the total time; if an entry reaches `generation(n)`, a band's witness lengths are not its p, or a
  group exceeds 6 s, adjust only the values R4's adjustment ladder names (never p, the phase steps or the budgets),
  re-measure, and write every changed value back into spec clarification Q1, research.md R4, data-model.md and plan.md's
  Technical Context in the same commit; then `Packages/ExperiencesRound02/BinaryGardens/CoreTests/BinaryGardensSolverTests.swift`
  (agent A: hand levels with known minima, including one where σ forces a detour; the plan wins and no arrangement at a
  smaller depth does; the independent enumeration of research R14 of every action sequence shorter than the plan
  through `BinaryGardensPuzzle` moves, with no visited set and no loss order, reproducing `arrangementsByDepth` on
  seeded levels; the loss order changes only the work, never the depth; the work bound respected; refused moves never
  followed; the plan is its parent chain and replays through the play; `BinaryGardensControl` values, actions and settings in
  the fixed order; `BinaryGardensDifficulty(level:plan:)` on a hand level: narrowestBand, tightestWindow, adjustable,
  moveSpace, arrangementsSearched = Σ arrangementsByDepth, work, nearestMiss and `puzzleDifficulty`); `--name host-2`

## Phase 4: Story 2 — levels come from their planned seeds (P1)

**Independent test**: building the catalog twice gives identical levels and the pinned digest.

- [ ] T-R02G2102-004 [US2] Generator tests against the measured profiles: confirm the R4 values recorded by
  T-R02G2102-003 are the ones in `BinaryGardensGenerator.swift` and in spec Q1, research.md R4, data-model.md and plan.md's Technical Context
  ("arithmetic values of spec Q1, confirmed or changed (and written back) by the measurement of research R4"); create
  `Packages/ExperiencesRound02/BinaryGardens/CoreTests/BinaryGardensGeneratorTests.swift` (agent C: determinism, the
  drawing order of clarification Q1 and research R15, band values and kernel ranges of every candidate, "luminosity
  levels drawn distinct in 4 … 32, clamp radius 2 … 4, world radius largest ring + 3 … min(60, largest + 20), world phase
  0 … 47, world speed ±1 … ±3", the winning phases on the band's grid, the bounds of `bounds(flux:trim:comfort:lethal:bloom:slack:)`
  containing the winning run (no lethal tick, window and bloom kept), the λ_hi guard tested as a bound (≤ 166 400),
  `isReducible`, the filters, the neighbour rule, the candidate bound and its `generation(n)` refusal); `--name host-3`

## Phase 5: Stories 3 and 4 — difficulty and honest witness files (P2)

**Independent test**: band means of the witness length do not fall; the 100 witness files match byte for byte and an
edited file is refused.

- [ ] T-R02G2102-005 [P] [US4] Create `Packages/ExperiencesRound02/BinaryGardens/Core/BinaryGardensWitness.swift`
  (agent B: schema 1 sorted-key, pretty-printed JSON with one trailing newline; state digests "16 hex characters of the
  SHA-256 of the arrangement and the actions spent" over `canonicalText` "rings=a,b;phases=a,b;luminosities=a,b;tilt=t;spent=s"
  after each action; play fingerprints "after `begin`, `dismissTutorial` when the level has one, and each action";
  terminal report `BinaryGardensWitnessReport` ("per world integral, meanWhole (= integral / 48), meanRemainder (=
  integral mod 48), longestLethalRun, tolerance, window, windowStart, requiredWindow, bloom (`inside`);
  minimumSeparationSquared, minimumSeparationTick, outcome (`won`)"); counterexample "depth (= size − 1), arrangements
  (judged at that depth, none winning), nearestMiss (loss), arrangement, failure (`BinaryGardensFailure`)"; difficulty;
  skipped; decode refuses newer (`r02-g21.newer-schema`), damaged and non-replaying or edited (`r02-g21.witness`) files
  with the reasons of contracts/api.md) with
  `Packages/ExperiencesRound02/BinaryGardens/CoreTests/BinaryGardensWitnessTests.swift`; `--name host-4`
- [ ] T-R02G2102-006 [US1] [US2] [US3] [US4] Create
  `Packages/ExperiencesRound02/BinaryGardens/CoreTests/BinaryGardensCatalogTests.swift` (lead: 100 entries, 20 per
  band; every level generated, won by its witness within the budget, and no arrangement at a smaller depth wins; the
  independent enumeration on the two levels with the smallest move space in each band (ties by level number);
  neighbours differ in ring radii or worlds; pinned digest `PuzzleCatalog<BinaryGardensPuzzle>.digest(id:
  "binary-gardens", identities: fingerprints)`; `ProgressionRule.standard` on the witness lengths and band means
  non-decreasing (1, 2, 3, 3, 4); `testBinaryGardensContentBoundary` (every level's witness replays to a win within its
  budget and its difficulty work and arrangements equal the solver's run; neighbouring input, seed 2_507: one seeded
  edit per sampled witness — an action value, a digest character or a difficulty count — refused `r02-g21.witness`) and
  `testBinaryGardensNoveltyBoundary` (every witness only ring, phase, luminosity and tilt actions then `run`; putting
  back any one changed control of the winning arrangement makes the run fail; neighbouring input, seed 2_507: dropping
  one seeded action of a sampled witness never wins); witness files byte for byte, written only with
  `BINARY_GARDENS_WRITE_WITNESSES=1 swift test --package-path Packages/ExperiencesRound02 --filter
  BinaryGardensCatalogTests --no-parallel`; generated levels cached per process in a thread-safe `static let`; 20
  groups of 5) and the 100 files `docs/games/binary-gardens/levels/001.witness.json` … `100.witness.json`;
  `--name host-5`

## Phase 6: Regression, documentation and close

- [ ] T-R02G2102-007 Docs: `docs/architecture/binary-gardens.md` (content pipeline: phase step, manifest, generator,
  solver, witness, digest, R4 measurement), `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md` (chunk 2
  time with the catalog; if it nears 540 s, Binary Gardens moves to its own chunk and the doc says so);
  `--name round02-host-1`, `-2`, `-3c`, `-3e`, `-3f`
- [ ] T-R02G2102-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`,
  `--name host-full`
- [ ] T-R02G2102-009 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G2102-010 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G2102-011 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G2102-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record;
  README row and gate list updated

## Dependencies and parallel work

001 → 002 → 003 core and measurement (lead) → {003 tests (agent A), 004 tests (agent C), 005 (agent B)} → 006 →
007 … 012. No test depends on a profile value before the T-R02G2102-003 measurement is recorded. Agents work in
isolated copies against contracts/api.md; shared files (level, sky, puzzle, error, manifest, difficulty, solver,
generator, catalog tests, witness files, docs) stay with the lead. MVP: Story 1. Requirement coverage: FR-001 → 003,
004, 006; FR-002 → 003; FR-003 → 003, 006; FR-004 → 005, 006; FR-005 → 006; FR-006 → 002, 007 … 011; FR-007 → 003,
004, 006; FR-008 → 006; FR-009 → 002; SC-001 … 005 → 003 … 006; SC-006 → 002, 007 … 011; SC-007 → 002, 006.
