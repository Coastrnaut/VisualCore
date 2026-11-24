# Tasks: R02-G14-02 — Moonlit Mechanism: level generator and solver witness

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G14-02 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G14-02 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Test seed
2_432; tests stay short (< 10 s each; catalog certification in groups of 20 levels, measured locally, never asserted on
CI). No {owner} or {device} tasks (pure logic); no GLSL.

## Phase 1: Setup

- [X] T-R02G1402-001 Baselines after R02-G14-01 is recorded: `--name baseline-host`, `--name baseline-timing`, `--name — Verified 2026-11-24: 2026-11-24: baseline-host, baseline-timing, baseline-round02 exit 0 on cd1b4f82f (.autonomy/migration/checks/R02-G14-02.baseline-*.json); rendering baseline = R02-G14-01 rendering-27/26
  baseline-round02 -- swift test --package-path Packages/ExperiencesRound02`; the rendering baseline is R02-G14-01's
  rendering runs (exit 0)

## Phase 2: Foundational

- [X] T-R02G1402-002 Add `generation(Int)` ("r02-g14.generation") and `witness(String)` ("r02-g14.witness") to — Verified 2026-11-24: 2026-11-24: generation and witness refusals (r02-g14.generation, .witness), the 100-entry manifest from the archived table, difficulty (with the solver's plan type it needs); host exit 0, existing 41 tests (.autonomy/migration/checks/R02-G14-02.host.json)
  `Packages/ExperiencesRound02/MoonlitMechanism/Core/MoonlitMechanismError.swift`; create
  `Packages/ExperiencesRound02/MoonlitMechanism/Core/MoonlitMechanismManifest.swift` (the 100 entries "number 1 … 100,
  planned seed, band 1 … 5, budget 8 … 19" copied from `python3 scripts/planning_index.py levels --experience R02-G14`,
  with provenance) and `Packages/ExperiencesRound02/MoonlitMechanism/Core/MoonlitMechanismDifficulty.swift`; `--name
  host`

## Phase 3: Story 1 — every shipped level can be solved (P1) 🎯

- [X] T-R02G1402-003 [US1] Implement `Packages/ExperiencesRound02/MoonlitMechanism/Core/MoonlitMechanismSolver.swift` — Verified 2026-11-24: 2026-11-24: lead solver (plan vectors by L1 norm, range and alignment pruning, runs as work bound 400,000, witness order); agent A 11 tests incl. an independent breadth-first search on 40 fixtures and two catalog levels per band, smaller-vector counts, bounds; host-2 exit 0 (.autonomy/migration/checks/R02-G14-02.host-2.json)
  (lead: plan vectors (t, h, r₁ … rₙ₋₁) by L1 norm c = 0, 1, 2, …, each coordinate from −left to +left in the order t,
  h, r₁, …, the last coordinate +left before −left; a vector leaving the lamp range skipped; a vector leaving a mesh
  misaligned skipped without a run; every other vector judged by the kernel's run; the first winning vector is the
  plan; smaller vectors counted as the minimality proof; work = runs, bounded at 400,000; at most 6 actions; witness
  actions (turns, re-seats in gear order, lamp steps, run) and replay check) with
  `Packages/ExperiencesRound02/MoonlitMechanism/CoreTests/MoonlitMechanismSolverTests.swift` (agent A: hand levels with
  known minima; the plan wins and no shorter sequence does; the independent breadth-first search over every action
  sequence the play accepts (states merged by phases and lamp height) on seeded levels; the work bound respected);
  `--name host-2`

## Phase 4: Story 2 — levels come from their planned seeds (P1)

- [X] T-R02G1402-004 [US2] Create `Packages/ExperiencesRound02/MoonlitMechanism/Core/MoonlitMechanismGenerator.swift` — Verified 2026-11-24: 2026-11-24: lead generator (band profiles, drawing order of Q1, filters, 256-candidate bound, digest); agent C 13 tests incl. an independent re-draw of 20 entries x 12 candidates, per-band generation and difficulty recount, the generation refusal; host-3 exit 0 (.autonomy/migration/checks/R02-G14-02.host-3.json)
  (lead: band profiles "band 1: 2 … 3, 2 … 3, 2, 2 … 3, 1 … 2; band 2: 3, 3, 2 … 3, 3 … 4, 2 … 3; band 3: 3 … 4, 3 … 4,
  3, 4 … 6, 3 … 4; band 4: 4, 4, 3 … 4, 5 … 7, 4 … 5; band 5: 4 … 5, 4 … 5, 4 … 5, 7 … 9, 5 … 6" (gears, lamp heights,
  key frames, scramble, plan range); candidates from `SeedDerivation.derive(plannedSeed, index: c)` in the drawing order
  of clarification Q1; at most 256 candidates then `generation(n)`; level ids `moonlit-mechanism-NNN`; tutorial on
  1 … 3; catalog digest) with `Packages/ExperiencesRound02/MoonlitMechanism/CoreTests/MoonlitMechanismGeneratorTests.swift`
  (agent C: determinism, drawing order, band values, filters, the candidate bound and its refusal); `--name host-3`

## Phase 5: Stories 3 and 4 — difficulty and honest witness files (P2)

- [X] T-R02G1402-005 [P] [US4] Create `Packages/ExperiencesRound02/MoonlitMechanism/Core/MoonlitMechanismWitness.swift` — Verified 2026-11-24: 2026-11-24: agent B witness (canonical phase/height digests, play fingerprints, counterexample norm and vector count in closed form, decode re-verification) with 15 tests; host-4 exit 0 (.autonomy/migration/checks/R02-G14-02.host-4.json)
  (agent B: schema 1 sorted-key JSON; state digests "first 16 hex of SHA-256 of the phases and the lamp height" after
  each action; play fingerprints after begin (and dismissTutorial) and each action; counterexample (the norm one below
  and the count of its vectors tried); difficulty; skipped; decode refuses newer, damaged and non-replaying files) with
  `Packages/ExperiencesRound02/MoonlitMechanism/CoreTests/MoonlitMechanismWitnessTests.swift`; `--name host-4`
- [X] T-R02G1402-006 [US2] [US3] [US4] Create — Verified 2026-11-24: 2026-11-24: catalog tests (manifest, pinned digest 7de63603…, progression and band means 1.9/2.5/3.5/4.5/5.3, every witness wins, breadth-first search through the play on two levels per band finds the first win at exactly the plan, re-verified decodes, 100 witness files byte for byte in 5 groups) and docs/games/moonlit-mechanism/levels/001…100.witness.json; host-5 exit 0 (.autonomy/migration/checks/R02-G14-02.host-5.json)
  `Packages/ExperiencesRound02/MoonlitMechanism/CoreTests/MoonlitMechanismCatalogTests.swift` (lead: 100 entries, 20 per
  band; every level generated, won by its witness within the budget, and no shorter sequence wins; the breadth-first
  search on the two levels with the fewest gears in each band; pinned digest; progression rule and band means; witness
  files byte for byte, written only with `MOONLIT_MECHANISM_WRITE_WITNESSES=1`; groups of 20) and the 100 files
  `docs/games/moonlit-mechanism/levels/001.witness.json` … `100.witness.json`; `--name host-5`

## Phase 6: Regression, documentation and close

- [X] T-R02G1402-007 Docs: `docs/architecture/moonlit-mechanism.md` (content pipeline), — Verified 2026-11-24: 2026-11-24: architecture content-pipeline section, ExperiencesRound02 README feature 432, testing doc; round02-host exit 0 in 373 s (.autonomy/migration/checks/R02-G14-02.round02-host.json)
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host`
- [ ] T-R02G1402-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`,
  `--name host-full`
- [ ] T-R02G1402-009 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G1402-010 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G1402-011 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G1402-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record;
  README row and gate list updated

## Dependencies and parallel work

001 → 002 → 003 core and 004 core (lead) → {003 tests (agent A), 004 tests (agent C), 005 (agent B)} → 006 → 007 … 012.
Agents work in isolated copies against contracts/api.md; shared files (error, manifest, solver, difficulty, generator,
catalog tests, witness files, docs) stay with the lead. Agents and the lead may draft in isolated copies before 001
(new files only). MVP: Story 1. Requirement coverage: FR-001 → 004, 006; FR-002 → 003, 006; FR-003 → 002, 004; FR-004 →
005, 006; FR-005 → 006; FR-006 → 002, 007 … 011.
