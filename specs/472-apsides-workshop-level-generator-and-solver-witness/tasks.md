# Tasks: R02-G18-02 — Apsides Workshop: level generator and solver witness

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G18-02 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G18-02 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Test seed
2_472; tests stay short (< 10 s each; catalog certification in groups of 10 levels, measured locally, never asserted on
CI). No {owner} or {device} tasks (pure logic); no GLSL.

## Phase 1: Setup

- [X] T-R02G1802-001 Baselines after R02-G18-01 is recorded: `--name baseline-host`, `--name baseline-timing`, `--name — Verified 2026-11-25: 2026-11-25 baseline-host, baseline-timing and round02-1, -2, -3c, -3e, -3f (with ApsidesWorkshop) exit 0 on the committed R02-G18-01 record; rendering baseline is R02-G18-01's rendering runs (exit 0)
  baseline-round02-1`, `-2`, `-3c`, `-3e`, `-3f` (the round-two filters of feature 471, chunk 3f with ApsidesWorkshop);
  the rendering baseline is R02-G18-01's rendering runs (exit 0)

## Phase 2: Foundational

- [X] T-R02G1802-002 Add `generation(Int)` ("r02-g18.generation") and `witness(String)` ("r02-g18.witness") to — Verified 2026-11-25: 2026-11-25 generation and witness refusals, the 100-entry manifest and the difficulty; all 87 ApsidesWorkshop tests pass (host exit 0)
  `Packages/ExperiencesRound02/ApsidesWorkshop/Core/ApsidesWorkshopError.swift`; create
  `Packages/ExperiencesRound02/ApsidesWorkshop/Core/ApsidesWorkshopManifest.swift` (the 100 entries "number 1 … 100,
  planned seed, band 1 … 5, budget 8 … 19, emphasis" copied from `python3 scripts/planning_index.py levels --experience
  R02-G18`, with provenance) and `Packages/ExperiencesRound02/ApsidesWorkshop/Core/ApsidesWorkshopDifficulty.swift`
  (tunings, targets, apsis targets, planets, narrowest share band, narrowest distance range "0 for a band or range the
  level does not have", orbits searched, work; `puzzleDifficulty`); `--name host`

## Phase 3: Story 1 — every shipped level can be solved (P1) 🎯

**Independent test**: each catalog level's witness, replayed and played, wins within the budget; no orbit reachable with
fewer tunings wins.

- [X] T-R02G1802-003 [US1] Implement `Packages/ExperiencesRound02/ApsidesWorkshop/Core/ApsidesWorkshopSolver.swift` — Verified 2026-11-25: 2026-11-25 ApsidesWorkshopSolver and ApsidesWorkshopSolverTests pass (host-2 exit 0): hand minima incl. knob-first order, orbit lists equal an independent enumeration (423 and 13 880 at most), apsis shortcut agrees with the full report
  (lead: depth 1 "every valid knob setting (eccentricity 0 … 15, then direction 0 … 23, the start's pair excluded) at
  the start's size, then every valid size 8 … 48 (the start's excluded) at the start's knob"; depth 2 "every valid orbit
  with both a different size and a different knob, size outermost, then eccentricity, then direction"; each orbit judged
  by the kernel's report "the apsis targets checked first from the orbit's steps alone"; the first winning orbit ends
  the search; the plan's tunings "size first when the winning eccentricity is not lower than the start's, the knob first
  otherwise", then `play`; orbits counted at each smaller depth; work = orbits judged, "bounded at 16 000"; `wins`
  replays the actions and the play through the kernel's play) with
  `Packages/ExperiencesRound02/ApsidesWorkshop/CoreTests/ApsidesWorkshopSolverTests.swift` (agent A: hand levels with
  known minima (one knob tuning, one size tuning, both); the plan wins and no orbit with fewer levers changed does; the
  apsis pruning agrees with the full report on seeded orbits; the independent enumeration of every orbit with fewer
  tunings through the kernel's full report on seeded levels; every two-tuning plan passes only valid orbits; the work
  bound respected; the plan is the first in the fixed order); `--name host-2`

## Phase 4: Story 2 — levels come from their planned seeds (P1)

**Independent test**: building the catalog twice gives identical levels and the pinned digest.

- [X] T-R02G1802-004 [US2] Create `Packages/ExperiencesRound02/ApsidesWorkshop/Core/ApsidesWorkshopGenerator.swift` — Verified 2026-11-25: 2026-11-25 ApsidesWorkshopGenerator and ApsidesWorkshopGeneratorTests pass (host-3 exit 0); the real catalog certifies all 100 entries within candidate index 8, at most 13 900 orbits judged
  (lead: band profiles "band 1 ({24}, 1 … 2, 0, 60 … 90, 40 … 60, 0, 1, 1), 2 ({24, 32}, 2, 0 … 1, 45 … 70, 40 … 60,
  0 … 1, 1, 1), 3 ({32}, 2 … 3, 1, 35 … 55, 25 … 45, 1, 1 … 2, 1 … 2), 4 ({32, 48}, 3, 1, 25 … 40, 20 … 35, 1 … 2, 2,
  2), 5 ({48}, 3 … 4, 1 … 2, 18 … 30, 15 … 25, 2 … 3, 2, 2)" (periods, targets, apsis targets, sweep half-width, apsis
  half-width, planets, levers, plan range); candidates from `SeedDerivation.derive(plannedSeed, index: c)` in the
  drawing order of clarification Q1; the planet placement "a tick, a radius 1 … 3, a gap of radius + 1 … 4 lattice units
  and a side … at most 60 tries"; the neighbour rule (targets equal to the previous level's are skipped); at most 256
  candidates then `generation(n)`; level ids `apsides-workshop-NNN`; tutorial on 1 … 3; difficulty = band; `catalog()`
  in manifest order; catalog digest) with
  `Packages/ExperiencesRound02/ApsidesWorkshop/CoreTests/ApsidesWorkshopGeneratorTests.swift` (agent C: determinism,
  drawing order, band values and kernel ranges of every candidate, targets from the winning orbit's shares and apsides
  with their bands, the order by event tick, planets clear of the winning orbit and the star, the levers moved, the
  filters, the neighbour rule, the candidate bound and its refusal); `--name host-3`

## Phase 5: Stories 3 and 4 — difficulty and honest witness files (P2)

**Independent test**: band means of the witness length do not fall; the 100 witness files match byte for byte and an
edited file is refused.

- [ ] T-R02G1802-005 [P] [US4] Create `Packages/ExperiencesRound02/ApsidesWorkshop/Core/ApsidesWorkshopWitness.swift`
  (agent B: schema 1 sorted-key JSON; state digests "16 hex characters of the SHA-256 of the orbit and the actions
  spent" after each action; play fingerprints after begin (and dismissTutorial) and each action; terminal report (the
  eight shares, periapsis and apoapsis sector and distance, largest Kepler residual, deviations, met); counterexample
  (the depth one below and the count of orbits at it); difficulty; skipped; decode refuses newer, damaged and
  non-replaying files) with `Packages/ExperiencesRound02/ApsidesWorkshop/CoreTests/ApsidesWorkshopWitnessTests.swift`;
  `--name host-4`
- [ ] T-R02G1802-006 [US2] [US3] [US4] Create
  `Packages/ExperiencesRound02/ApsidesWorkshop/CoreTests/ApsidesWorkshopCatalogTests.swift` (lead: 100 entries, 20 per
  band; every level generated, won by its witness within the budget, and no orbit with fewer tunings wins; the full
  report enumeration on the two levels with the fewest planets in each band (ties by level number); neighbours differ;
  pinned digest; progression rule and band means; witness files byte for byte, written only with
  `APSIDES_WORKSHOP_WRITE_WITNESSES=1`; groups of 10) and the 100 files
  `docs/games/apsides-workshop/levels/001.witness.json` … `100.witness.json`; `--name host-5`

## Phase 6: Regression, documentation and close

- [ ] T-R02G1802-007 Docs: `docs/architecture/apsides-workshop.md` (content pipeline),
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host-1`, `-2`, `-3c`, `-3e`,
  `-3f`
- [ ] T-R02G1802-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`,
  `--name host-full`
- [ ] T-R02G1802-009 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G1802-010 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G1802-011 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G1802-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record;
  README row and gate list updated

## Dependencies and parallel work

001 → 002 → 003 core and 004 core (lead) → {003 tests (agent A), 004 tests (agent C), 005 (agent B)} → 006 → 007 … 012.
Agents work in isolated copies against contracts/api.md; shared files (error, manifest, solver, difficulty, generator,
catalog tests, witness files, docs) stay with the lead. MVP: Story 1. Requirement coverage: FR-001 → 004, 006; FR-002 →
003; FR-003 → 002, 006; FR-004 → 005, 006; FR-005 → 006; FR-006 → 002, 007 … 011; FR-007 → 004, 006; SC-001 … 005 →
003 … 006; SC-006 → 007 … 011.
