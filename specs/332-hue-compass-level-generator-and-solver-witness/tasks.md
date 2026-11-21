# Tasks: R02-G04-02 — Hue Compass: level generator and solver witness

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G04-02 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G04-02 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). No {owner}
or {device} tasks (pure logic and host-generated content). Fixture seed 2_332; tests stay short (< 10 s each).

## Phase 1: Setup

- [X] T-R02G0402-001 Baselines: `--name baseline-host`, `--name baseline-timing`, `--name baseline-round02 -- swift test — Verified 2026-11-21: 2026-11-21 R02-G04-02.baseline-host/timing/round02 exit 0
  --package-path Packages/ExperiencesRound02`; the rendering baseline is R02-G04-01's rendering runs (exit 0)

## Phase 2: Foundational

- [X] T-R02G0402-002 Add `generation(Int)` ("r02-g04.generation") and `witness(String)` ("r02-g04.witness") to — Verified 2026-11-21: 2026-11-21 host exit 0 (whole round-two package with the error cases, the 100-entry manifest, difficulty with band profiles and the generated type, and the solver's result types)
  `Packages/ExperiencesRound02/HueCompass/Core/HueCompassError.swift`; create `Packages/ExperiencesRound02/HueCompass/Core/HueCompassManifest.swift` (HueCompassManifestEntry "number 1 … 100,
  seed UInt64, band 1 … 5, budget 8 … 19", the 100 entries copied from `python3 scripts/planning_index.py levels
  --experience R02-G04` with the source line), `Packages/ExperiencesRound02/HueCompass/Core/HueCompassDifficulty.swift` ("smallest, largest class after the
  best single probe, bearing and band tolerance, clear share, work") and the `HueCompassSolution` and
  `HueCompassAmbiguity` types in `Packages/ExperiencesRound02/HueCompass/Core/HueCompassSolver.swift` as the contract states (solver body by agent A);
  `--name host -- swift test --package-path Packages/ExperiencesRound02` (existing tests unchanged)

## Phase 3: Story 1 — every shipped level can be deduced (P1) 🎯

- [X] T-R02G0402-003 [P] [US1] Implement `HueCompassSolver` in `Packages/ExperiencesRound02/HueCompass/Core/HueCompassSolver.swift` (clarification Q2: — Verified 2026-11-21: 2026-11-21 host-2 exit 0 (agent A: 10 solver tests: hand-made levels needing 1, 2 and more than 2 probes, a 0-probe level proven impossible (at least 87 candidates), equal to an independent brute force on 40 seeded levels, soundness and real ambiguities, work bound, determinism; about 7 ms per solve)
  candidates farther from the start than the bearing tolerance; classes by clues at the probe bearings via a 96 × 96 clue
  table; a class acceptable when its circular bearing span ≤ 2 × bearing tolerance and band span ≤ 2 × band tolerance;
  the empty set, then singles, then pairs in lexicographic order; work = sets tried ≤ 4,657; best single bearing and its
  largest class; the ambiguity counterexample; `selection(for:in:)` the smallest acceptable bearing then band) with
  `Packages/ExperiencesRound02/HueCompass/CoreTests/HueCompassSolverTests.swift` (seed 2_332: hand-built levels needing 0, 1 and 2 probes; a level not
  settled within depth 2 gives nil; the smallest count equals an independent brute force over sets and selections on
  seeded levels; soundness: every consistent target is accepted by its class's selection; the ambiguity's two targets
  share clues and no selection accepts both; work bound; determinism); `--name host-2`

## Phase 4: Story 2 — levels come from their planned seeds (P1)

- [X] T-R02G0402-004 [US2] Create `Packages/ExperiencesRound02/HueCompass/Core/HueCompassGenerator.swift` (HueCompassBandProfile "tolerances (4, 2), (3, 1), — Verified 2026-11-21: 2026-11-21 host-3 exit 0 (generator, 5 tests: profiles tighten by band, candidates deterministic, band ranges and budgets met, skipped candidates re-checked as not qualifying, impossible profile refused as generation(1); all 100 levels generate, band 5 skipping at most 4)
  (2, 1), (1, 0), (1, 0); clear share 0, 10, 20, 30, 40 %; smallest 1, 1, 1, 1 … 2, 2", `candidate(_:index:)` drawing
  offset, fog, target and start in that order from `SeededRandom(seed: SeedDerivation.derive(seed, index: k))`,
  HueCompassGenerated, `generate` with k = 0 … 63, id `hue-compass-NNN`, allowance = budget, tutorial for 1 … 3,
  `.generation(number)` beyond 64, a candidate without both counterexamples skipped; `catalogDigest`) with
  `Packages/ExperiencesRound02/HueCompass/CoreTests/HueCompassGeneratorTests.swift` (determinism; band ranges; budget; skipped recorded and re-checked;
  impossible profile refused); `--name host-3`

## Phase 5: Stories 3 and 4 — difficulty and honest witness files (P2)

- [X] T-R02G0402-005 [P] [US4] Create `Packages/ExperiencesRound02/HueCompass/Core/HueCompassWitness.swift` (schema 1; actions: for each probe bearing the — Verified 2026-11-21: 2026-11-21 host-4 exit 0 (agent B: 9 witness tests: byte round trip, canonical actions, near miss fails, ambiguity holds, newer and damaged refused, every edited part refused; decode re-derives everything without the solver)
  shortest turn when not zero, then the probe, then the selection; built by replaying them on a `HueCompassPlay`: clues,
  candidate counts after each probe, fingerprints after begin and each action; near miss and ambiguity per clarification
  Q4; sorted-key pretty JSON with a trailing newline; `decode` refuses newer, damaged and non-replaying witnesses) with
  `Packages/ExperiencesRound02/HueCompass/CoreTests/HueCompassWitnessTests.swift` (round trip byte for byte; edited action, fingerprint, level, clue,
  counts, counterexamples and difficulty refused; newer schema and damaged JSON refused; the near miss fails; the
  ambiguity holds); `--name host-4`
- [ ] T-R02G0402-006 [US2] [US3] [US4] Create `Packages/ExperiencesRound02/HueCompass/CoreTests/HueCompassCatalogTests.swift` (100 entries, 20 per band; the
  catalog generated twice is identical; pinned digest; `ProgressionRule.standard` holds on the smallest count; band means
  of the smallest count never fall and tolerances never loosen; on levels 1, 11, 21, … 91 the smallest count equals the
  brute force (SC-R02G0402-002); for all 100 levels every class after the witness
  probes is accepted by its selection (soundness, SC-R02G0402-001); each witness equals `docs/games/hue-compass/levels/NNN.witness.json` byte for byte, one
  test per band, written only with `HUE_COMPASS_WRITE_WITNESSES=1`) and generate the 100 files; `--name host-5`

## Phase 6: Regression, documentation and close

- [ ] T-R02G0402-007 Docs: `docs/architecture/hue-compass.md` (content pipeline), `Packages/ExperiencesRound02/README.md`,
  `docs/automatedtesting.md`; `--name round02-host`
- [ ] T-R02G0402-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`,
  `--name host-full`
- [ ] T-R02G0402-009 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G0402-010 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G0402-011 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G0402-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record

## Dependencies and parallel work

001 → 002 (lead) → {003 (agent A), 005 (agent B)} → 004 (lead, needs the solver) → 006 → 007 … 012. Agent B codes against
the solution contract with hand-made solutions; shared files (error, manifest, difficulty, generator, catalog tests,
witness files, docs) stay with the lead. MVP: Story 1.
