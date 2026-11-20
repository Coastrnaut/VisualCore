# Tasks: R02-G02-01 — Lissajous Labyrinth: playable rule kernel

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G02-01 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G02-01 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). No {owner}
or {device} tasks (pure logic). Fixture seed 2_311; tests stay short (< 10 s each).

## Phase 1: Setup

- [X] T-R02G0201-001 Baselines: `--name baseline-host -- swift test --package-path Packages/VisualCore`, the isolated — Verified 2026-11-20: 2026-11-20 baseline-host, baseline-timing exit 0; baseline-round02 exit 0 (Aurora Loom's 59 tests unchanged); rendering baseline R02-G01-02 rendering-27/26 exit 0 (.autonomy/migration/checks/R02-G02-01.baseline-*.json)
  timing run (`--name baseline-timing`) and `--name baseline-round02 -- swift test --package-path
  Packages/ExperiencesRound02`; the rendering baseline is R02-G01-02's rendering runs (exit 0)

## Phase 2: Foundational

- [X] T-R02G0201-002 Add product and targets `LissajousLabyrinthCore` (`LissajousLabyrinth/Core`, depending on — Verified 2026-11-20: 2026-11-20 host exit 0: LissajousLabyrinthLevelTests 4/4 (sine table pinned aa21b9ef…8c79 and within half a unit of sin; refusals and codes; 200 fixtures won by their safe setting and not at the start; round trip byte for byte; newer, edited, invalid, truncated, old forms refused) (.autonomy/migration/checks/R02-G02-01.host.json)
  VisualCoreSimulation and VisualCoreMath) and `LissajousLabyrinthCoreTests` (`LissajousLabyrinth/CoreTests`) to
  `Packages/ExperiencesRound02/Package.swift`; create `Packages/ExperiencesRound02/LissajousLabyrinth/Core/LissajousLabyrinthError.swift`,
  `Packages/ExperiencesRound02/LissajousLabyrinth/Core/LissajousLabyrinthSine.swift` (4,096 entries "round(1,024 · sin(2πk/4,096))", `sin`, `cos`,
  `tableDigest`), `Packages/ExperiencesRound02/LissajousLabyrinth/Core/LissajousLabyrinthLevel.swift` (LissajousLabyrinthBall "each coordinate −5,000 … 5,000;
  radius 64 … 1,024", LissajousLabyrinthDial, LissajousLabyrinthDials "frequencies 1 … 9 coprime; phases 0 … 15",
  LissajousLabyrinthLevel "id slug; band 1 … 5; amplitudes 3 × 1 … 4; frequencyC 1 … 9; checkpoints 1 … 6; obstacles
  0 … 8; allowance 1 … 64; start valid and not winning; schema 1", fingerprint, stored form),
  `Packages/ExperiencesRound02/LissajousLabyrinth/Core/LissajousLabyrinthLap.swift` (position, exact segment contact, verdict with ties by tick then obstacle),
  `Packages/ExperiencesRound02/LissajousLabyrinth/CoreTests/LissajousLabyrinthFixtures.swift` (seeded levels with a known safe setting) and
  `Packages/ExperiencesRound02/LissajousLabyrinth/CoreTests/LissajousLabyrinthLevelTests.swift` (table digest pinned and within one unit of sin; refusals and codes;
  round trip; damaged, edited and newer forms refused; 200 fixtures won by their safe setting and not at the start);
  `--name host -- swift test --package-path Packages/ExperiencesRound02 --filter LissajousLabyrinthLevelTests`

## Phase 3: Story 1 — tune the tracer through every checkpoint (P1) 🎯

- [X] T-R02G0201-003 [P] [US1] Create `Packages/ExperiencesRound02/LissajousLabyrinth/CoreTests/LissajousLabyrinthLapTests.swift` (500 seeded levels: the safe setting — Verified 2026-11-20: 2026-11-20 host-2 exit 0: LissajousLabyrinthLapTests 8/8 (500 safe settings win; every valid single-dial change on 50 levels agrees with an independent exact reference; surface boundaries for checkpoints and segments; closing segment 4095; order; ties; period) (.autonomy/migration/checks/R02-G02-01.host-2.json)
  wins; every single-dial change on the first 50 agrees with an independent reference written in the test; checkpoint
  boundary inclusive and obstacle boundary exclusive at the surface and one unit either side; the closing segment;
  out-of-order and missed checkpoints; tie order of contacts; the path closes after 4,096 ticks); `--name host-2`

## Phase 4: Stories 2, 3 and 4 — allowance, undo, replay and life stages (P1, P2)

- [X] T-R02G0201-004 [P] [US2] [US3] [US4] Create `Packages/ExperiencesRound02/LissajousLabyrinth/Core/LissajousLabyrinthPlay.swift` (stages and events, actions with — Verified 2026-11-20: 2026-11-20 host-3 exit 0: LissajousLabyrinthPlayTests 11/11 (500 traces replay; undo restores every earlier state; 1,000 refused attempts change nothing; safe dials win; spending the allowance fails with the verdict; stage table; tutorial) (.autonomy/migration/checks/R02-G02-01.host-3.json)
  validation "range, no-change, not-coprime", records, undo with refund, redo, replay, fingerprints) with
  `Packages/ExperiencesRound02/LissajousLabyrinth/CoreTests/LissajousLabyrinthPlayTests.swift` (500 seeded traces replay to identical fingerprints and outcome; undo of
  every action restores the exact state; 1,000 seeded refused actions leave state and fingerprint unchanged; spending the
  allowance fails with the verdict named; stage table; no action after the end); `--name host-3`

## Phase 5: Solver-ready rules (P2)

- [X] T-R02G0201-005 [P] [US1] Create `Packages/ExperiencesRound02/LissajousLabyrinth/Core/LissajousLabyrinthRules.swift` (PuzzleRules, rules id — Verified 2026-11-20: 2026-11-20 host-4 exit 0: LissajousLabyrinthRulesTests 6/6 (move order vs brute force; apply refusals; isSolved equals the verdict on 100 fixtures; R02-F23 PuzzleValidator certifies a seeded level, notUnique for the solution promise; wrongRules, illegalMove) (.autonomy/migration/checks/R02-G02-01.host-4.json)
  "r02-g02-lissajous-labyrinth") with `Packages/ExperiencesRound02/LissajousLabyrinth/CoreTests/LissajousLabyrinthRulesTests.swift` (moves in dial order, values
  ascending, skipping current and non-coprime; apply refusals; isSolved equals the verdict; R02-F23's PuzzleValidator
  certifies a seeded level); `--name host-4`
- [X] T-R02G0201-006 [P] Create `Packages/ExperiencesRound02/LissajousLabyrinth/CoreTests/LissajousLabyrinthInvariantTests.swift` with — Verified 2026-11-20: 2026-11-20 host-5 exit 0: LissajousLabyrinthInvariantTests 8/8 (Time, Inputbudget, Goal, Repeatability, Undo, Failurehonesty, Stability, Save — each a boundary example and a seeded neighbouring check) (.autonomy/migration/checks/R02-G02-01.host-5.json)
  `testLissajousLabyrinthTimeBoundary` (INV-01), `testLissajousLabyrinthInputbudgetBoundary` (INV-02),
  `testLissajousLabyrinthGoalBoundary` (INV-03), `testLissajousLabyrinthRepeatabilityBoundary` (INV-04),
  `testLissajousLabyrinthUndoBoundary` (INV-05), `testLissajousLabyrinthFailurehonestyBoundary` (INV-07),
  `testLissajousLabyrinthStabilityBoundary` (INV-08) and `testLissajousLabyrinthSaveBoundary` (INV-09), each a direct
  boundary example plus a seeded neighbouring-input check (FR-R02G0201-010); `--name host-5`

## Phase 6: Regression, documentation and close

- [X] T-R02G0201-007 Docs: new `docs/architecture/lissajous-labyrinth.md`; `Packages/ExperiencesRound02/README.md`; — Verified 2026-11-20: 2026-11-20 round02-host exit 0 (96 tests; the lap reads the sine table through one buffer per lap, which took the whole package from about 35 s to 5 s); docs/architecture/lissajous-labyrinth.md; package README section (.autonomy/migration/checks/R02-G02-01.round02-host.json)
  `docs/automatedtesting.md`; `--name round02-host -- swift test --package-path Packages/ExperiencesRound02`
- [X] T-R02G0201-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences` and — Verified 2026-11-20: 2026-11-20 rendering-27, rendering-26, experiences (sim-27.2) and host-full exit 0
  `--name host-full`
- [X] T-R02G0201-009 Reference regression chunk 1 (`--name reference-1`) — Verified 2026-11-20: 2026-11-20 reference-1 exit 0
- [X] T-R02G0201-010 Reference regression chunk 2 (`--name reference-2`) — Verified 2026-11-20: 2026-11-20 reference-2 exit 0: 7 of 7 with chunk 1
- [ ] T-R02G0201-011 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G0201-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record

## Dependencies and parallel work

001 → 002 → {003 (agent A), 004 (agent B), 005 (agent C), 006 (agent D)} in parallel → 007 … 012. Shared files
(Package.swift, error, sine, level, lap, fixtures, docs) stay with the lead. MVP: Story 1.
