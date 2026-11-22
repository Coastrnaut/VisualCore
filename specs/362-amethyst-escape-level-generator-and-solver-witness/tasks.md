# Tasks: R02-G07-02 — Amethyst Escape: level generator and solver witness

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G07-02 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G07-02 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Fixture seed
2_362; tests stay short (< 10 s each; catalog certification one test per band). No {owner} or {device} tasks (pure
logic); no GLSL in this feature.

## Phase 1: Setup

- [ ] T-R02G0702-001 Baselines: `--name baseline-host`, `--name baseline-timing`, `--name baseline-round02 -- swift test
  --package-path Packages/ExperiencesRound02`; the rendering baseline is R02-G07-01's rendering runs (exit 0)

## Phase 2: Foundational

- [ ] T-R02G0702-002 Add `generation(Int)` ("r02-g07.generation") and `witness(String)` ("r02-g07.witness") to
  `Packages/ExperiencesRound02/AmethystEscape/Core/AmethystEscapeError.swift`; create
  `Packages/ExperiencesRound02/AmethystEscape/Core/AmethystEscapeManifest.swift` (AmethystEscapeManifestEntry "number 1 … 100,
  seed UInt64, band 1 … 5, budget 8 … 19", the 100 entries copied from `python3 scripts/planning_index.py levels
  --experience R02-G07` with the source line) and `Packages/ExperiencesRound02/AmethystEscape/Core/AmethystEscapeDifficulty.swift` ("smallest, turns,
  advances, shells, sectors, explored"); `--name host -- swift test --package-path Packages/ExperiencesRound02 --filter
  AmethystEscape` (existing tests unchanged)

## Phase 3: Story 1 — every shipped level can be solved (P1) 🎯

- [ ] T-R02G0702-003 [US1] Implement `Packages/ExperiencesRound02/AmethystEscape/Core/AmethystEscapeSolver.swift`
  (clarification Q2: packed states (offsets and pearl as one integer, `stateCount` N^K × K × N), breadth-first search in
  the rules' move order (rotate(r, +1), rotate(r, −1) for each shell, then advance unless stuck), wedge states dead, the
  first escape is the smallest; depths (states first reached at each depth below it), work (states expanded),
  `escapesByAdvancing`; nil when no escape exists) and, after it, agent A's
  `Packages/ExperiencesRound02/AmethystEscape/CoreTests/AmethystEscapeSolverTests.swift` (seed 2_362: hand-built levels with
  known shortest routes; an inescapable level gives nil; on seeded small levels an independent brute force (depth-limited
  search over every action sequence up to the found length, written in the test) finds no escape below the solver's count
  and one at it; the solution replays to a win through the play; determinism; encode/decode round trip); `--name host-2`

## Phase 4: Story 2 — levels come from their planned seeds (P1)

- [ ] T-R02G0702-004 [US2] Create `Packages/ExperiencesRound02/AmethystEscape/Core/AmethystEscapeGenerator.swift`
  (AmethystEscapeBandProfile "6 × 2, 6 × 3, 8 × 3, 8 × 4, 10 × 4 sectors × shells; smallest 3 … 4, 5 … 6, 7 … 8, 9 … 10,
  11 … 12", `candidate(_:index:)` drawing in the order of clarification Q1 from `SeededRandom(seed:
  SeedDerivation.derive(seed, index: k))`, AmethystEscapeGenerated, `generate` with k = 0 … 511 refusing escapes by
  advances alone, smallest out of range or over budget, id `amethyst-escape-NNN`, budget = manifest budget, tutorial for
  1 … 3, difficulty = band, `.generation(number)` beyond 512; `catalogDigest`) and, after it, agent C's
  `Packages/ExperiencesRound02/AmethystEscape/CoreTests/AmethystEscapeGeneratorTests.swift` (determinism; band ranges; budget;
  the solution wins and advances alone do not; skipped recorded and re-checked; an impossible profile refused); `--name
  host-3`

## Phase 5: Stories 3 and 4 — difficulty and honest witness files (P2)

- [ ] T-R02G0702-005 [P] [US4] Create `Packages/ExperiencesRound02/AmethystEscape/Core/AmethystEscapeWitness.swift`
  (schema 1; built by replaying the solution's actions on an `AmethystEscapePlay`: the 16-hex state digest after every
  move, fingerprints after begin and each action; smallest and depths; unedited (advances alone: outcome and move) and
  near-miss (the witness minus its last action: not escaped) counterexamples; difficulty; skipped; sorted-key pretty JSON
  with a trailing newline; `decode` refuses newer, damaged and non-replaying witnesses) with
  `Packages/ExperiencesRound02/AmethystEscape/CoreTests/AmethystEscapeWitnessTests.swift` (round trip byte for byte; edited
  actions, digests, fingerprints, level, counterexamples and difficulty refused; newer schema and damaged JSON refused; the
  counterexamples behave as recorded) by agent B; `--name host-4`
- [ ] T-R02G0702-006 [US2] [US3] [US4] Create `Packages/ExperiencesRound02/AmethystEscape/CoreTests/AmethystEscapeCatalogTests.swift`
  (100 entries, 20 per band; the catalog generated twice is identical; pinned digest; `ProgressionRule.standard` holds on
  the smallest count; band means never fall; on levels 1, 11, 21, … 91 the solver equals the brute force (SC-R02G0702-002);
  all 100 witnesses replay to a win; each witness equals `docs/games/amethyst-escape/levels/NNN.witness.json` byte for byte,
  one test per band, written only with `AMETHYST_ESCAPE_WRITE_WITNESSES=1`) and generate the 100 files; `--name host-5`

## Phase 6: Regression, documentation and close

- [ ] T-R02G0702-007 Docs: `docs/architecture/amethyst-escape.md` (content pipeline), `Packages/ExperiencesRound02/README.md`,
  `docs/automatedtesting.md`; `--name round02-host`
- [ ] T-R02G0702-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`,
  `--name host-full`
- [ ] T-R02G0702-009 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G0702-010 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G0702-011 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G0702-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record

## Dependencies and parallel work

001 → 002 (lead) → 003 (lead; agent A tests) → 004 (lead; agent C tests) → {005 (agent B), 006 (lead)} → 007 … 012.
Shared files (error, manifest, solver, difficulty, generator, catalog tests, witness files, docs) stay with the lead.
MVP: Story 1.
