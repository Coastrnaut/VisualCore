# Tasks: R02-G03-02 — Wave Knot Keeper: level generator and solver witness

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G03-02 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G03-02 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). No {owner}
or {device} tasks (pure logic and host-generated content). Fixture seed 2_322; tests stay short (< 10 s each).

## Phase 1: Setup

- [X] T-R02G0302-001 Baselines: `--name baseline-host`, `--name baseline-timing`, `--name baseline-round02 -- swift test — Verified 2026-11-21: 2026-11-21 R02-G03-02.baseline-host/timing/round02 exit 0
  --package-path Packages/ExperiencesRound02`; the rendering baseline is R02-G02-10's rendering runs (exit 0)

## Phase 2: Foundational

- [X] T-R02G0302-002 Add `generation(Int)` ("r02-g03.generation") and `witness(String)` ("r02-g03.witness") to — Verified 2026-11-21: 2026-11-21 host exit 0 (whole round-two package with the error cases, manifest of 100 entries, difficulty and the solver's types and search)
  `Packages/ExperiencesRound02/WaveKnotKeeper/Core/WaveKnotKeeperError.swift`; create `Packages/ExperiencesRound02/WaveKnotKeeper/Core/WaveKnotKeeperManifest.swift` (WaveKnotKeeperManifestEntry
  "number 1 … 100, seed UInt64, band 1 … 5, budget 8 … 19", the 100 entries copied from `python3 scripts/planning_index.py
  levels --experience R02-G03` with the source line), `Packages/ExperiencesRound02/WaveKnotKeeper/Core/WaveKnotKeeperDifficulty.swift` ("shortest, points, gates,
  crossings, work") and the `WaveKnotKeeperSolution` and `WaveKnotKeeperCrossingExample` types in
  `Packages/ExperiencesRound02/WaveKnotKeeper/Core/WaveKnotKeeperSolver.swift` as the contract states (solver body by agent A); `--name host -- swift test
  --package-path Packages/ExperiencesRound02` (existing tests unchanged)

## Phase 3: Story 1 — every shipped level can be solved (P1) 🎯

- [ ] T-R02G0302-003 [P] [US1] Implement `WaveKnotKeeperSolver.solve` in `Packages/ExperiencesRound02/WaveKnotKeeper/Core/WaveKnotKeeperSolver.swift`
  (clarification Q2: breadth-first search over `WaveKnotKeeperRules.moves`/`apply` to depth ≤ 3, visited ropes by points,
  ties by the rules' move order, work = ropes expanded, the first explored rope with a move refused as
  `r02-g03.move("crossing")` recorded as the crossing counterexample) with `Packages/ExperiencesRound02/WaveKnotKeeper/CoreTests/WaveKnotKeeperSolverTests.swift`
  (seed 2_322: hand-built levels with known shortest 1, 2 and 3; a start not solvable within the depth gives nil; the
  shortest equals an independent plain breadth-first search over `PuzzleRules` on seeded levels; the moves replay through
  legal ropes to a win; the crossing counterexample is refused by the rules with `move("crossing")`; the work never
  exceeds 3,661; determinism); `--name host-2`

## Phase 4: Story 2 — levels come from their planned seeds (P1)

- [ ] T-R02G0302-004 [US2] Create `Packages/ExperiencesRound02/WaveKnotKeeper/Core/WaveKnotKeeperGenerator.swift` (WaveKnotKeeperBandProfile "points 6, 7, 8, 9,
  10; gates 0, 0, 1, 1, 2 of side 3; scramble 1, 2, 2, 3, 4; shortest 1, 1–2, 1–2, 2, 2–3" (spec amendment), the solved rope, gates,
  scramble walk and tension bound of clarification Q1, WaveKnotKeeperGenerated, `generate` with candidates k = 0 … 63
  from `SeedDerivation.derive(seed, index: k)`, id `wave-knot-keeper-NNN`, allowance = budget, tutorial for 1 … 3,
  `.generation(number)` beyond 64, a candidate without both counterexamples skipped; `catalogDigest`) with
  `Packages/ExperiencesRound02/WaveKnotKeeper/CoreTests/WaveKnotKeeperGeneratorTests.swift` (determinism; band ranges; budget; skipped recorded; the start does not
  win; the tension bound covers the walk); `--name host-3`

## Phase 5: Stories 3 and 4 — difficulty and honest witness files (P2)

- [ ] T-R02G0302-005 [P] [US4] Create `Packages/ExperiencesRound02/WaveKnotKeeper/Core/WaveKnotKeeperWitness.swift` (schema 1; built by replaying the solution
  on a `WaveKnotKeeperPlay`: fingerprints after begin and each move; terminal summary; near miss and crossing
  counterexample per clarification Q4; sorted-key pretty JSON with a trailing newline; `decode` refuses newer, damaged and
  non-replaying witnesses) with `Packages/ExperiencesRound02/WaveKnotKeeper/CoreTests/WaveKnotKeeperWitnessTests.swift` (round trip byte for byte; edited move,
  fingerprint, level, terminal, counterexamples and difficulty refused; newer schema and damaged JSON refused; the near
  miss does not win; the crossing counterexample is refused by the rules); `--name host-4`
- [ ] T-R02G0302-006 [US2] [US3] [US4] Create `Packages/ExperiencesRound02/WaveKnotKeeper/CoreTests/WaveKnotKeeperCatalogTests.swift` (100 entries, 20 per band;
  the catalog generated twice is identical; pinned digest; `ProgressionRule.standard` holds on shortest; band means of
  shortest and point count never fall; on levels 1, 11, 21, … 91 the shortest equals a plain breadth-first search over
  `PuzzleRules` (SC-R02G0302-002); each witness equals `docs/games/wave-knot-keeper/levels/NNN.witness.json` byte for
  byte, one test per band, written only with `WAVE_KNOT_KEEPER_WRITE_WITNESSES=1`) and generate the 100 files;
  `--name host-5`

## Phase 6: Regression, documentation and close

- [ ] T-R02G0302-007 Docs: `docs/architecture/wave-knot-keeper.md` (generator, solver, witness),
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md` (witness regeneration); `--name round02-host`
- [ ] T-R02G0302-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`,
  `--name host-full` and `--name app-unit`
- [ ] T-R02G0302-009 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G0302-010 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G0302-011 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G0302-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record

## Dependencies and parallel work

001 → 002 → {003 (agent A), 005 (agent B, against the contract; replays tested with a hand-built fixture)} → 004 (needs
003) → 006 (needs 004, 005) → 007 … 012. Shared files (error, manifest, difficulty, generator, catalog tests, witness
files, docs) stay with the lead. MVP: Story 1.
