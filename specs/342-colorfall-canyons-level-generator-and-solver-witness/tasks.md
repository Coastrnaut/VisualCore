# Tasks: R02-G05-02 — Colorfall Canyons: level generator and solver witness

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G05-02 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G05-02 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). No {owner}
or {device} tasks (pure logic and host-generated content); no GLSL (the CPU flow step of R02-G05-01 is the reference every
run uses). Fixture seed 2_342; tests stay short (< 10 s each).

## Phase 1: Setup

- [X] T-R02G0502-001 Baselines: `--name baseline-host`, `--name baseline-timing`, `--name baseline-round02 -- swift test — Verified 2026-11-21: 2026-11-21 R02-G05-02.baseline-host/timing/round02 exit 0
  --package-path Packages/ExperiencesRound02`; the rendering baseline is R02-G05-01's rendering runs (exit 0)

## Phase 2: Foundational

- [X] T-R02G0502-002 Add `generation(Int)` ("r02-g05.generation") and `witness(String)` ("r02-g05.witness") to — Verified 2026-11-21: 2026-11-21 host exit 0 (whole round-two package: error cases generation and witness, the 100-entry manifest from the planning index, ColorfallCanyonsDifficulty; existing tests unchanged)
  `Packages/ExperiencesRound02/ColorfallCanyons/Core/ColorfallCanyonsError.swift`; create `Packages/ExperiencesRound02/ColorfallCanyons/Core/ColorfallCanyonsManifest.swift` (ColorfallCanyonsManifestEntry
  "number 1 … 100, seed UInt64, band 1 … 5, budget 8 … 19", the 100 entries copied from `python3 scripts/planning_index.py
  levels --experience R02-G05` with the source line) and `Packages/ExperiencesRound02/ColorfallCanyons/Core/ColorfallCanyonsDifficulty.swift` ("smallest, work, win
  tick, springs, basins, protected basins, carvable cells"); `--name host -- swift test --package-path
  Packages/ExperiencesRound02` (existing tests unchanged)

## Phase 3: Story 1 — every shipped level can be solved (P1) 🎯

- [X] T-R02G0502-003 [US1] Implement `Packages/ExperiencesRound02/ColorfallCanyons/Core/ColorfallCanyonsSolver.swift` (clarification Q2: ColorfallCanyonsEdit carve — Verified 2026-11-21: 2026-11-21 host-2 exit 0 (solver by the lead: edit sets 0 … 3, routing keys with an incremental Zobrist hash compared in full, reachability pruning, an allocation-free kernel copy with an exact settled stop, the result re-run through the kernel; 13 tests by agent A retested by the lead: hand-built levels needing 0 … 3 edits and nil beyond, an independent brute force with no pruning or cache on catalog levels of every band, candidates and fixtures, fast flow and router equal to the kernel on over 1,000 edit sets, every smaller set loses, pruning soundness, determinism)
  and valve, moves = carvable cells in order then springs; edit sets of size 0 … 3 as non-decreasing move lists, each valve
  at most once, sets carving below 0 skipped; key = routing and valves, each key simulated once with conservation asserted
  every tick; first winning set is the smallest; work = distinct keys simulated; smaller = keys of fewer edits simulated;
  win tick; `run(_:edits:)`) and, after it, agent A's `Packages/ExperiencesRound02/ColorfallCanyons/CoreTests/ColorfallCanyonsSolverTests.swift` (seed 2_342:
  hand-built levels needing 0, 1, 2 and 3 edits; a level needing more than the depth gives nil; the smallest count equals
  an independent brute force over every edit set (no routing cache) on seeded generated levels; every set smaller than the
  smallest fails; work bound; determinism); `--name host-2`

## Phase 4: Story 2 — levels come from their planned seeds (P1)

- [ ] T-R02G0502-004 [US2] Create `Packages/ExperiencesRound02/ColorfallCanyons/Core/ColorfallCanyonsGenerator.swift` (ColorfallCanyonsBandProfile "grid 6 × 5, 6 × 5,
  7 × 5, 8 × 6, 8 × 6; springs 1, 2, 2, 3, 3; depressions 3, 4, 5, 8, 8; smallest 1 … 2, 2 … 3, 3, 3, 3",
  `candidate(_:index:)` drawing in the order of clarification Q1 from `SeededRandom(seed: SeedDerivation.derive(seed,
  index: k))` with the planted plan and basins, ColorfallCanyonsGenerated, `generate` with k = 0 … 511, id
  `colorfall-canyons-NNN`, budget = manifest budget, tutorial for 1 … 3, difficulty = band, `.generation(number)` beyond 512;
  `catalogDigest`) and, after it, agent C's `Packages/ExperiencesRound02/ColorfallCanyons/CoreTests/ColorfallCanyonsGeneratorTests.swift` (determinism; band
  ranges; budget; planted plan wins; unedited fails; skipped recorded and re-checked; an impossible profile refused);
  `--name host-3`

## Phase 5: Stories 3 and 4 — difficulty and honest witness files (P2)

- [ ] T-R02G0502-005 [P] [US4] Create `Packages/ExperiencesRound02/ColorfallCanyons/Core/ColorfallCanyonsWitness.swift` (schema 1; actions: the smallest edits as carve
  and valve actions, then step(tick limit); built by replaying them on a `ColorfallCanyonsPlay`: win tick, the 16-hex
  fluid digest after every tick up to the win, released, held and spilled totals per colour, fingerprints after begin and
  each action; unedited and near-miss counterexamples (reason, tick); smaller; difficulty; skipped; sorted-key pretty JSON
  with a trailing newline; `decode` refuses newer, damaged and non-replaying witnesses) with
  `Packages/ExperiencesRound02/ColorfallCanyons/CoreTests/ColorfallCanyonsWitnessTests.swift` (round trip byte for byte; edited actions, digests, totals,
  fingerprints, level, counterexamples and difficulty refused; newer schema and damaged JSON refused; the counterexamples
  fail as recorded) by agent B; `--name host-4`
- [ ] T-R02G0502-006 [US2] [US3] [US4] Create `Packages/ExperiencesRound02/ColorfallCanyons/CoreTests/ColorfallCanyonsCatalogTests.swift` (100 entries, 20 per band;
  the catalog generated twice is identical; pinned digest; `ProgressionRule.standard` holds on the smallest count; band
  means never fall; on levels 1, 11, 21, … 91 the smallest count equals the brute force (SC-R02G0502-002); all 100
  witnesses replay to a win with zero drift; each witness equals `docs/games/colorfall-canyons/levels/NNN.witness.json`
  byte for byte, one test per band or half band, written only with `COLORFALL_CANYONS_WRITE_WITNESSES=1`) and generate the
  100 files; `--name host-5`

## Phase 6: Regression, documentation and close

- [ ] T-R02G0502-007 Docs: `docs/architecture/colorfall-canyons.md` (content pipeline), `Packages/ExperiencesRound02/README.md`,
  `docs/automatedtesting.md`; `--name round02-host`
- [ ] T-R02G0502-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`,
  `--name host-full`
- [ ] T-R02G0502-009 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G0502-010 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G0502-011 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G0502-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record

## Dependencies and parallel work

001 → 002 (lead) → 003 solver (lead) → {003 tests (agent A), 004 generator (lead) → 004 tests (agent C), 005 (agent B)} →
006 (lead) → 007 … 012. Agent B codes against the solution contract with hand-made solutions; shared files (error,
manifest, difficulty, solver, generator, catalog tests, witness files, docs) stay with the lead. MVP: Story 1.
