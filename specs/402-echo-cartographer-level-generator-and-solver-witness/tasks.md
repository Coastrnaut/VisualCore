# Tasks: R02-G11-02 — Echo Cartographer: level generator and solver witness

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G11-02 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G11-02 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Test seed
2_402; tests stay short (< 10 s each; catalog certification in groups of 5 levels, measured locally, never asserted on
CI). No {owner} or {device} tasks (pure logic); no GLSL.

## Phase 1: Setup

- [ ] T-R02G1102-001 Baselines: `--name baseline-host`, `--name baseline-timing`, `--name baseline-round02 -- swift test
  --package-path Packages/ExperiencesRound02`; the rendering baseline is R02-G11-01's rendering runs (exit 0)

## Phase 2: Foundational

- [ ] T-R02G1102-002 Add `generation(Int)` ("r02-g11.generation") and `witness(String)` ("r02-g11.witness") to
  `Packages/ExperiencesRound02/EchoCartographer/Core/EchoCartographerError.swift`; create
  `Packages/ExperiencesRound02/EchoCartographer/Core/EchoCartographerManifest.swift` (the 100 entries "number 1 … 100,
  planned seed, band 1 … 5, energy 8 … 19" copied from `python3 scripts/planning_index.py levels --experience R02-G11`,
  with provenance) and `Packages/ExperiencesRound02/EchoCartographer/Core/EchoCartographerDifficulty.swift`; `--name host`

## Phase 3: Story 1 — every shipped level can be solved by reasoning (P1) 🎯

- [ ] T-R02G1102-003 [US1] Implement `Packages/ExperiencesRound02/EchoCartographer/Core/EchoCartographerSolver.swift`
  (lead: region, fitting placements by pruned enumeration capped at 1 000, the greedy plan up to 6 pulses from the
  opening knowledge, work counted and bounded at 400 000, witness actions and replay check) with
  `Packages/ExperiencesRound02/EchoCartographer/CoreTests/EchoCartographerSolverTests.swift` (agent A: hand levels with
  known counts; the plan's pulses each from a cell known open at its turn; exactly one placement after the plan and the
  true beacons; the independent brute force — fixed-point path lengths and every beacon-count subset — on seeded small
  chambers; work bound respected); `--name host-2`

## Phase 4: Story 2 — levels come from their planned seeds (P1)

- [ ] T-R02G1102-004 [US2] Create `Packages/ExperiencesRound02/EchoCartographer/Core/EchoCartographerGenerator.swift`
  (lead: band profiles "band 1: 6 … 7, 1/5, 1, 1, 1, 1 … 2; band 2: 7 … 9, 1/5, 1 … 2, 1, 1, 2 … 3; band 3: 8 … 10, 1/4,
  2, 1, 2, 3 … 4; band 4: 9 … 12, 1/4, 2 … 3, 0, 2, 4 … 5; band 5: 10 … 14, 1/4, 3 … 4, 0, 3, 5 … 6"; candidates from
  `SeedDerivation.derive(plannedSeed, index: c)` in the drawing order of clarification Q1; region ≥ 12; at most 256
  candidates then `generation(n)`; level ids `echo-cartographer-NNN`; tutorial on 1 … 3; catalog digest) with
  `Packages/ExperiencesRound02/EchoCartographer/CoreTests/EchoCartographerGeneratorTests.swift` (agent C: determinism,
  drawing order, band values, filters, the candidate bound and its refusal); `--name host-3`

## Phase 5: Stories 3 and 4 — difficulty and honest witness files (P2)

- [ ] T-R02G1102-005 [P] [US4] Create `Packages/ExperiencesRound02/EchoCartographer/Core/EchoCartographerWitness.swift`
  (agent B: schema 1 sorted-key JSON; echo digests "first 16 hex of SHA-256 of the canonical echo"; placements after each
  pulse; play fingerprints after begin (and dismissTutorial) and each action; counterexample; difficulty; skipped;
  decode refuses newer, damaged and non-replaying files) with
  `Packages/ExperiencesRound02/EchoCartographer/CoreTests/EchoCartographerWitnessTests.swift`; `--name host-4`
- [ ] T-R02G1102-006 [US2] [US3] [US4] Create
  `Packages/ExperiencesRound02/EchoCartographer/CoreTests/EchoCartographerCatalogTests.swift` (lead: 100 entries, 20 per
  band; every level generated, won by its witness within the energy, singled out after its pulses and not before the
  last; the brute force on the two smallest regions of each band; pinned digest; progression rule and band means;
  witness files byte for byte, written only with `ECHO_CARTOGRAPHER_WRITE_WITNESSES=1`; groups of 5) and the 100 files
  `docs/games/echo-cartographer/levels/001.witness.json` … `100.witness.json`; `--name host-5`

## Phase 6: Regression, documentation and close

- [ ] T-R02G1102-007 Docs: `docs/architecture/echo-cartographer.md` (content pipeline),
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host`
- [ ] T-R02G1102-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`,
  `--name host-full`
- [ ] T-R02G1102-009 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G1102-010 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G1102-011 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G1102-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record

## Dependencies and parallel work

001 → 002 → 003 core and 004 core (lead) → {003 tests (agent A), 004 tests (agent C), 005 (agent B)} → 006 → 007 … 012.
Agents work in isolated copies against contracts/api.md; shared files (error, manifest, solver, difficulty, generator,
catalog tests, witness files, docs) stay with the lead. MVP: Story 1.
