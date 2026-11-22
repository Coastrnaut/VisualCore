# Tasks: R02-G09-02 — Nocturne Garden: level generator and solver witness

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G09-02 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G09-02 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Fixture seed
2_382; tests stay short (< 10 s each; catalog certification in groups of 5 levels). No {owner} or {device} tasks (pure
logic); no GLSL in this feature.

## Phase 1: Setup

- [X] T-R02G0902-001 Baselines: `--name baseline-host`, `--name baseline-timing`, `--name baseline-round02 -- swift test — Verified 2026-11-22: baseline-host, baseline-timing, baseline-round02 exit=0 (run on the committed tree with the feature's work held aside); rendering baseline is R02-G09-01's rendering runs (exit 0)
  --package-path Packages/ExperiencesRound02`; the rendering baseline is R02-G09-01's rendering runs (exit 0)

## Phase 2: Foundational

- [X] T-R02G0902-002 Add `generation(Int)` ("r02-g09.generation") and `witness(String)` ("r02-g09.witness") to — Verified 2026-11-22: host exit=0 (78 Nocturne Garden tests: kernel suites unchanged, generation and witness refusals, manifest of 100 entries, difficulty)
  `Packages/ExperiencesRound02/NocturneGarden/Core/NocturneGardenError.swift` (no other kernel change: generated levels stay inside R02-G09-01's ranges);
  create `Packages/ExperiencesRound02/NocturneGarden/Core/NocturneGardenManifest.swift` (NocturneGardenManifestEntry "number 1 … 100, seed UInt64, band 1 … 5,
  budget 8 … 19", the 100 entries copied from `python3 scripts/planning_index.py levels --experience R02-G09` with the
  source line) and `Packages/ExperiencesRound02/NocturneGarden/Core/NocturneGardenDifficulty.swift` ("smallest, kinds, sizes, sunChange, targetCells,
  forbiddenCells, required, work"); `--name host -- swift test --package-path Packages/ExperiencesRound02 --filter
  NocturneGarden` (existing tests unchanged)

## Phase 3: Story 1 — every shipped level can be solved (P1) 🎯

- [X] T-R02G0902-003 [US1] Implement `Packages/ExperiencesRound02/NocturneGarden/Core/NocturneGardenSolver.swift` (clarification Q2: `needed` = least s with — Verified 2026-11-22: host-2 exit=0 (NocturneGardenSolverTests 9: needed, stamp equals bloom cells, single bloom, sun move first, unreachable target nil, candidates solve at the bound and not one short, brute-force cover, determinism, work bound; agent A's tests retested by the lead)
  s·q ≥ p·|T|; `cover(e)` = largest |cells ∩ T| of one plant at e (supplied kinds, allowed sizes, anchors) with leak
  within the allowance; `lowerBound` L = min over allowed e ascending of [e ≠ opening] + ⌈needed / cover⌉;
  depth-first search per elevation for exactly L moves: a sun move first when needed, then plants ordered by shape score
  (cells in T minus cells outside T, then the rules' plant order), pruned when shared + remaining · cover < needed or the
  leak exceeds the allowance, never continuing from a failed state; work = plant evaluations, bound 20,000; nil when
  none found within the bound) and, after it, agent A's `Packages/ExperiencesRound02/NocturneGarden/CoreTests/NocturneGardenSolverTests.swift` (seed 2_382:
  hand-built levels with known answers; an unreachable target gives nil; the solution's length equals the lower bound;
  the solution replays to a win through the play; the independent check (brute-force cover over all single plants, and
  replay on a fresh play); determinism; work bound honoured); `--name host-2`

## Phase 4: Story 2 — levels come from their planned seeds (P1)

- [X] T-R02G0902-004 [US2] Create `Packages/ExperiencesRound02/NocturneGarden/Core/NocturneGardenGenerator.swift` (NocturneGardenBandProfile "band 1: 16 × 12, smallest 2 … 3, — Verified 2026-11-22: host-3 exit=0 (NocturneGardenGeneratorTests 9: manifest shape, band profiles, candidate determinism and shape, 8 entries certified with skipped candidates re-checked, determinism, difficulty, reason codes, digest; agent C's tests retested by the lead)
  sizes {2}, elevations {2, 3}, 1 … 2 blooms, ring 1 kept 1/2, match 4/5, allowance 2, no decoy; band 2: 20 × 14, 3 … 4, {1, 2},
  {2, 3}, 2 … 3, ring 1 · 1/2, 17/20, 2, no; band 3: 24 × 16, 4 … 5, {1, 2, 3}, {1 … 4}, 3 … 4, ring 2 · 3/4, 9/10, 1, decoy;
  band 4: 28 × 20, 5 … 6, all, all, 4 … 5, ring 2 · 3/4, 19/20, 1, decoy; band 5: 32 × 24, 6 … 7, all, all, 5 … 6, ring 2 · 3/4, 1/1, 0,
  decoy", `candidate(_:index:)` drawing in the order of clarification Q1 from `SeededRandom(seed:
  SeedDerivation.derive(seed, index: k))`, one size per candidate, each bloom wholly in the bed adding at least 3 new cells, target = their
  exact mask, NocturneGardenGenerated, `generate` with k = 0 … 255 keeping a candidate only when the solver certifies it
  in the band's smallest range and within the budget, id `nocturne-garden-NNN`, budget = manifest budget, tutorial for 1 … 3, difficulty = band,
  `.generation(number)` beyond 256; `catalogDigest` via `PuzzleCatalog.digest(id: "nocturne-garden", identities:)`)
  and, after it, agent C's `Packages/ExperiencesRound02/NocturneGarden/CoreTests/NocturneGardenGeneratorTests.swift` (determinism; band profiles; filters;
  budget; the solution wins; skipped recorded and re-checked; an impossible profile refused); `--name host-3`

## Phase 5: Stories 3 and 4 — difficulty and honest witness files (P2)

- [X] T-R02G0902-005 [P] [US4] Create `Packages/ExperiencesRound02/NocturneGarden/Core/NocturneGardenWitness.swift` (schema 1; built by replaying the — Verified 2026-11-22: host-4 exit=0 (NocturneGardenWitnessTests 14: byte-for-byte round trip, digest layout, near miss, every edited part refused by name, newer and damaged refused, make refusals; agent B's files retested by the lead)
  solution's actions on a `NocturneGardenPlay`: the 16-hex mask digest after every action, fingerprints after begin and
  each action; smallest and the bound (elevation, needed, cover); the near miss (the witness minus its last action: not
  won, shared below needed); difficulty; skipped; sorted-key pretty JSON with a trailing newline; `decode` refuses
  newer, damaged and non-replaying witnesses) with `Packages/ExperiencesRound02/NocturneGarden/CoreTests/NocturneGardenWitnessTests.swift` (round trip byte
  for byte; edited actions, digests, fingerprints, level, near miss and difficulty refused; newer schema and damaged JSON
  refused; the near miss behaves as recorded) by agent B; `--name host-4`
- [X] T-R02G0902-006 [US2] [US3] [US4] Create `Packages/ExperiencesRound02/NocturneGarden/CoreTests/NocturneGardenCatalogTests.swift` (100 entries, 20 per — Verified 2026-11-22: host-5 exit=0 (NocturneGardenCatalogTests 8: manifest, pinned digest ce13750a…, progression and band means, 100 witnesses win at the lower bound and are not won one move short, independent brute-force bound on two levels per band, full decode per band, 100 files byte for byte in 20 groups of 5; suite 11.3 s locally, slowest single test 6.1 s)
  band; the catalog generated twice is identical; pinned digest; `ProgressionRule.standard` holds on the smallest
  count; band means never fall; the independent check on two levels per band (SC-R02G0902-002); all 100 witnesses
  replay to a win; each witness equals `docs/games/nocturne-garden/levels/NNN.witness.json` byte for byte, in groups of
  5 levels, written only with `NOCTURNE_GARDEN_WRITE_WITNESSES=1`) and generate the 100 files; `--name host-5`

## Phase 6: Regression, documentation and close

- [X] T-R02G0902-007 Docs: `docs/architecture/nocturne-garden.md` (content pipeline), — Verified 2026-11-22: round02-host (swift test --package-path Packages/ExperiencesRound02) exit 0; docs/architecture/nocturne-garden.md content pipeline, ExperiencesRound02 README feature 382, docs/automatedtesting.md entry; validate_docs passes
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host`
- [X] T-R02G0902-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`, — Verified 2026-11-22: 2026-11-22: rendering-27, rendering-26, experiences, host-full exit 0
  `--name host-full`
- [X] T-R02G0902-009 Reference regression chunk 1 (`--name reference-1`) — Verified 2026-11-22: 2026-11-22: reference-1 exit 0
- [X] T-R02G0902-010 Reference regression chunk 2 (`--name reference-2`) — Verified 2026-11-22: 2026-11-22: reference-2 exit 0
- [X] T-R02G0902-011 Script tests, run alone (`--name script-tests`) — Verified 2026-11-22: 2026-11-22: script-tests (run alone) exit 0
- [ ] T-R02G0902-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record

## Dependencies and parallel work

001 → 002 (lead) → 003 (lead; agent A tests) → 004 (lead; agent C tests) → {005 (agent B), 006 (lead)} → 007 … 012.
Shared files (error, manifest, solver, difficulty, generator, catalog tests, witness files, docs) stay with the lead.
MVP: Story 1.
