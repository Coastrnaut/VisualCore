# Tasks: R02-G12-02 — Harmonic Bridges: level generator and solver witness

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G12-02 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G12-02 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Test seed
2_412; tests stay short (< 10 s each; catalog certification in groups of 5 levels, measured locally, never asserted on
CI). No {owner} or {device} tasks (pure logic); no GLSL.

## Phase 1: Setup

- [X] T-R02G1202-001 Baselines: `--name baseline-host`, `--name baseline-timing`, `--name baseline-round02 -- swift test — Verified 2026-11-23: baseline-host, baseline-timing, baseline-round02 exit 0 on the committed tree; rendering baseline is R02-G12-01's rendering runs (exit 0)
  --package-path Packages/ExperiencesRound02`; the rendering baseline is R02-G12-01's rendering runs (exit 0)

## Phase 2: Foundational

- [X] T-R02G1202-002 Add `generation(Int)` ("r02-g12.generation") and `witness(String)` ("r02-g12.witness") to — Verified 2026-11-23: host exit 0 (40 Harmonic Bridges tests, existing behaviour unchanged); generation(Int) and witness(String) refusals added; HarmonicBridgesManifest with the 100 entries of planning_index.py levels --experience R02-G12 (20 per band, budgets 8 … 19) and provenance; HarmonicBridgesDifficulty lands with the solver in T-003 because it is built from the solver's plan
  `Packages/ExperiencesRound02/HarmonicBridges/Core/HarmonicBridgesError.swift`; create
  `Packages/ExperiencesRound02/HarmonicBridges/Core/HarmonicBridgesManifest.swift` (the 100 entries "number 1 … 100,
  planned seed, band 1 … 5, budget 8 … 19" copied from `python3 scripts/planning_index.py levels --experience R02-G12`,
  with provenance) and `Packages/ExperiencesRound02/HarmonicBridges/Core/HarmonicBridgesDifficulty.swift`; `--name host`

## Phase 3: Story 1 — every shipped level can be solved (P1) 🎯

- [ ] T-R02G1202-003 [US1] Implement `Packages/ExperiencesRound02/HarmonicBridges/Core/HarmonicBridgesSolver.swift`
  (lead: bridge patterns per string and peg over the window's steps; options = maximal patterns among the other pegs not
  contained in the current pattern, each realised by its lowest peg; plans of k = 1 … 6 retuned strings, subsets of the
  useful strings in lexicographic index order, the product of their options in order, the first winning choice; smaller
  choices counted as the minimality proof; work counted and bounded at 400 000; witness actions and replay check) with
  `Packages/ExperiencesRound02/HarmonicBridges/CoreTests/HarmonicBridgesSolverTests.swift` (agent A: hand levels with
  known minima; the plan wins and every choice of one fewer fails; the independent brute force — every peg of every
  smaller set, no pattern pruning — on seeded small levels; work bound respected); `--name host-2`

## Phase 4: Story 2 — levels come from their planned seeds (P1)

- [ ] T-R02G1202-004 [US2] Create `Packages/ExperiencesRound02/HarmonicBridges/Core/HarmonicBridgesGenerator.swift`
  (lead: band profiles "band 1: 1 … 2, 1, 2, 1 … 3, 1 … 2; band 2: 2 … 3, 1 … 2, 2 … 3, 2 … 4, 2 … 3; band 3: 3 … 4, 2,
  2 … 3, 2 … 5, 2 … 4; band 4: 4 … 5, 2 … 3, 2 … 3, 3 … 6, 3 … 4; band 5: 5 … 6, 3 … 4, 3, 3 … 6, 3 … 5" (scrambled,
  steps, tones, thresholds, decoys); frequencies {6, 12, 18, 24, 30, 36, 48, 60, 72}; candidates from
  `SeedDerivation.derive(plannedSeed, index: c)` in the drawing order of clarification Q1; at most 256 candidates then
  `generation(n)`; level ids `harmonic-bridges-NNN`; tutorial on 1 … 3; catalog digest) with
  `Packages/ExperiencesRound02/HarmonicBridges/CoreTests/HarmonicBridgesGeneratorTests.swift` (agent C: determinism,
  drawing order, band values, filters, the candidate bound and its refusal); `--name host-3`

## Phase 5: Stories 3 and 4 — difficulty and honest witness files (P2)

- [ ] T-R02G1202-005 [P] [US4] Create `Packages/ExperiencesRound02/HarmonicBridges/Core/HarmonicBridgesWitness.swift`
  (agent B: schema 1 sorted-key JSON; bridge digests "first 16 hex of SHA-256 of the bridges per step" after each tuning;
  play fingerprints after begin (and dismissTutorial) and each action; counterexample (the size one below and the count
  of its choices tried; for a one-tuning plan the starting pegs' break); difficulty; skipped; decode refuses newer,
  damaged and non-replaying files) with
  `Packages/ExperiencesRound02/HarmonicBridges/CoreTests/HarmonicBridgesWitnessTests.swift`; `--name host-4`
- [ ] T-R02G1202-006 [US2] [US3] [US4] Create
  `Packages/ExperiencesRound02/HarmonicBridges/CoreTests/HarmonicBridgesCatalogTests.swift` (lead: 100 entries, 20 per
  band; every level generated, won by its witness within the budget, and no set of one tuning fewer wins; the brute force
  on two levels per band (every peg in bands 1 … 3, every pattern in bands 4 and 5); pinned digest; progression rule and
  band means; witness files byte for byte, written only with `HARMONIC_BRIDGES_WRITE_WITNESSES=1`; groups of 5) and the
  100 files `docs/games/harmonic-bridges/levels/001.witness.json` … `100.witness.json`; `--name host-5`

## Phase 6: Regression, documentation and close

- [ ] T-R02G1202-007 Docs: `docs/architecture/harmonic-bridges.md` (content pipeline),
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host`
- [ ] T-R02G1202-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`,
  `--name host-full`
- [ ] T-R02G1202-009 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G1202-010 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G1202-011 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G1202-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record

## Dependencies and parallel work

001 → 002 → 003 core and 004 core (lead) → {003 tests (agent A), 004 tests (agent C), 005 (agent B)} → 006 → 007 … 012.
Agents work in isolated copies against contracts/api.md; shared files (error, manifest, solver, difficulty, generator,
catalog tests, witness files, docs) stay with the lead. MVP: Story 1.
