# Tasks: R02-G06-02 — Chrono Constellator: level generator and solver witness

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G06-02 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G06-02 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). No {owner}
or {device} tasks (pure logic and host-generated content); no GLSL (R02-G06-01's closed-form positions and evaluation are
the reference every run uses). Fixture seed 2_352; tests stay short (< 10 s each).

## Phase 1: Setup

- [X] T-R02G0602-001 Baselines: `--name baseline-host`, `--name baseline-timing`, `--name baseline-round02 -- swift test — Verified 2026-11-21: 2026-11-21 baseline-host, baseline-timing, baseline-round02 exit 0 (.autonomy/migration/checks/R02-G06-02.baseline-*.json); rendering baseline: R02-G06-01 rendering-27/26 exit 0
  --package-path Packages/ExperiencesRound02`; the rendering baseline is R02-G06-01's rendering runs (exit 0)

## Phase 2: Foundational

- [X] T-R02G0602-002 Add `generation(Int)` ("r02-g06.generation") and `witness(String)` ("r02-g06.witness") to — Verified 2026-11-21: 2026-11-21 host exit 0: the 45 ChronoConstellator tests unchanged with the new error cases (generation, witness), the 100-entry manifest (copied from the planning index, numbers 1 … 100, 20 per band) and the difficulty type (.autonomy/migration/checks/R02-G06-02.host.json); lead run
  `Packages/ExperiencesRound02/ChronoConstellator/Core/ChronoConstellatorError.swift`; create
  `Packages/ExperiencesRound02/ChronoConstellator/Core/ChronoConstellatorManifest.swift` (ChronoConstellatorManifestEntry
  "number 1 … 100, seed UInt64, band 1 … 5, budget 8 … 19", the 100 entries copied from `python3 scripts/planning_index.py
  levels --experience R02-G06` with the source line) and
  `Packages/ExperiencesRound02/ChronoConstellator/Core/ChronoConstellatorDifficulty.swift` ("smallest, win tick, stars, loop
  lengths, windows, blocked"); `--name host -- swift test --package-path Packages/ExperiencesRound02 --filter
  ChronoConstellator` (existing tests unchanged)

## Phase 3: Story 1 — every shipped level can be solved (P1) 🎯

- [X] T-R02G0602-003 [US1] Implement `Packages/ExperiencesRound02/ChronoConstellator/Core/ChronoConstellatorSolver.swift` — Verified 2026-11-21: 2026-11-21 host-2 exit 0: ChronoConstellatorSolverTests 15 tests in 1.2 s (hand-built levels needing 1, 2, 3 edits; unedited win and all-blocked levels give nil; window phases and blocked check against an independent tick check; witness replays through the play; phase-only brute force on generated, raw and random levels and single-hold brute force on m* ≤ 3 levels find no smaller win) (.autonomy/migration/checks/R02-G06-02.host-2.json); lead retest
  (clarification Q2: `misaligned(_:at:)` m(T); the lower bound m* = min m(T) over T = 1 … tick limit, nil when 0; the
  windows T with m(T) = m* in order; `windowPhases` "(index of target − T) mod L" for each star off target, default
  otherwise; `isBlocked` when two stars share a cell on a tick 1 … T under the window's phase-only timeline; the first
  unblocked window is the solution, nil when every window is blocked; windows, blocked and work counted) and, after it,
  agent A's `Packages/ExperiencesRound02/ChronoConstellator/CoreTests/ChronoConstellatorSolverTests.swift` (seed 2_352:
  hand-built levels needing 1, 2 and 3 edits; a level won unedited gives nil; a level with every window blocked gives nil;
  on seeded small levels an independent brute force over every phase-only timeline of at most m* edits, replayed to the
  tick limit, finds no win below m* and one at m*; on band 1–2 sized levels (m* ≤ 2) the brute force also adds every single
  hold of starts 1 … 32 and lengths 1 … 32 (the lower-bound argument of clarification Q2 covers holds on every level); the solution replays to a win through the play;
  determinism); `--name host-2`

## Phase 4: Story 2 — levels come from their planned seeds (P1)

- [X] T-R02G0602-004 [US2] Create `Packages/ExperiencesRound02/ChronoConstellator/Core/ChronoConstellatorGenerator.swift` — Verified 2026-11-21: 2026-11-21 host-3 exit 0: ChronoConstellatorGeneratorTests 9 tests in 0.87 s (band profiles, rectangle loops, determinism, band shape, solutions in range and witness wins, skipped candidates truly fail, difficulty consistent, impossible entries refused) (.autonomy/migration/checks/R02-G06-02.host-3.json); lead retest
  (ChronoConstellatorBandProfile "grid 6 × 5, 6 × 5, 7 × 6, 7 × 6, 8 × 7; stars 2, 3, 3, 4, 5; smallest 1, 2, 2, 3, 3 … 4;
  blocked at least 0, 1, 2, 2, 3", `candidate(_:index:)` drawing in the order of clarification Q1 from
  `SeededRandom(seed: SeedDerivation.derive(seed, index: k))` (rectangle loops, direction, distinct targets, phases,
  tick limit 120 … 360), ChronoConstellatorGenerated, `generate` with k = 0 … 511, id `chrono-constellator-NNN`, budget =
  manifest budget, tutorial for 1 … 3, difficulty = band, `.generation(number)` beyond 512; `catalogDigest`) and, after
  it, agent C's `Packages/ExperiencesRound02/ChronoConstellator/CoreTests/ChronoConstellatorGeneratorTests.swift`
  (determinism; band ranges; budget; the solution wins and the unedited level fails; skipped recorded and re-checked; an
  impossible profile refused); `--name host-3`

## Phase 5: Stories 3 and 4 — difficulty and honest witness files (P2)

- [X] T-R02G0602-005 [P] [US4] Create `Packages/ExperiencesRound02/ChronoConstellator/Core/ChronoConstellatorWitness.swift` — Verified 2026-11-21: 2026-11-21 host-4 exit 0: ChronoConstellatorWitnessTests 16 tests in 0.35 s (byte round trip, digests and fingerprints from replay, counterexamples fail as recorded, every edited part and newer, damaged JSON refused) (.autonomy/migration/checks/R02-G06-02.host-4.json); lead retest
  (schema 1; actions: the solution's phase changes in star order, then step(tick limit); built by replaying them on a
  `ChronoConstellatorPlay`: win tick, the 16-hex position digest after every tick up to the win, fingerprints after begin
  and each action; the lower bound, window, windows and blocked; unedited and near-miss counterexamples (reason, tick);
  difficulty; skipped; sorted-key pretty JSON with a trailing newline; `decode` refuses newer, damaged and non-replaying
  witnesses) with `Packages/ExperiencesRound02/ChronoConstellator/CoreTests/ChronoConstellatorWitnessTests.swift` (round
  trip byte for byte; edited actions, digests, fingerprints, level, counterexamples and difficulty refused; newer schema and
  damaged JSON refused; the counterexamples fail as recorded) by agent B; `--name host-4`
- [X] T-R02G0602-006 [US2] [US3] [US4] Create — Verified 2026-11-21: 2026-11-21 host-5 exit 0: ChronoConstellatorCatalogTests 7 tests in 1.2 s (100 entries, pinned digest 6483b20e…, progression and band means, all 100 witnesses win through the play and fail unedited, brute force on levels 1, 11, … 91, 100 witness files byte for byte) (.autonomy/migration/checks/R02-G06-02.host-5.json); difficulty gains puzzleDifficulty, generator levelID; 100 witness files generated with CHRONO_CONSTELLATOR_WRITE_WITNESSES=1
  `Packages/ExperiencesRound02/ChronoConstellator/CoreTests/ChronoConstellatorCatalogTests.swift` (100 entries, 20 per
  band; the catalog generated twice is identical; pinned digest; `ProgressionRule.standard` holds on the smallest count;
  band means never fall; on levels 1, 11, 21, … 91 the solver equals the phase-only brute force, with holds added on the band 1–2 samples
  (SC-R02G0602-002); all 100 witnesses
  replay to a win; each witness equals `docs/games/chrono-constellator/levels/NNN.witness.json` byte for byte, one test per
  band, written only with `CHRONO_CONSTELLATOR_WRITE_WITNESSES=1`) and generate the 100 files; `--name host-5`

## Phase 6: Regression, documentation and close

- [X] T-R02G0602-007 Docs: `docs/architecture/chrono-constellator.md` (content pipeline), — Verified 2026-11-21: 2026-11-21 round02-host exit 0 (.autonomy/migration/checks/R02-G06-02.round02-host.json); architecture content pipeline, package README, testing doc (certify by a lower bound; separate witness write run)
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host`
- [X] T-R02G0602-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`, — Verified 2026-11-21: 2026-11-21 rendering-27, rendering-26, experiences, host-full exit 0 (.autonomy/migration/checks/R02-G06-02.*.json)
  `--name host-full`
- [X] T-R02G0602-009 Reference regression chunk 1 (`--name reference-1`) — Verified 2026-11-21: 2026-11-21 reference-1 exit 0 (.autonomy/migration/checks/R02-G06-02.reference-1.json)
- [X] T-R02G0602-010 Reference regression chunk 2 (`--name reference-2`) — Verified 2026-11-21: 2026-11-21 reference-2 exit 1 (projectm-reference-ios26 square preset within8 0.9695 vs required 0.9696, run-to-run variance; kept in evidence), reference-2-2 exit 0 (0.9752 vs 0.9675) (.autonomy/migration/checks/R02-G06-02.reference-2.json, .autonomy/migration/checks/R02-G06-02.reference-2-2.json); testing doc lesson added
- [X] T-R02G0602-011 Script tests, run alone (`--name script-tests`) — Verified 2026-11-21: 2026-11-21 script-tests exit 0, run alone after the chain (.autonomy/migration/checks/R02-G06-02.script-tests.json)
- [X] T-R02G0602-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record — Verified 2026-11-21: 2026-11-21 converge round 1 appended T-013 (contract), implemented; converge round 2 clean; sealed 17 passing, 1 failed attempt kept; recorded pass (.autonomy/migration/evidence/R02-G06-02.json); README updated

## Dependencies and parallel work

001 → 002 (lead) → 003 solver (lead) → {003 tests (agent A), 004 generator (lead) → 004 tests (agent C), 005 (agent B)} →
006 (lead) → 007 … 012. Agent B codes against the solution contract with hand-made solutions; shared files (error,
manifest, difficulty, solver, generator, catalog tests, witness files, docs) stay with the lead. MVP: Story 1.

## Phase 7: Convergence

- [X] T-R02G0602-013 Bring `specs/352-chrono-constellator-level-generator-and-solver-witness/contracts/api.md` and `specs/352-chrono-constellator-level-generator-and-solver-witness/data-model.md` in line with the code: `ChronoConstellatorCounterexample` (actions, the full `ChronoConstellatorFailure` reason, tick), `ChronoConstellatorDifficulty.puzzleDifficulty` (explored = windows), `ChronoConstellatorGenerator.levelID`, `rectangle`, `winTick`, `timeline`, `catalogID`, and the witness helpers `phaseChanges(for:level:)`, `actions(for:level:)`, `digest(_:)` with its byte layout per plan: contracts (partial) — Verified 2026-11-21: 2026-11-21 contracts/api.md and data-model.md list ChronoConstellatorCounterexample (full failure), puzzleDifficulty, levelID, rectangle, winTick, timeline, catalogID and the witness helpers with the digest byte layout; docs exit 0 (.autonomy/migration/checks/R02-G06-02.docs.json)
