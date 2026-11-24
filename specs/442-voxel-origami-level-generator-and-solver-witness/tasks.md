# Tasks: R02-G15-02 — Voxel Origami: level generator and solver witness

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G15-02 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G15-02 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Test seed
2_442; tests stay short (< 10 s each; catalog certification in groups of 20 levels, measured locally, never asserted on
CI). No {owner} or {device} tasks (pure logic); no GLSL.

## Phase 1: Setup

- [X] T-R02G1502-001 Baselines after R02-G15-01 is recorded: `--name baseline-host`, `--name baseline-timing`, `--name — Verified 2026-11-24: 2026-11-24: baseline-host, baseline-timing, baseline-round02 exit 0 (.autonomy/migration/checks/R02-G15-02.baseline-*.json); rendering baseline = R02-G15-01 rendering-27/26
  baseline-round02 -- swift test --package-path Packages/ExperiencesRound02`; the rendering baseline is R02-G15-01's
  rendering runs (exit 0)

## Phase 2: Foundational

- [X] T-R02G1502-002 Add `generation(Int)` ("r02-g15.generation") and `witness(String)` ("r02-g15.witness") to — Verified 2026-11-24: 2026-11-24: generation and witness refusals, 100-entry manifest with emphases and orientations, difficulty (the solver lands with it, the difficulty being built from its plan); host exit 0, existing Voxel Origami suites unchanged (.autonomy/migration/checks/R02-G15-02.host.json)
  `Packages/ExperiencesRound02/VoxelOrigami/Core/VoxelOrigamiError.swift`; create
  `Packages/ExperiencesRound02/VoxelOrigami/Core/VoxelOrigamiManifest.swift` (the 100 entries "number 1 … 100, planned
  seed, band 1 … 5, budget 8 … 19, emphasis" copied from `python3 scripts/planning_index.py levels --experience
  R02-G15`, with provenance; orientations "rotate assembly → any, lock shape → fixed, else upright") and
  `Packages/ExperiencesRound02/VoxelOrigami/Core/VoxelOrigamiDifficulty.swift`; `--name host`

## Phase 3: Story 1 — every shipped level can be solved (P1) 🎯

- [ ] T-R02G1502-003 [US1] Implement `Packages/ExperiencesRound02/VoxelOrigami/Core/VoxelOrigamiSolver.swift` (lead: a
  breadth-first search over quarter-turn states from the start; states expanded in the order reached, moves in hinge
  order ascending, step −1 then +1; only hinges that would swing a cube; a move reaches a state only when the kernel's
  collision and exact sweep rule clear it; states merged by their quarter turns; the first reached state whose pose
  matches ends the search and its path is the plan; states counted at each smaller depth as the minimality proof; work
  = turns tried, bounded at 300 000; at most 6 turns; replay check) with
  `Packages/ExperiencesRound02/VoxelOrigami/CoreTests/VoxelOrigamiSolverTests.swift` (agent A: hand levels with known
  minima; the plan matches and no shorter sequence does; the independent depth-first enumeration of every turn sequence
  the play accepts (no state merging) on seeded levels; the work bound respected; the plan is the first in the fixed
  order); `--name host-2`

## Phase 4: Story 2 — levels come from their planned seeds (P1)

- [ ] T-R02G1502-004 [US2] Create `Packages/ExperiencesRound02/VoxelOrigami/Core/VoxelOrigamiGenerator.swift` (lead: band
  profiles "band 1: 5 … 6, 2 … 4, 1 … 2; band 2: 6 … 7, 4 … 6, 2 … 3; band 3: 7 … 8, 6 … 9, 3 … 4; band 4: 8 … 9,
  8 … 12, 4 … 5; band 5: 9 … 10, 10 … 14, 5 … 6" (cubes, scramble, plan range); candidates from
  `SeedDerivation.derive(plannedSeed, index: c)` in the drawing order of clarification Q1 (tree redrawn up to 50 times,
  at most eight draws per wanted scramble turn); at most 256 candidates then `generation(n)`; level ids
  `voxel-origami-NNN`; tutorial on 1 … 3; difficulty = band; catalog digest) with
  `Packages/ExperiencesRound02/VoxelOrigami/CoreTests/VoxelOrigamiGeneratorTests.swift` (agent C: determinism, drawing
  order, band values, orientations by emphasis, filters, the candidate bound and its refusal); `--name host-3`

## Phase 5: Stories 3 and 4 — difficulty and honest witness files (P2)

- [ ] T-R02G1502-005 [P] [US4] Create `Packages/ExperiencesRound02/VoxelOrigami/Core/VoxelOrigamiWitness.swift` (agent B:
  schema 1 sorted-key JSON; state digests "first 16 hex of SHA-256 of the quarter turns" after each action; play
  fingerprints after begin (and dismissTutorial) and each action; counterexample (the depth one below and the count of
  states reached at it); difficulty; skipped; decode refuses newer, damaged and non-replaying files) with
  `Packages/ExperiencesRound02/VoxelOrigami/CoreTests/VoxelOrigamiWitnessTests.swift`; `--name host-4`
- [ ] T-R02G1502-006 [US2] [US3] [US4] Create `Packages/ExperiencesRound02/VoxelOrigami/CoreTests/VoxelOrigamiCatalogTests.swift`
  (lead: 100 entries, 20 per band; every level generated, won by its witness within the budget, and no shorter sequence
  matches; the depth-first enumeration on the two levels with the fewest cubes in each band; pinned digest; progression
  rule and band means; witness files byte for byte, written only with `VOXEL_ORIGAMI_WRITE_WITNESSES=1`; groups of 20)
  and the 100 files `docs/games/voxel-origami/levels/001.witness.json` … `100.witness.json`; `--name host-5`

## Phase 6: Regression, documentation and close

- [ ] T-R02G1502-007 Docs: `docs/architecture/voxel-origami.md` (content pipeline),
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host`
- [ ] T-R02G1502-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`,
  `--name host-full`
- [ ] T-R02G1502-009 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G1502-010 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G1502-011 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G1502-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record;
  README row and gate list updated

## Dependencies and parallel work

001 → 002 → 003 core and 004 core (lead) → {003 tests (agent A), 004 tests (agent C), 005 (agent B)} → 006 → 007 … 012.
Agents work in isolated copies against contracts/api.md; shared files (error, manifest, solver, difficulty, generator,
catalog tests, witness files, docs) stay with the lead. Agents and the lead may draft in isolated copies before 001
(new files only). MVP: Story 1. Requirement coverage: FR-001 → 004, 006; FR-002 → 003, 006; FR-003 → 002, 004; FR-004 →
005, 006; FR-005 → 006; FR-006 → 002, 007 … 011.
