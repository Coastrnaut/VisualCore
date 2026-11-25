# Tasks: R02-G17-02 — Celestial Eclipse Lab: level generator and solver witness

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G17-02 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G17-02 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Test seed
2_462; tests stay short (< 10 s each; catalog certification in groups of 10 levels, measured locally, never asserted on
CI). No {owner} or {device} tasks (pure logic); no GLSL.

## Phase 1: Setup

- [X] T-R02G1702-001 Baselines after R02-G17-01 is recorded: `--name baseline-host`, `--name baseline-timing`, `--name — Verified 2026-11-25: 2026-11-25 baseline-host and round02-1, -2, -3c, -3e, -3f exit 0; baseline-timing printed bounds above its asserts (process tree at background priority PRI 4, VisualCore unchanged), host scheduling, not code; rendering baseline is R02-G17-01's rendering runs (exit 0)
  baseline-round02-1`, `-2`, `-3c`, `-3e`, `-3f` (the round-two filters of feature 461, chunk 3c with
  CelestialEclipseLab); the rendering baseline is R02-G17-01's rendering runs (exit 0)

## Phase 2: Foundational

- [X] T-R02G1702-002 Add `generation(Int)` ("r02-g17.generation") and `witness(String)` ("r02-g17.witness") to — Verified 2026-11-25: 2026-11-25 generation and witness refusals, the 100-entry manifest and the difficulty; all 83 CelestialEclipseLab tests pass (host exit 0); feature 461's 200-walk rules test split into four quarters of 50 walks (it took 12 s alone on this host)
  `Packages/ExperiencesRound02/CelestialEclipseLab/Core/CelestialEclipseLabError.swift`; create
  `Packages/ExperiencesRound02/CelestialEclipseLab/Core/CelestialEclipseLabManifest.swift` (the 100 entries "number 1 …
  100, planned seed, band 1 … 5, budget 8 … 19, emphasis" copied from `python3 scripts/planning_index.py levels
  --experience R02-G17`, with provenance) and
  `Packages/ExperiencesRound02/CelestialEclipseLab/Core/CelestialEclipseLabDifficulty.swift` (changes, bodies, movable,
  targets, events, settings searched, work; `puzzleDifficulty`); `--name host`

## Phase 3: Story 1 — every shipped level can be solved (P1) 🎯

**Independent test**: each catalog level's witness, replayed and run, wins within the budget; no setting with fewer
phase changes wins.

- [X] T-R02G1702-003 [US1] Implement — Verified 2026-11-25: 2026-11-25 CelestialEclipseLabSolver (pair-interval table, phase search by depth, counted proof) and CelestialEclipseLabSolverTests pass, 7 tests (host-2 exit 0)
  `Packages/ExperiencesRound02/CelestialEclipseLab/Core/CelestialEclipseLabSolver.swift` (lead: the pair-interval table
  "for every pair and every pair of phases, the pair's eclipse intervals over the horizon by the kernel's exact overlap
  and visibility rules", a setting's intervals merged "in timeline order (first tick, front, back)" and walked by the
  kernel's judge; depths 1 … maxChanges 5; at each depth "the subsets of d movable bodies in lexicographic order of body
  numbers, and within a subset the new phases in lexicographic order (each 0 … period − 1 except the starting phase)";
  the first winning setting ends the search and its phase changes in body order are the plan; settings counted at each
  smaller depth; work = settings judged, "bounded at 60 000"; `wins` replays the actions and the run through the
  kernel's play) with `Packages/ExperiencesRound02/CelestialEclipseLab/CoreTests/CelestialEclipseLabSolverTests.swift`
  (agent A: hand levels with known minima (one change, two changes, a fixed body that cannot be changed); the plan wins
  and no setting with fewer changes does; the table agrees with the kernel's whole-sky timeline on seeded settings; the
  independent enumeration of every setting with fewer changes through the kernel's timeline on seeded levels; the work
  bound respected; the plan is the first in the fixed order); `--name host-2`

## Phase 4: Story 2 — levels come from their planned seeds (P1)

**Independent test**: building the catalog twice gives identical levels and the pinned digest.

- [X] T-R02G1702-004 [US2] Create — Verified 2026-11-25: 2026-11-25 CelestialEclipseLabGenerator (band profiles, integer orbit table, candidates, neighbour rule, catalog, digest) and its 12 generator tests pass (host-3 exit 0)
  `Packages/ExperiencesRound02/CelestialEclipseLab/Core/CelestialEclipseLabGenerator.swift` (lead: band profiles "band 1
  (3, 1 … 2, 24 … 32, 2, 1 … 2), 2 (3 … 4, 2 … 3, 28 … 36, 3, 2 … 3), 3 (4 … 5, 2 … 3, 32 … 40, 4, 3 … 4), 4 (5 … 6, 3 …
  4, 36 … 44, 4, 3 … 4), 5 (6, 3 … 4, 40 … 48, 5, 4 … 5)" (bodies, targets, horizon, moved, plan range); the integer
  orbit table "round(1000·cos), round(1000·sin)" for periods 4 … 8, scaled "rounded half away from zero"; candidates
  from `SeedDerivation.derive(plannedSeed, index: c)` in the drawing order of clarification Q1; the neighbour rule (a
  target sequence of (front, back) pairs equal to the previous level's is skipped); at most 256 candidates then
  `generation(n)`; level ids `celestial-eclipse-lab-NNN`; tutorial on 1 … 3; difficulty = band; `catalog()` in manifest
  order; catalog digest) with
  `Packages/ExperiencesRound02/CelestialEclipseLab/CoreTests/CelestialEclipseLabGeneratorTests.swift` (agent C:
  determinism, drawing order, band values, depth order and kernel ranges of every candidate, the target being the
  winning timeline's first events with windows of 0 … 2 ticks, the moved bodies, the filters, the neighbour rule, the
  candidate bound and its refusal); `--name host-3`

## Phase 5: Stories 3 and 4 — difficulty and honest witness files (P2)

**Independent test**: band means of the witness length do not fall; the 100 witness files match byte for byte and an
edited file is refused.

- [X] T-R02G1702-005 [P] [US4] Create — Verified 2026-11-25: 2026-11-25 CelestialEclipseLabWitness and its 16 tests pass (host-4 exit 0)
  `Packages/ExperiencesRound02/CelestialEclipseLab/Core/CelestialEclipseLabWitness.swift` (agent B: schema 1 sorted-key
  JSON; state digests "16 hex characters of the SHA-256 of the phases and the actions spent" after each action; play
  fingerprints after begin (and dismissTutorial) and each action; terminal timeline (front, back, first, last,
  visibility; matched); counterexample (the depth one below and the count of settings at it); difficulty; skipped;
  decode refuses newer, damaged and non-replaying files) with
  `Packages/ExperiencesRound02/CelestialEclipseLab/CoreTests/CelestialEclipseLabWitnessTests.swift`; `--name host-4`
- [X] T-R02G1702-006 [US2] [US3] [US4] Create — Verified 2026-11-25: 2026-11-25 catalog tests pass, 8 tests (host-5 exit 0): 100 witness files byte for byte, pinned digest c74bf277…, progression and band means, neighbours differ, whole-sky enumeration on two levels per band
  `Packages/ExperiencesRound02/CelestialEclipseLab/CoreTests/CelestialEclipseLabCatalogTests.swift` (lead: 100 entries,
  20 per band; every level generated, won by its witness within the budget, and no setting with fewer changes wins; the
  whole-sky enumeration on the two levels with the fewest bodies in each band; neighbours differ; pinned digest;
  progression rule and band means; witness files byte for byte, written only with
  `CELESTIAL_ECLIPSE_LAB_WRITE_WITNESSES=1`; groups of 10) and the 100 files
  `docs/games/celestial-eclipse-lab/levels/001.witness.json` … `100.witness.json`; `--name host-5`

## Phase 6: Regression, documentation and close

- [X] T-R02G1702-007 Docs: `docs/architecture/celestial-eclipse-lab.md` (content pipeline), — Verified 2026-11-25: 2026-11-25 architecture content-pipeline section, round-two README and automatedtesting entry written; round02-host-1, -2, -3c, -3e, -3f exit 0
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host-1`, `-2`, `-3c`,
  `-3e`, `-3f`
- [X] T-R02G1702-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`, — Verified 2026-11-25: 2026-11-25 rendering-27, rendering-26, experiences, host-full exit 0 (app-unit too)
  `--name host-full`
- [X] T-R02G1702-009 Reference regression chunk 1 (`--name reference-1`) — Verified 2026-11-25: 2026-11-25 reference-1 exit 0
- [ ] T-R02G1702-010 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G1702-011 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G1702-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record;
  README row and gate list updated

## Dependencies and parallel work

001 → 002 → 003 core and 004 core (lead) → {003 tests (agent A), 004 tests (agent C), 005 (agent B)} → 006 → 007 … 012.
Agents work in isolated copies against contracts/api.md; shared files (error, manifest, solver, difficulty, generator,
catalog tests, witness files, docs) stay with the lead. MVP: Story 1. Requirement coverage: FR-001 → 004, 006; FR-002 →
003, 006; FR-003 → 002, 004; FR-004 → 005, 006; FR-005 → 006; FR-006 → 002, 007 … 011; FR-007 → 004, 006.
