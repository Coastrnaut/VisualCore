# Tasks: R02-G03-01 — Wave Knot Keeper: playable rule kernel

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G03-01 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G03-01 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Fixture seed
2_321, neighbouring checks seed 2_326; tests stay short (< 10 s each). No {owner} or {device} tasks (pure logic).

## Phase 1: Setup

- [X] T-R02G0301-001 Baselines: `--name baseline-host`, `--name baseline-timing`, `--name baseline-round02 -- swift test — Verified 2026-11-20: 2026-11-20 R02-G03-01.baseline-host/timing/round02 exit 0
  --package-path Packages/ExperiencesRound02`; the rendering baseline is R02-G01-07's rendering runs (exit 0)

## Phase 2: Foundational

- [X] T-R02G0301-002 Edit `Packages/ExperiencesRound02/Package.swift` (+ `WaveKnotKeeperCore`, tests, product); create — Verified 2026-11-20: 2026-11-20 host exit 0 (package targets; error codes; level with point, gate, target, direction, move; start simple, not won, tension within bound, which needed the geometry, so the lead wrote WaveKnotKeeperGeometry and WaveKnotKeeperPlay with it; fixtures with known solutions, 100 verified to win; 6 level tests)
  `Packages/ExperiencesRound02/WaveKnotKeeper/Core/WaveKnotKeeperError.swift` (codes "r02-g03.level, .move, .stage, .stale, .allowance, .newer-schema,
  .malformed"), `Packages/ExperiencesRound02/WaveKnotKeeper/Core/WaveKnotKeeperLevel.swift` (Point "−16 … 16", Gate "inclusive box inside bounds", Target
  "crossings 0 … 32, writhe −32 … 32", Level "points 6 … 16 distinct, gates 0 … 4, allowance 1 … 64, band 1 … 5";
  JSON schema 1 with sorted keys and fingerprint; decode re-checks; the "start not won" and "start tension ≤ bound"
  checks need the geometry and are added by the lead once T-R02G0301-003 lands) and
  `Packages/ExperiencesRound02/WaveKnotKeeper/CoreTests/WaveKnotKeeperFixtures.swift` (seeded levels with a known solution) with
  `Packages/ExperiencesRound02/WaveKnotKeeper/CoreTests/WaveKnotKeeperLevelTests.swift`; `--name host`

## Phase 3: Story 1 — untie the knot (P1) 🎯

- [X] T-R02G0301-003 [P] [US1] Create `Packages/ExperiencesRound02/WaveKnotKeeper/Core/WaveKnotKeeperGeometry.swift` (orientation determinants; exact — Verified 2026-11-20: 2026-11-20 host-2 exit 0 (geometry, 11 tests: 500 seeded ropes match an independent brute-force projection count, translation, rotation and reversal invariant; one-crossing and 7-stick trefoil diagrams; degenerate cases; 2,000 random primitive cases vs an independent exact method; sweep refusals; simplicity; tension). Level start checks landed with T-002
  segment-triangle intersection with contact only at a shared vertex allowed; `sweepIsClear`; xy-projection crossings
  with signs, writhe and degeneracy; tension Σ|segment|²) with `Packages/ExperiencesRound02/WaveKnotKeeper/CoreTests/WaveKnotKeeperGeometryTests.swift`
  (500 seeded ropes: summary equals an independent brute-force projection count and is translation-invariant; known knots
  (trefoil-like lattice ropes) give their crossing counts; sweep refusals on constructed cases); then the lead adds the level's "start not won" and "start tension ≤ bound"
  checks with their tests; `--name host-2`

## Phase 4: Stories 2 and 3 — fail, undo, redo, replay (P1)

- [ ] T-R02G0301-004 [P] [US2] [US3] Create `Packages/ExperiencesRound02/WaveKnotKeeper/Core/WaveKnotKeeperPlay.swift` (stages "loading, tutorial, playing,
  paused, won, failed, result"; moves validated for range, bounds, coincidence, sweep, gates, tension, stage, previous
  fingerprint, allowance; records with previous and next fingerprints; undo, redo; replay) with
  `Packages/ExperiencesRound02/WaveKnotKeeper/CoreTests/WaveKnotKeeperPlayTests.swift` (known solutions win; 500 seeded traces replay; undo restores exact
  fingerprints; allowance and tension failures named); `--name host-3`

## Phase 5: Stories 4 — contract and invariants (P2)

- [ ] T-R02G0301-005 [P] [US4] Create `Packages/ExperiencesRound02/WaveKnotKeeper/Core/WaveKnotKeeperRules.swift` (`PuzzleRules`: State = points, Move =
  WaveKnotKeeperMove, legal moves in a fixed order) with `Packages/ExperiencesRound02/WaveKnotKeeper/CoreTests/WaveKnotKeeperRulesTests.swift`; `--name host-4`
- [ ] T-R02G0301-006 [P] Create `Packages/ExperiencesRound02/WaveKnotKeeper/CoreTests/WaveKnotKeeperInvariantTests.swift` (`testWaveKnotKeeperTimeBoundary`,
  `…InputbudgetBoundary`, `…GoalBoundary`, `…RepeatabilityBoundary`, `…UndoBoundary`, `…FailurehonestyBoundary`,
  `…StabilityBoundary`, `…SaveBoundary`, each with a seeded neighbouring-input check, seed 2_326); `--name host-5`

## Phase 6: Regression, documentation and close

- [ ] T-R02G0301-007 Docs: `docs/architecture/wave-knot-keeper.md` (rules), `Packages/ExperiencesRound02/README.md`,
  `docs/automatedtesting.md`; `--name round02-host`
- [ ] T-R02G0301-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`,
  `--name host-full`
- [ ] T-R02G0301-009 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G0301-010 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G0301-011 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G0301-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record

## Dependencies and parallel work

001 → 002 (lead) → {003 (agent A), 004 (agent B), 005 (agent C), 006 (agent D)} → 007 … 012. Agents B, C and D code
against the geometry contract; shared files (package, error, level, fixtures, docs) stay with the lead. MVP: Story 1.
