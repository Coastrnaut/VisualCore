# Tasks: R02-G16-02 — Starlit Cartouche: level generator and solver witness

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G16-02 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G16-02 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Test seed
2_452; tests stay short (< 10 s each; catalog certification in groups of 10 levels, measured locally, never asserted on
CI). No {owner} or {device} tasks (pure logic); no GLSL.

## Phase 1: Setup

- [X] T-R02G1602-001 Baselines after R02-G16-01 is recorded: `--name baseline-host`, `--name baseline-timing`, `--name — Verified 2026-11-24: baseline-host, baseline-timing, baseline-round02-1..3 exit 0 (.autonomy/migration/checks/R02-G16-02.baseline-*.json)
  baseline-round02-1 … 3` (the three round-two filters of feature 446); the rendering baseline is R02-G16-01's
  rendering runs (exit 0)

## Phase 2: Foundational

- [X] T-R02G1602-002 Add `generation(Int)` ("r02-g16.generation") and `witness(String)` ("r02-g16.witness") to — Verified 2026-11-24: host-r2 exit 0 (.autonomy/migration/checks/R02-G16-02.host-r2.json; first host attempt failed on the 451 budget-17 refusal, moved to 25); solver source lands here because Difficulty uses its plan
  `Packages/ExperiencesRound02/StarlitCartouche/Core/StarlitCartoucheError.swift`; widen the budget bound to "1 … 24"
  in `Packages/ExperiencesRound02/StarlitCartouche/Core/StarlitCartoucheLevel.swift`; create
  `Packages/ExperiencesRound02/StarlitCartouche/Core/StarlitCartoucheManifest.swift` (the 100 entries "number 1 … 100,
  planned seed, band 1 … 5, budget 8 … 19, emphasis" copied from `python3 scripts/planning_index.py levels --experience
  R02-G16`, with provenance) and `Packages/ExperiencesRound02/StarlitCartouche/Core/StarlitCartoucheDifficulty.swift`;
  `--name host`

## Phase 3: Story 1 — every shipped level can be solved (P1) 🎯

- [X] T-R02G1602-003 [US1] Implement `Packages/ExperiencesRound02/StarlitCartouche/Core/StarlitCartoucheSolver.swift` — Verified 2026-11-24: host-2r2 exit 0 (.autonomy/migration/checks/R02-G16-02.host-2r2.json; host-2 failed to compile: solver tests use the generator, landed with T-004); StarlitCartoucheSolverTests 7 tests, hand minima + independent DFS
  (lead: a breadth-first search over route states (star, beat, strokes drawn) from the start; states expanded in the
  order reached, legs by corridor index (those touching the ship's star) then wait 0 … 8; a leg reaches a state only
  when the chart accepts it and finds no failure; states merged by star, beat and stroke mask; the first winning leg
  ends the search and its path is the plan; states counted at each smaller depth as the minimality proof; work = legs
  tried, bounded at 300 000; at most 7 legs; replay check) with
  `Packages/ExperiencesRound02/StarlitCartouche/CoreTests/StarlitCartoucheSolverTests.swift` (agent A: hand levels with
  known minima (a wait needed for range, a hazard to wait out, a window that forces an order); the plan wins and no
  shorter sequence does; the independent depth-first enumeration of every leg sequence the play accepts (no state
  merging) on seeded levels; the work bound respected; the plan is the first in the fixed order); `--name host-2`

## Phase 4: Story 2 — levels come from their planned seeds (P1)

- [X] T-R02G1602-004 [US2] Create `Packages/ExperiencesRound02/StarlitCartouche/Core/StarlitCartoucheGenerator.swift` — Verified 2026-11-24: host-3 exit 0 (.autonomy/migration/checks/R02-G16-02.host-3.json); StarlitCartoucheGeneratorTests 11 tests incl. independent redraw of the Q1 order; all 100 entries certify, at most 2 skipped
  (lead: band profiles "band b: stars b + 4 … b + 5, route b + 1 … b + 2, decoys b + 1, plan range b + 1 … b + 2";
  candidates from `SeedDerivation.derive(plannedSeed, index: c)` in the drawing order of clarification Q1 (up to 8
  draws per route leg); at most 256 candidates then `generation(n)`; level ids `starlit-cartouche-NNN`; tutorial on
  1 … 3; difficulty = band; catalog digest) with
  `Packages/ExperiencesRound02/StarlitCartouche/CoreTests/StarlitCartoucheGeneratorTests.swift` (agent C: determinism,
  drawing order, band values, hazards and windows by emphasis, hazards never meeting the route, filters, the candidate
  bound and its refusal); `--name host-3`

## Phase 5: Stories 3 and 4 — difficulty and honest witness files (P2)

- [X] T-R02G1602-005 [P] [US4] Create `Packages/ExperiencesRound02/StarlitCartouche/Core/StarlitCartoucheWitness.swift` — Verified 2026-11-24: host-4 exit 0 (.autonomy/migration/checks/R02-G16-02.host-4.json); StarlitCartoucheWitnessTests 13 tests: round trip, known digests, every refusal
  (agent B: schema 1 sorted-key JSON; state digests "first 16 hex of SHA-256 of the ship's star, the beat and the drawn
  strokes" after each action; play fingerprints after begin (and dismissTutorial) and each action; counterexample (the
  depth one below and the count of states reached at it); difficulty; skipped; decode refuses newer, damaged and
  non-replaying files) with `Packages/ExperiencesRound02/StarlitCartouche/CoreTests/StarlitCartoucheWitnessTests.swift`;
  `--name host-4`
- [X] T-R02G1602-006 [US2] [US3] [US4] Create — Verified 2026-11-24: host-5 exit 0 (.autonomy/migration/checks/R02-G16-02.host-5.json); StarlitCartoucheCatalogTests 8 tests, digest ee022539…969e pinned, 100 witness files written with STARLIT_CARTOUCHE_WRITE_WITNESSES=1
  `Packages/ExperiencesRound02/StarlitCartouche/CoreTests/StarlitCartoucheCatalogTests.swift` (lead: 100 entries, 20 per
  band; every level generated, won by its witness within the budget, and no shorter sequence wins; the depth-first
  enumeration on the two levels with the fewest stars in each band; pinned digest; progression rule and band means;
  witness files byte for byte, written only with `STARLIT_CARTOUCHE_WRITE_WITNESSES=1`; groups of 10) and the 100 files
  `docs/games/starlit-cartouche/levels/001.witness.json` … `100.witness.json`; `--name host-5`

## Phase 6: Regression, documentation and close

- [X] T-R02G1602-007 Docs: `docs/architecture/starlit-cartouche.md` (content pipeline), — Verified 2026-11-24: round02-host-1..3 exit 0 (.autonomy/migration/checks/R02-G16-02.round02-host-*.json; chunk 3 342 s); architecture, package README and testing doc updated
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host-1 … 3`
- [ ] T-R02G1602-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`,
  `--name host-full`
- [ ] T-R02G1602-009 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G1602-010 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G1602-011 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G1602-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record;
  README row and gate list updated

## Dependencies and parallel work

001 → 002 → 003 core and 004 core (lead) → {003 tests (agent A), 004 tests (agent C), 005 (agent B)} → 006 → 007 … 012.
Agents work in isolated copies against contracts/api.md; shared files (error, level, manifest, solver, difficulty,
generator, catalog tests, witness files, docs) stay with the lead. MVP: Story 1. Requirement coverage: FR-001 → 004,
006; FR-002 → 003, 006; FR-003 → 002, 004; FR-004 → 005, 006; FR-005 → 006; FR-006 → 002, 007 … 011; FR-007 → 002.
