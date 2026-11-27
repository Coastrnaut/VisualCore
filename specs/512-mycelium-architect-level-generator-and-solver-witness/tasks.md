# Tasks: R02-G22-02 — Mycelium Architect: level generator and solver witness

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G22-02. Evidence: `python3
scripts/migration_ledger.py run-check --gate R02-G22-02 --name <check> -- <command>` (never a scratchpad path; recorded
only after every agent has reported; read `exit=` before ticking). Commit after every task (no trailers). Tests short
(< 10 s each). No {owner} or {device} tasks. Every `host` … `host-5` check runs `swift test --package-path
Packages/ExperiencesRound02 --filter MyceliumArchitect`. New sources go in `MyceliumArchitect/Core/Content/`.

## Phase 1: Setup

- [X] T-R02G2202-001 Baselines after R02-G22-01 is recorded: `--name baseline-host`, `--name baseline-timing`, `--name — Verified 2026-11-27: baseline-host, baseline-timing, baseline-round02-1 (VoxelOrigami|MyceliumArchitect)/2/3c/3e/3f exit=0
  baseline-round02-1` (`VoxelOrigami|MyceliumArchitect`), `-2`, `-3c`, `-3e`, `-3f` on the committed tree

## Phase 2: Foundational

- [ ] T-R02G2202-002 Kernel extension: before editing record one literal fingerprint of a hand level from the
  unchanged kernel; edit `Packages/ExperiencesRound02/MyceliumArchitect/Core/MyceliumArchitectLevel.swift` (optional
  `sites`: "nil or 2 … 12 distinct cells, on the board, empty (not root, terminal, rock, toxin, fixed nutrient),
  ascending; refusals "site count", "site", "site not empty" after the shared-cell check and before "nothing
  placeable"; omitted from the stored form and fingerprint when nil"), `MyceliumArchitectPlay.swift` (`changed` refuses
  `.action("not a site")`), `MyceliumArchitectPuzzle.swift` (placements on sites only), `MyceliumArchitectError.swift`
  (`generation(Int)` → "r02-g22.generation", `witness(String)` → "r02-g22.witness"); create
  `Packages/ExperiencesRound02/MyceliumArchitect/CoreTests/MyceliumArchitectSitesTests.swift` (the pinned fingerprint
  and byte-identical stored form without sites, round trip with sites, the refusals in order, the play's and puzzle's
  off-site refusal); `--name host`

## Phase 3: Stories 1 and 2 — solvable levels from planned seeds (P1) 🎯

- [ ] T-R02G2202-003 [US1] [US2] Create `Core/Content/MyceliumArchitectManifest.swift` (the 100 entries with
  provenance), `MyceliumArchitectDifficulty.swift`, `MyceliumArchitectSolver.swift` (clarification Q3: breadth-first by
  action count, loss order, reachability, depth ≤ p, work bound 20 000, replay through the play) and
  `MyceliumArchitectGenerator.swift` (clarification Q2: draw order, band profiles, terminals from the winning growth,
  skips, at most 64 candidates, `generation(n)`, catalog, digest); measure the whole catalog once in an isolated copy
  (accepted candidate index per band, work, witness lengths, slowest level and group of five) and record it in
  research R4 (profile changes written back to spec Q2, research, data model and plan in the same commit); `--name
  host-2`
- [ ] T-R02G2202-004 [P] [US1] Create `CoreTests/MyceliumArchitectSolverTests.swift` (agent A: minimal plans; the
  independent enumeration of every shorter action sequence through the puzzle moves, no visited set, on the two levels
  with the smallest move space per band; per-depth counts equal; work counted; plans replay); `--name host-3`
- [ ] T-R02G2202-005 [P] [US2] Create `CoreTests/MyceliumArchitectGeneratorTests.swift` (agent C: determinism,
  manifest budgets, band profiles respected, skip reasons, neighbour rule, `generation(n)` on an impossible profile,
  source scan of `Core/Content/` for clock and floating-point tokens); `--name host-4`

## Phase 4: Stories 3 and 4 — difficulty and witnesses (P2)

- [ ] T-R02G2202-006 [P] [US4] Create `Core/Content/MyceliumArchitectWitness.swift` and
  `CoreTests/MyceliumArchitectWitnessTests.swift` (agent B: clarification Q5 layout; digests, fingerprints, terminal
  report, counterexample, difficulty, skipped; schema 1 sorted keys; damaged, edited and newer refused; verify replays);
  `--name host-5`
- [ ] T-R02G2202-007 [US3] [US4] Create `CoreTests/MyceliumArchitectCatalogTests.swift` (20 groups of 5 levels: witness
  replay wins within budget, minimality counts, byte-identical witness files, pinned digest, progression rule, band
  means not falling, neighbour rule, `testMyceliumArchitectContentBoundary` and `testMyceliumArchitectNoveltyBoundary`
  with seeded neighbouring-input checks) and write `docs/games/mycelium-architect/levels/001.witness.json` … `100` once
  with `MYCELIUM_ARCHITECT_WRITE_WITNESSES=1`; `--name host-6`

## Phase 5: Regression, documentation and close

- [ ] T-R02G2202-008 Docs: `docs/architecture/mycelium-architect.md` (content pipeline),
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host-1`, `-2`, `-3c`, `-3e`,
  `-3f`
- [ ] T-R02G2202-009 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`, `--name
  host-full`
- [ ] T-R02G2202-010 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G2202-011 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G2202-012 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G2202-013 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record;
  README row and gate list updated

## Dependencies and parallel work

001 → 002 → 003 (lead) → {004 (agent A), 005 (agent C), 006 (agent B)} → 007 (lead) → 008 … 013. Shared files
(kernel, manifest, difficulty, solver, generator, catalog tests, docs) stay with the lead. MVP: Stories 1 and 2.
Coverage: FR-001, 007 → 003, 005; FR-002 → 003, 004; FR-003, 005 → 003, 007; FR-004 → 006, 007; FR-006 → 002, 008 …
012; FR-008 → 007; FR-009 → 002; SC-001 … 005, 007 → 003 … 007; SC-006 → 008 … 012.
