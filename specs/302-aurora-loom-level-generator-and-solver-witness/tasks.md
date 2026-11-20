# Tasks: R02-G01-02 — Aurora Loom: level generator and solver witness

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G01-02 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G01-02 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). No {owner}
or {device} tasks (pure logic and host-generated content). Fixture seeds 2_301 and 2_302; tests stay short (< 10 s each).

## Phase 1: Setup

- [X] T-R02G0102-001 Baselines: `--name baseline-host -- swift test --package-path Packages/VisualCore` and the isolated — Verified 2026-11-20: 2026-11-20 baseline-host, baseline-timing, baseline-round02 exit 0 (.autonomy/migration/checks/R02-G01-02.baseline-*.json); rendering baseline R02-G01-01 rendering-27/26 exit 0
  timing run (`--name baseline-timing`); `--name baseline-round02 -- swift test --package-path Packages/ExperiencesRound02`;
  the rendering baseline is R02-G01-01's rendering runs (exit 0)

## Phase 2: Foundational

- [X] T-R02G0102-002 Add `generation(Int)` ("r02-g01.generation") and `witness(String)` ("r02-g01.witness") to — Verified 2026-11-20: 2026-11-20 host exit 0: all 59 AuroraLoomCore tests incl. the 32 of R02-G01-01 unchanged; generation and witness reason codes; manifest of 100 entries; difficulty; solution types (.autonomy/migration/checks/R02-G01-02.host.json)
  `Packages/ExperiencesRound02/AuroraLoom/Core/AuroraLoomError.swift` (with their `reasonCode` cases); create
  `Packages/ExperiencesRound02/AuroraLoom/Core/AuroraLoomManifest.swift` (AuroraLoomManifestEntry "number 1 … 100, seed
  UInt64, band 1 … 5, budget 8 … 19", the 100 entries copied from `python3 scripts/planning_index.py levels --experience
  R02-G01` with the source line) and `Packages/ExperiencesRound02/AuroraLoom/Core/AuroraLoomDifficulty.swift`
  (AuroraLoomDifficulty, `puzzleDifficulty`); the `AuroraLoomSolution` and `AuroraLoomSolveMethod` types in
  `Packages/ExperiencesRound02/AuroraLoom/Core/AuroraLoomSolver.swift` as the contract states (solver body by agent A);
  `--name host -- swift test --package-path Packages/ExperiencesRound02` (existing tests unchanged)

## Phase 3: Story 1 — every shipped level can be solved (P1) 🎯

- [X] T-R02G0102-003 [P] [US1] Implement `AuroraLoomSolver.solve` in — Verified 2026-11-20: 2026-11-20 host-2 exit 0: AuroraLoomSolverTests 5/5 (500 seeded levels: solution wins, replays via AuroraLoomRules and equals an independent exhaustive per-ribbon check with the full win test; determinism; drifting ribbon gives nil; tie rules; work bound) (.autonomy/migration/checks/R02-G01-02.host-2.json)
  `Packages/ExperiencesRound02/AuroraLoom/Core/AuroraLoomSolver.swift` (per-ribbon descent "at most 32 sweeps", then the
  grid of 256 settings per ribbon; shortest = sum of per-ribbon fewest changes; tie rules and move order of clarification
  Q2; method; work = setting evaluations) with `Packages/ExperiencesRound02/AuroraLoom/CoreTests/AuroraLoomSolverTests.swift`
  (500 seeded levels, seed 2_302: shortest equals an independent exhaustive per-ribbon check with the full win test; the
  solution's setting wins; its moves applied on `AuroraLoomRules` reach it; descent and grid agree when descent claims;
  a level with an unsolvable ribbon returns nil); `--name host-2`

## Phase 4: Story 2 — levels come from their planned seeds (P1)

- [X] T-R02G0102-004 [US2] Create `Packages/ExperiencesRound02/AuroraLoom/Core/AuroraLoomGenerator.swift` — Verified 2026-11-20: 2026-11-20 host-3 exit 0: AuroraLoomGeneratorTests 4/4 (band profiles; ids; 40 seeded entries deterministic within band and budget with skipped candidates re-checked; generation refusals incl. a range beyond six controls, which first hung the scramble loop and is now capped at six) (.autonomy/migration/checks/R02-G01-02.host-3.json)
  (AuroraLoomBandProfile "Ω 16, 32, 64, 128, 256; tolerance 160, 96, 64, 40, 24; shortest 1–2 … 5–6", AuroraLoomGenerated,
  `generate` with candidates k = 0 … 63 from `SeedDerivation.derive(seed, index: k)`, id `aurora-loom-NNN`, allowance =
  budget, tutorial for 1 … 3, `.generation(number)` beyond 64; `catalog()`; `catalogDigest`) with
  `Packages/ExperiencesRound02/AuroraLoom/CoreTests/AuroraLoomGeneratorTests.swift` (determinism; band ranges; budget;
  skipped recorded; refusal path through a profile that cannot be met); `--name host-3`

## Phase 5: Stories 3 and 4 — difficulty and honest witness files (P2)

- [ ] T-R02G0102-005 [P] [US4] Create `Packages/ExperiencesRound02/AuroraLoom/Core/AuroraLoomWitness.swift`
  (AuroraLoomCounterexample; AuroraLoomWitness "schema 1", built by replaying the solution on an `AuroraLoomPlay`,
  fingerprints after begin/tutorial and each action, terminal worst mismatch, counterexample "ribbon 0's phase + 1 step mod
  16", sorted-key pretty JSON with a trailing newline; `decode` refuses newer, damaged and non-replaying witnesses) with
  `Packages/ExperiencesRound02/AuroraLoom/CoreTests/AuroraLoomWitnessTests.swift` (round trip byte for byte; edited
  action, fingerprint, level and difficulty refused; newer schema and damaged JSON refused; counterexample loses with a named
  ribbon, gate and tick; `.witness("counterexample")` when the near-miss would not lose, `.witness("replay")` when the
  actions do not win); `--name host-4`
- [ ] T-R02G0102-006 [US2] [US3] [US4] Create `Packages/ExperiencesRound02/AuroraLoom/CoreTests/AuroraLoomCatalogTests.swift`
  (100 entries, 20 per band; the catalog generated twice is identical; pinned digest; `ProgressionRule.standard` holds on
  shortest; band means of shortest and work do not fall; each witness equals
  `docs/games/aurora-loom/levels/NNN.witness.json` byte for byte, written only with `AURORA_LOOM_WRITE_WITNESSES=1`;
  `testAuroraLoomContentBoundary` for R2-G01-INV-06 with a seeded neighbouring check) and generate the 100 files in
  `docs/games/aurora-loom/levels/`; `--name host-5`

## Phase 6: Regression, documentation and close

- [ ] T-R02G0102-007 Docs: `docs/architecture/aurora-loom.md` (generator, solver, witness), `Packages/ExperiencesRound02/README.md`,
  `docs/automatedtesting.md` (witness regeneration); `--name round02-host -- swift test --package-path
  Packages/ExperiencesRound02`
- [ ] T-R02G0102-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences` and
  `--name host-full`
- [ ] T-R02G0102-009 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G0102-010 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G0102-011 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G0102-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record

## Dependencies and parallel work

001 → 002 → {003 (agent A), 005 (agent B, against the contract; replays need a solution, tested with a hand-built
fixture)} → 004 (needs 003) → 006 (needs 004, 005) → 007 … 012. Shared files (error, manifest, generator, catalog test,
witness files, docs) stay with the lead. MVP: Story 1.
