# Tasks: R02-G13-02 — Acoustic Constellator: level generator and solver witness

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G13-02 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G13-02 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Test seed
2_422; tests stay short (< 10 s each; catalog certification in groups of 5 levels, measured locally, never asserted on
CI). No {owner} or {device} tasks (pure logic); no GLSL.

## Phase 1: Setup

- [X] T-R02G1302-001 Baselines after R02-G13-01 is recorded: `--name baseline-host`, `--name baseline-timing`, `--name — Verified 2026-11-23: baseline-host, baseline-timing, baseline-round02 exit 0 on the committed tree; rendering baseline is R02-G13-01's rendering runs
  baseline-round02 -- swift test --package-path Packages/ExperiencesRound02`; the rendering baseline is R02-G13-01's
  rendering runs (exit 0)

## Phase 2: Foundational

- [X] T-R02G1302-002 Add `generation(Int)` ("r02-g13.generation") and `witness(String)` ("r02-g13.witness") to — Verified 2026-11-23: host (AcousticConstellatorContentSmokeTests + LevelTests 17 tests: manifest of 100 entries, 20 per band, budgets 8...19, reason codes r02-g13.generation and r02-g13.witness, the first two entries of each band generate in range and win) exit 0, lead retest
  `Packages/ExperiencesRound02/AcousticConstellator/Core/AcousticConstellatorError.swift`; create
  `Packages/ExperiencesRound02/AcousticConstellator/Core/AcousticConstellatorManifest.swift` (the 100 entries "number
  1 … 100, planned seed, band 1 … 5, budget 8 … 19" copied from `python3 scripts/planning_index.py levels --experience
  R02-G13`, with provenance) and `Packages/ExperiencesRound02/AcousticConstellator/Core/AcousticConstellatorDifficulty.swift`;
  `--name host`

## Phase 3: Story 1 — every shipped level can be solved (P1) 🎯

- [X] T-R02G1302-003 [US1] Implement `Packages/ExperiencesRound02/AcousticConstellator/Core/AcousticConstellatorSolver.swift` — Verified 2026-11-23: host-2 (AcousticConstellatorSolverTests 10 tests: hand levels with known minima (missing link only, one nudge, helper link, over maxActions, work bound, symbol over degree limit), plans win through the solver and the play, independent brute force over every play action at size plan-1 on 20 seeded candidates finds no win, smallerSets and work recounted independently, deterministic) exit 0, lead retest
  (lead: the missing symbol pairs always in the plan; options = helper links (unlinked pairs, pair order) then nudges
  (star order, −1 then +1); e = 0, 1, 2, … extra actions as multisets in option order, skipping a repeated helper link,
  opposite nudges on one star and sets over the degree or link limit; the kernel's listen on each; the first winning set
  is the plan; smaller sets counted as the minimality proof; work = listens, bounded at 400,000; at most 6 actions;
  witness actions (links in pair order, nudges in star order, listen) and replay check) with
  `Packages/ExperiencesRound02/AcousticConstellator/CoreTests/AcousticConstellatorSolverTests.swift` (agent A: hand levels
  with known minima; the plan wins and every set of one fewer loses; the independent brute force — every multiset of one
  action fewer over all actions the play accepts, no pruning — on seeded small levels; work bound respected);
  `--name host-2`

## Phase 4: Story 2 — levels come from their planned seeds (P1)

- [X] T-R02G1302-004 [US2] Create — Verified 2026-11-23: host-3 (AcousticConstellatorGeneratorTests 8 tests: band profiles, derived limits and threshold, candidate determinism, drawing order re-drawn independently on 200 pairs, band values, generated filters and determinism on 6 entries, generation(n) refusal, catalog digest order-sensitive) exit 0, lead retest; candidate doc comment corrected (degree-5 symbol star)
  `Packages/ExperiencesRound02/AcousticConstellator/Core/AcousticConstellatorGenerator.swift` (lead: band profiles "band
  1: 3 … 4, 1 … 2, 24, 1 … 2; band 2: 4 … 5, 1 … 2, 24, 2 … 3; band 3: 5 … 6, 2 … 3, 32, 3 … 4; band 4: 6 … 7, 2 … 3, 40,
  4 … 5; band 5: 7 … 8, 3 … 4, 48, 5 … 6" (stars, missing, window, plan range) with a cycle from band 3; candidates from
  `SeedDerivation.derive(plannedSeed, index: c)` in the drawing order of clarification Q1; degree limit min(4, max(2,
  largest symbol degree + 1)), link limit min(16, symbol size + 2), threshold ⌊3n²/5⌋; at most 256 candidates then
  `generation(n)`; level ids `acoustic-constellator-NNN`; tutorial on 1 … 3; catalog digest) with
  `Packages/ExperiencesRound02/AcousticConstellator/CoreTests/AcousticConstellatorGeneratorTests.swift` (agent C:
  determinism, drawing order, band values, filters, the candidate bound and its refusal); `--name host-3`

## Phase 5: Stories 3 and 4 — difficulty and honest witness files (P2)

- [X] T-R02G1302-005 [P] [US4] Create — Verified 2026-11-23: host-4 (AcousticConstellatorWitnessTests 15 tests: entries 1, 21, 41 through generate and make; byte-identical re-encoding; parts equal the solver's plan; digests and fingerprints equal an independent replay; counterexample (size, sets, reason missing/tried) consistent; every refusal named: actions, replay, digests, fingerprints, counterexample, level, candidate, difficulty, number, skipped, solution, newer schema, schema, unreadable) exit 0, lead retest
  `Packages/ExperiencesRound02/AcousticConstellator/Core/AcousticConstellatorWitness.swift` (agent B: schema 1 sorted-key
  JSON; state digests "first 16 hex of SHA-256 of the links and phases" after each action; play fingerprints after begin
  (and dismissTutorial) and each action; counterexample (the size one below and the count of its sets tried);
  difficulty; skipped; decode refuses newer, damaged and non-replaying files) with
  `Packages/ExperiencesRound02/AcousticConstellator/CoreTests/AcousticConstellatorWitnessTests.swift`; `--name host-4`
- [X] T-R02G1302-006 [US2] [US3] [US4] Create — Verified 2026-11-23: host-5 (AcousticConstellatorCatalogTests 9 tests: 100 entries 20 per band, pinned digest 4c50d04a...7a12, progression rule and band means, every stored witness wins within its budget, brute force over every play action on two fewest-star levels in bands 1-3 and over the pruned options in bands 4-5 finds no smaller win, one full decode per band, 100 witness files byte for byte in 20 groups) exit 0, lead retest; files unchanged by the run
  `Packages/ExperiencesRound02/AcousticConstellator/CoreTests/AcousticConstellatorCatalogTests.swift` (lead: 100 entries,
  20 per band; every level generated, won by its witness within the budget, and no set of one action fewer wins; the
  brute force on two levels per band (all play actions in bands 1 … 3, the pruned options in bands 4 and 5); pinned digest; progression rule and band means; witness files byte for byte,
  written only with `ACOUSTIC_CONSTELLATOR_WRITE_WITNESSES=1`; groups of 5) and the 100 files
  `docs/games/acoustic-constellator/levels/001.witness.json` … `100.witness.json`; `--name host-5`

## Phase 6: Regression, documentation and close

- [X] T-R02G1302-007 Docs: `docs/architecture/acoustic-constellator.md` (content pipeline), — Verified 2026-11-23: round02-host exit 0; architecture doc content pipeline, ExperiencesRound02 README feature 422, testing doc entry; validate_docs passes
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host`
- [X] T-R02G1302-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`, — Verified 2026-11-23: 2026-11-23: rendering-27, rendering-26, experiences, host-full exit 0 (.autonomy/migration/checks/R02-G13-02.{rendering-27,rendering-26,experiences,host-full}.json)
  `--name host-full`
- [X] T-R02G1302-009 Reference regression chunk 1 (`--name reference-1`) — Verified 2026-11-23: 2026-11-23: reference-1 exit 0 (.autonomy/migration/checks/R02-G13-02.reference-1.json)
- [X] T-R02G1302-010 Reference regression chunk 2 (`--name reference-2`) — Verified 2026-11-23: 2026-11-23: reference-2 exit 0 (.autonomy/migration/checks/R02-G13-02.reference-2.json)
- [ ] T-R02G1302-011 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G1302-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record;
  README row and gate list updated

## Dependencies and parallel work

001 → 002 → 003 core and 004 core (lead) → {003 tests (agent A), 004 tests (agent C), 005 (agent B)} → 006 → 007 … 012.
Agents work in isolated copies against contracts/api.md; shared files (error, manifest, solver, difficulty, generator,
catalog tests, witness files, docs) stay with the lead. MVP: Story 1. Requirement coverage: FR-001 → 004, 006; FR-002
→ 003, 006; FR-003 → 002, 004; FR-004 → 005, 006; FR-005 → 006; FR-006 → 002, 007 … 011.

## Phase 7: Convergence

- [X] T-R02G1302-013 Align `specs/422-acoustic-constellator-level-generator-and-solver-witness/data-model.md` with the — Verified 2026-11-23: data-model.md now states the plan's links in one pair-ordered list with one nudge entry per step (as AcousticConstellatorSolver does) and that degree-5 symbol candidates are refused by the level rules and skipped (as AcousticConstellatorGenerator.candidate does)
  code: `AcousticConstellatorPlan` keeps all its links (missing and helper) in one list in pair order and one nudge entry
  per ±1 step, and a candidate whose symbol has a star of degree 5 or more (over the capped degree limit of 4) is refused
  by the level rules and skipped like any uncertified candidate, per plan: data-model (contradicts)
