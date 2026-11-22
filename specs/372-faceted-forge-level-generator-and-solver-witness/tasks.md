# Tasks: R02-G08-02 — Faceted Forge: level generator and solver witness

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G08-02 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G08-02 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Fixture seed
2_372; tests stay short (< 10 s each; catalog certification in groups of 5 levels). No {owner} or {device} tasks (pure
logic); no GLSL in this feature.

## Phase 1: Setup

- [X] T-R02G0802-001 Baselines: `--name baseline-host`, `--name baseline-timing`, `--name baseline-round02 -- swift test — Verified 2026-11-22: baseline-host, baseline-timing, baseline-round02 exit=0; rendering baseline is R02-G08-01's rendering runs (exit 0)
  --package-path Packages/ExperiencesRound02`; the rendering baseline is R02-G08-01's rendering runs (exit 0)

## Phase 2: Foundational

- [X] T-R02G0802-002 Add `generation(Int)` ("r02-g08.generation") and `witness(String)` ("r02-g08.witness") to — Verified 2026-11-22: host exit=0 (FacetedForge suites with generation and witness errors, widened budget 1 … 20 and faces 4 … 34, manifest of 100 entries, difficulty)
  `Packages/ExperiencesRound02/FacetedForge/Core/FacetedForgeError.swift`; widen `FacetedForgeLevel.budgets` to 1 … 20
  and `faceCounts` to 4 … 34 in `Packages/ExperiencesRound02/FacetedForge/Core/FacetedForgeLevel.swift` (additive: every
  earlier level stays valid); create `Packages/ExperiencesRound02/FacetedForge/Core/FacetedForgeManifest.swift`
  (FacetedForgeManifestEntry "number 1 … 100, seed UInt64, band 1 … 5, budget 8 … 19", the 100 entries copied from
  `python3 scripts/planning_index.py levels --experience R02-G08` with the source line) and
  `Packages/ExperiencesRound02/FacetedForge/Core/FacetedForgeDifficulty.swift` ("smallest, directions, diagonals,
  crystal faces, pieces, work"); `--name host -- swift test --package-path Packages/ExperiencesRound02 --filter
  FacetedForge` (existing tests unchanged)

## Phase 3: Story 1 — every shipped level can be solved (P1) 🎯

- [X] T-R02G0802-003 [US1] Implement `Packages/ExperiencesRound02/FacetedForge/Core/FacetedForgeSolver.swift` — Verified 2026-11-22: host-2 exit=0 (FacetedForgeSolverTests 10: hand-built answers, unreachable targets nil, canPartition rules, determinism, work bound honoured, 40 fixtures solved at the lower bound, independent breadth-first check on small levels)
  (clarification Q2: `lowerBound` = target pieces − 1; `canPartition` of pieces into the remaining target by exact share
  subset sums with a one-entry piece matching its face count; depth-first search from the crystal alone in the rules'
  order (pieces in canonical order, directions 0 … 12, depths ascending), halves at least the sliver limit, pruned by
  `canPartition`; work = cut evaluations, bound 20,000; nil when none found within the bound) and, after it, agent A's
  `Packages/ExperiencesRound02/FacetedForge/CoreTests/FacetedForgeSolverTests.swift` (seed 2_372: hand-built levels with
  known solutions; an unreachable target gives nil; the solution's length equals the lower bound; the solution replays
  to a win through the play; the independent check (recount and replay, and a bounded breadth-first search over P − 2
  cuts on small levels finds no win); determinism; work bound honoured); `--name host-2`

## Phase 4: Story 2 — levels come from their planned seeds (P1)

- [X] T-R02G0802-004 [US2] Create `Packages/ExperiencesRound02/FacetedForge/Core/FacetedForgeGenerator.swift` — Verified 2026-11-22: host-3 exit=0 (FacetedForgeGeneratorTests 11: manifest shape, band profiles, determinism, generated shape and filters, crystals by band, solutions win, skipped re-checked, difficulty, impossible entry refused)
  (FacetedForgeBandProfile "band 1 cube, 2 … 3 cuts, axes and face diagonals; 2 box, 3 … 4; 3 truncated cube, 4 … 5, all
  13; 4 octahedron, 5 … 6; 5 doubly truncated cube, 6 … 7", `candidate(_:index:)` drawing in the order of clarification
  Q1 from `SeededRandom(seed: SeedDerivation.derive(seed, index: k))`, sliver 1/64, shares at least 1/32, bands 3 … 5
  with a body diagonal, FacetedForgeGenerated, `generate` with k = 0 … 255 keeping a candidate only when the solver
  certifies it, id `faceted-forge-NNN`, budget = manifest budget, tutorial for 1 … 3, difficulty = band,
  `.generation(number)` beyond 256; `catalogDigest`) and, after it, agent C's
  `Packages/ExperiencesRound02/FacetedForge/CoreTests/FacetedForgeGeneratorTests.swift` (determinism; band ranges;
  filters; budget; the solution wins; skipped recorded and re-checked; an impossible profile refused); `--name host-3`

## Phase 5: Stories 3 and 4 — difficulty and honest witness files (P2)

- [X] T-R02G0802-005 [P] [US4] Create `Packages/ExperiencesRound02/FacetedForge/Core/FacetedForgeWitness.swift` (schema — Verified 2026-11-22: host-4 exit=0 (FacetedForgeWitnessTests 14: byte-for-byte round trip, solver values, digests and fingerprints, near miss, every edited part refused by name, newer and damaged refused)
  1; built by replaying the solution's cuts on a `FacetedForgePlay`: the 16-hex state digest after every cut,
  fingerprints after begin and each cut; smallest and the lower bound; the near-miss counterexample (the witness minus
  its last cut: not won); difficulty; skipped; sorted-key pretty JSON with a trailing newline; `decode` refuses newer,
  damaged and non-replaying witnesses) with
  `Packages/ExperiencesRound02/FacetedForge/CoreTests/FacetedForgeWitnessTests.swift` (round trip byte for byte; edited
  cuts, digests, fingerprints, level, counterexample and difficulty refused; newer schema and damaged JSON refused; the
  counterexample behaves as recorded) by agent B; `--name host-4`
- [X] T-R02G0802-006 [US2] [US3] [US4] Create — Verified 2026-11-22: host-5 exit=0 (FacetedForgeCatalogTests 8: manifest, pinned digest ceb59042…, progression and band means, 100 witnesses win at the lower bound and are open one cut short, independent recount on two levels per band, full decode per band, 100 files byte for byte in 20 groups of 5)
  `Packages/ExperiencesRound02/FacetedForge/CoreTests/FacetedForgeCatalogTests.swift` (100 entries, 20 per band; the
  catalog generated twice is identical; pinned digest; `ProgressionRule.standard` holds on the smallest count; band
  means never fall; the independent check on two levels per band (SC-R02G0802-002); all 100 witnesses replay to a win;
  each witness equals `docs/games/faceted-forge/levels/NNN.witness.json` byte for byte, in groups of 5 levels, written
  only with `FACETED_FORGE_WRITE_WITNESSES=1`) and generate the 100 files; `--name host-5`

## Phase 6: Regression, documentation and close

- [ ] T-R02G0802-007 Docs: `docs/architecture/faceted-forge.md` (content pipeline),
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host`
- [ ] T-R02G0802-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`,
  `--name host-full`
- [ ] T-R02G0802-009 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G0802-010 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G0802-011 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G0802-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record

## Dependencies and parallel work

001 → 002 (lead) → 003 (lead; agent A tests) → 004 (lead; agent C tests) → {005 (agent B), 006 (lead)} → 007 … 012.
Shared files (error, level, manifest, solver, difficulty, generator, catalog tests, witness files, docs) stay with the
lead. MVP: Story 1.
