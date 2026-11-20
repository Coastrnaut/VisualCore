# Tasks: R02-G01-01 — Aurora Loom: playable rule kernel

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G01-01 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G01-01 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). No {owner}
or {device} tasks (pure logic). Fixture seed 2_301; tests stay short.

## Phase 1: Setup

- [X] T-R02G0101-001 Baselines: `--name baseline-host -- swift test --package-path Packages/VisualCore` and the isolated — Verified 2026-11-20: 2026-11-20 baseline-host exit 0, baseline-timing exit 0 (.autonomy/migration/checks/R02-G01-01.baseline-*.json); rendering baseline R02-F24 rendering-27/26 exit 0
  timing run; the rendering baseline is R02-F24's rendering runs (exit 0)

## Phase 2: Foundational

- [X] T-R02G0101-002 Create `Packages/ExperiencesRound02/Package.swift` (platforms iOS 26 and macOS 15; target — Verified 2026-11-20: 2026-11-20 host exit 0: AuroraLoomLevelTests 4/4 (refusals and codes; an already-winning start refused; periods; 200 seeded fixtures win with their setting and not at the start; round trip byte for byte; newer, damaged, edited forms refused) (.autonomy/migration/checks/R02-G01-01.host.json)
  `AuroraLoomCore` at `AuroraLoom/Core` depending on VisualCoreSimulation and VisualCoreMath; test target
  `AuroraLoomCoreTests` at `AuroraLoom/CoreTests`), `Packages/ExperiencesRound02/AuroraLoom/Core/AuroraLoomError.swift`, `Packages/ExperiencesRound02/AuroraLoom/Core/AuroraLoomHarmony.swift` (phase, residual, wins over n = 0 … 2P − 1, worst
  mismatch with ties by ribbon, gate, tick) and `Packages/ExperiencesRound02/AuroraLoom/Core/AuroraLoomLevel.swift`
  (AuroraLoomRibbon "steps 0 … 15; omega 0 … 256", AuroraLoomGate "position 1 … 15; Θ 0 … 4,095", AuroraLoomLevel "id slug;
  band 1 … 5; 3 ribbons; 4 gates with distinct positions; Ω power of two 1 … 256; tolerance 1 … 512; allowance 1 … 64;
  start must not win; schema 1", fingerprint, stored form) with `Packages/ExperiencesRound02/AuroraLoom/CoreTests/AuroraLoomLevelTests.swift` (refusals and codes;
  round trip; damaged, newer and edited forms refused; period);  `--name host -- swift test --package-path Packages/ExperiencesRound02 --filter
  AuroraLoomLevelTests`

## Phase 3: Story 1 — make three ribbons agree (P1) 🎯

- [X] T-R02G0101-003 [P] [US1] Create `Packages/ExperiencesRound02/AuroraLoom/CoreTests/AuroraLoomHarmonyTests.swift` (1,000 seeded levels: the — Verified 2026-11-20: 2026-11-20 host-2 exit 0: AuroraLoomHarmonyTests 11/11 (1,000 seeded levels win with their setting; 13,500 single-control changes agree with an independent reference; boundaries at ±tolerance and the ±2,048 wrap; tie order; drift over two periods) (.autonomy/migration/checks/R02-G01-01.host-2.json)
  constructed setting wins; for every single-control change the win test agrees with an independent reference written in
  the test; boundary at exactly the tolerance inside, one unit beyond outside; worst mismatch and tie order; a drifting
  ribbon (ω ≠ Ω) is judged over the two periods); `--name host-2`

## Phase 4: Stories 2, 3 and 4 — allowance, undo, replay and life stages (P1, P2)

- [X] T-R02G0101-004 [P] [US2] [US3] [US4] Create `Packages/ExperiencesRound02/AuroraLoom/Core/AuroraLoomPlay.swift` (stages and events, moves with validation and — Verified 2026-11-20: 2026-11-20 host-3 exit 0: AuroraLoomPlayTests 11/11 (500 traces replay exactly; undo restores every earlier state; 1,000 refused attempts change nothing; winning and failing with the worst mismatch; full stage table) (.autonomy/migration/checks/R02-G01-01.host-3.json)
  records, undo with refund, redo, replay, fingerprints) with `Packages/ExperiencesRound02/AuroraLoom/CoreTests/AuroraLoomPlayTests.swift` (500 seeded traces replay to
  identical fingerprints and outcome; undo of every move restores the exact state; 1,000 seeded refused moves leave state
  and fingerprint unchanged; spending the allowance fails with the worst mismatch named; stage machine table; no move
  after the end); `--name host-3`

## Phase 5: Solver-ready rules (P2)

- [ ] T-R02G0101-005 [P] [US1] Create `Packages/ExperiencesRound02/AuroraLoom/Core/AuroraLoomRules.swift` (PuzzleRules conformance, rules id
  "r02-g01-aurora-loom") with `Packages/ExperiencesRound02/AuroraLoom/CoreTests/AuroraLoomRulesTests.swift` (moves in order; apply refuses out-of-range and no-change;
  isSolved equals the win test; R02-F23's PuzzleValidator certifies a small seeded level and its uniqueness); `--name
  host-4`

## Phase 6: Regression, documentation and close

- [ ] T-R02G0101-006 CI and docs: a step `swift test --package-path Packages/ExperiencesRound02` in
  `.github/workflows/ci.yml` beside the VisualCore host tests (and its cache path); new
  `docs/architecture/aurora-loom.md`; `Packages/ExperiencesRound02/README.md`; `docs/automatedtesting.md`; `--name
  round02-host -- swift test --package-path Packages/ExperiencesRound02`
- [ ] T-R02G0101-007 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences` and
  `--name host-full`
- [ ] T-R02G0101-008 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G0101-009 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G0101-010 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G0101-011 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record

## Dependencies and parallel work

001 → 002 → {003, 004, 005} in parallel → 006 → … → 011. Agents: A (003), B (004),
C (005). Shared files (002, CI, docs) stay with the lead. MVP: Story 1.
