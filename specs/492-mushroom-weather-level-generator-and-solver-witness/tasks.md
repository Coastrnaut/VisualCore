# Tasks: R02-G20-02 — Mushroom Weather: level generator and solver witness

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G20-02 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G20-02 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Test seed
2_492; tests stay short (< 10 s each; catalog certification in 20 groups of 5 levels, measured locally, never asserted
on CI). No {owner} or {device} tasks (pure logic); no GLSL.

## Phase 1: Setup

- [X] T-R02G2002-001 Baselines after R02-G20-01 is recorded: `--name baseline-host`, `--name baseline-timing`, `--name — Verified 2026-11-26: 2026-11-26 baseline-host, baseline-timing, baseline-round02-1, -2, -3c, -3e, -3f exit 0 after R02-G20-01 (.autonomy/migration/checks/R02-G20-02.baseline-*.json)
  baseline-round02-1`, `-2`, `-3c`, `-3e`, `-3f` (the round-two filters of feature 491, chunk 3f with
  MushroomWeather); the rendering baseline is R02-G20-01's rendering runs (exit 0)

## Phase 2: Foundational

- [X] T-R02G2002-002 Kernel extension and shared types (lead): in — Verified 2026-11-26: 2026-11-26 host exit 0: 53 tests in 7 suites incl. 8 sites tests (refusals by name, allowsPod, play and puzzle on sites, byte-identical stored form without sites, budgets 13 … 24) (.autonomy/migration/checks/R02-G20-02.host.json)
  `Packages/ExperiencesRound02/MushroomWeather/Core/MushroomWeatherLevel.swift` widen `budgets` to "1 … 24" and add
  optional `sites` ("2 … 8 distinct floor cells without a colony, row-major"; refusals in order after "pods share a
  cell": "sites", "sites duplicate", "site off floor", "site on colony", "pod not on a site"; omitted from the stored
  form when absent, so every level without sites keeps its fingerprint; `allowsPod(_:)`); in
  `Core/MushroomWeatherPlay.swift` refuse a placement the level does not allow with `.action("not a site")` (after off
  floor and colony cell, before occupied cell); in `Core/MushroomWeatherPuzzle.swift` list placements on sites only when
  sites are listed; add `generation(Int)` ("r02-g20.generation") and `witness(String)` ("r02-g20.witness") to
  `Core/MushroomWeatherError.swift`; create `Core/MushroomWeatherManifest.swift` (the 100 entries "number 1 … 100,
  planned seed, band 1 … 5, budget 8 … 19, emphasis" copied from `python3 scripts/planning_index.py levels --experience
  R02-G20`, with provenance) and `Core/MushroomWeatherDifficulty.swift` (actions, colonies, narrowest band, sites,
  vents, arrangements searched, work, nearest miss; `puzzleDifficulty`); move feature 491's two out-of-range budget
  cases in `CoreTests/MushroomWeatherLevelTests.swift` and `CoreTests/MushroomWeatherInvariantTests.swift` from 13 to 25;
  create `CoreTests/MushroomWeatherSitesTests.swift` (sites refused by name, allowed cells, the play's "not a site"
  refusal, the puzzle's placements on sites only, a level without sites encoding byte for byte as before, budgets
  13 … 24 accepted); `--name host`

## Phase 3: Story 1 — every shipped level can be solved (P1) 🎯

**Independent test**: each catalog level's witness, replayed and run, wins within the budget; no arrangement reachable
with fewer actions wins.

- [X] T-R02G2002-003 [US1] Implement `Packages/ExperiencesRound02/MushroomWeather/Core/MushroomWeatherSolver.swift` — Verified 2026-11-26: 2026-11-26 host-2 exit 0: 63 tests in 8 suites incl. 10 solver tests (hand minima, independent BFS counts, loss order, work bound) (.autonomy/migration/checks/R02-G20-02.host-2.json)
  (lead: arrangements by distance "pod count + vents toggled + one for a changed moonlight" from a start with no pod;
  within a depth "by pod count ascending, then vent count ascending, then pod site combinations and vent combinations
  in lexicographic order, then the new moonlight ascending, skipping the start's"; "each depth after 0 ordered by the
  band loss of each arrangement's parent (the moonlight change, else the last vent toggle, else the last pod removed),
  ties keeping the fixed order"; loss "Σ over colonies of max(0, low − h, h − high)
  plus K − min(K, final run), plus M per colony when the run fails dried or mold"; the first winning arrangement ends
  the search; the plan's actions "placements in slot order, then vent toggles, then the moonlight change", then `run`;
  arrangements counted at each smaller depth and the nearest miss; work = arrangements judged, "bounded at 1,500";
  `replayWins` replays the actions and the run through the kernel's play; no plan for a level without sites or with a
  starting pod) with `Packages/ExperiencesRound02/MushroomWeather/CoreTests/MushroomWeatherSolverTests.swift` (agent A:
  hand levels with known minima; the plan wins and no arrangement at a smaller distance does; an independent
  breadth-first search over `MushroomWeatherPuzzle` moves (place, move, remove, vent, moonlight) reproducing the
  per-depth counts on seeded levels; the loss order changes only the work, never the depth; the work bound respected;
  the plan is the first in the search order); `--name host-2`

## Phase 4: Story 2 — levels come from their planned seeds (P1)

**Independent test**: building the catalog twice gives identical levels and the pinned digest.

- [X] T-R02G2002-004 [US2] Create `Packages/ExperiencesRound02/MushroomWeather/Core/MushroomWeatherGenerator.swift` — Verified 2026-11-26: 2026-11-26 host-3 exit 0: 75 tests in 9 suites incl. 12 generator tests (determinism, drawing order, band values, vents and sites near colonies, filters, neighbour rule, candidate bound) (.autonomy/migration/checks/R02-G20-02.host-3.json)
  (lead, from the measured prototype: band profiles "band 1 (6 … 7, 6 … 7, 2 … 5, 1, 2, 2, 4, 2, 4 … 6), 2 (6 … 8,
  6 … 8, 3 … 6, 2, 2, 3, 4, 3, 3 … 5), 3 (7 … 8, 7 … 9, 3 … 7, 2, 3, 3, 5, 3, 2 … 4), 4 (7 … 9, 8 … 10, 4 … 8, 3, 3, 4,
  6, 4, 1 … 3), 5 (8 … 9, 8 … 10, 4 … 8, 3, 4, 5, 6, 5, 1 … 2)" (rows, columns, blocked, vents, slots, colonies, sites,
  plan, margin); candidates from `SeedDerivation.derive(plannedSeed, index: c)` in the drawing order of clarification
  Q1; vents and sites on near cells; bands from the winning run widened by the margin; sensitive floors min(low·3/4, the
  run's minimum); the skip rules of clarification Q1 including "reducible" and the neighbour rule (floor and colonies
  equal to the previous level's); at most 64 candidates then `generation(n)`; level ids `mushroom-weather-NNN`; no
  starting pod; tutorial on 1 … 3; difficulty = band; `catalog()` in manifest order; catalog digest) with
  `Packages/ExperiencesRound02/MushroomWeather/CoreTests/MushroomWeatherGeneratorTests.swift` (agent C: determinism,
  drawing order, band values and kernel ranges of every candidate, vents and sites near colonies, bands containing the
  winning run's last K cycles, the filters, the neighbour rule, the candidate bound and its refusal); `--name host-3`

## Phase 5: Stories 3 and 4 — difficulty and honest witness files (P2)

**Independent test**: band means of the witness length do not fall; the 100 witness files match byte for byte and an
edited file is refused.

- [X] T-R02G2002-005 [P] [US4] Create `Packages/ExperiencesRound02/MushroomWeather/Core/MushroomWeatherWitness.swift` — Verified 2026-11-26: 2026-11-26 host-4 exit 0: 83 tests in 10 suites incl. 8 witness tests (byte round trip, digests, independent replay, damaged and edited files refused by reason) (.autonomy/migration/checks/R02-G20-02.host-4.json)
  (agent B: schema 1 sorted-key JSON; state digests "16 hex characters of the SHA-256 of the arrangement and the actions
  spent" after each action; play fingerprints after begin (and dismissTutorial) and each action; terminal report
  (ledger totals: start, released, evaporated, end; each colony's final run, longest run and first cycle out of band;
  cycles run); counterexample (the depth one below, the count of arrangements at it, the nearest miss); difficulty;
  skipped; decode refuses newer, damaged and non-replaying files) with
  `Packages/ExperiencesRound02/MushroomWeather/CoreTests/MushroomWeatherWitnessTests.swift`; `--name host-4`
- [X] T-R02G2002-006 [US2] [US3] [US4] Create — Verified 2026-11-26: 2026-11-26 host-5 exit 0: 91 tests in 11 suites incl. catalog suite (pinned digest a71fe37a…, 100 witnesses win, independent enumeration on 10 levels, 20 byte-for-byte groups); 100 witness files (.autonomy/migration/checks/R02-G20-02.host-5.json)
  `Packages/ExperiencesRound02/MushroomWeather/CoreTests/MushroomWeatherCatalogTests.swift` (lead: 100 entries, 20 per
  band; every level generated, won by its witness within the budget, and no arrangement at a smaller distance wins; the
  independent breadth-first search on the two levels with the fewest sites, then fewest colonies, in each band (ties by
  level number); neighbours differ; pinned digest; progression rule and band means; witness files byte for byte,
  written only with `MUSHROOM_WEATHER_WRITE_WITNESSES=1`; 20 groups of 5) and the 100 files
  `docs/games/mushroom-weather/levels/001.witness.json` … `100.witness.json`; `--name host-5`

## Phase 6: Regression, documentation and close

- [X] T-R02G2002-007 Docs: `docs/architecture/mushroom-weather.md` (content pipeline), — Verified 2026-11-26: 2026-11-26 docs (architecture content pipeline, package README, automatedtesting) and round02-host-1, -2, -3c, -3e, -3f exit 0 (.autonomy/migration/checks/R02-G20-02.round02-host-*.json)
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host-1`, `-2`, `-3c`, `-3e`,
  `-3f`
- [X] T-R02G2002-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`, — Verified 2026-11-26: 2026-11-26 rendering-27, rendering-26, experiences, host-full exit 0 (.autonomy/migration/checks/R02-G20-02.{rendering-27,rendering-26,experiences,host-full}.json)
  `--name host-full`
- [ ] T-R02G2002-009 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G2002-010 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G2002-011 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G2002-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record;
  README row and gate list updated

## Dependencies and parallel work

001 → 002 → 003 core and 004 core (lead) → {003 tests (agent A), 004 tests (agent C), 005 (agent B)} → 006 → 007 … 012.
Agents work in isolated copies against contracts/api.md; shared files (level, play, puzzle, error, manifest, solver,
difficulty, generator, catalog tests, witness files, docs) stay with the lead. MVP: Story 1. Requirement coverage:
FR-001 → 002, 004, 006; FR-002 → 003; FR-003 → 002, 006; FR-004 → 005, 006; FR-005 → 006; FR-006 → 002, 007 … 011;
FR-007 → 004, 006; SC-001 … 005 → 003 … 006; SC-006 → 002, 007 … 011.
