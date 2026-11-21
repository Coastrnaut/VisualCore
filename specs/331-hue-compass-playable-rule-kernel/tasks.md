# Tasks: R02-G04-01 — Hue Compass: playable rule kernel

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G04-01 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G04-01 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Fixture seed
2_331, neighbouring checks seed 2_336; tests stay short (< 10 s each). No {owner} or {device} tasks (pure logic).

## Phase 1: Setup

- [ ] T-R02G0401-001 Baselines: `--name baseline-host`, `--name baseline-timing`, `--name baseline-round02 -- swift test
  --package-path Packages/ExperiencesRound02`; the rendering baseline is R02-G03-10's rendering runs (exit 0)

## Phase 2: Foundational

- [ ] T-R02G0401-002 Edit `Packages/ExperiencesRound02/Package.swift` (+ `HueCompassCore`, `HueCompassCoreTests`, product); create
  `Packages/ExperiencesRound02/HueCompass/Core/HueCompassError.swift` (codes "r02-g04.level, .action, .stage, .stale, .allowance, .newer-schema,
  .malformed"), `Packages/ExperiencesRound02/HueCompass/Core/HueCompassWheel.swift` ("96 bearings, 24 bands of 4"; 96 integer boundary constants at angle
  2πk/96 × 65 536 rounded; sector test by cross products; band(b) = (⌊b/4⌋ + offset) mod 24; circular distances; shorter
  arc, counter-clockwise from the probe on a tie; clue), `Packages/ExperiencesRound02/HueCompass/Core/HueCompassLevel.swift` (offset "0 … 23", fog "96 ×
  (0 … 9)", target "0 … 95", bearing tolerance "0 … 4", band tolerance "0 … 2", allowance "2 … 24", start bearing
  "0 … 95" not within the bearing tolerance of the target, band "1 … 5"; JSON schema 1 with sorted keys and fingerprint;
  decode re-checks) and `Packages/ExperiencesRound02/HueCompass/CoreTests/HueCompassFixtures.swift` (seeded levels with a known probe sequence and correct
  selection) with `Packages/ExperiencesRound02/HueCompass/CoreTests/HueCompassLevelTests.swift`; `--name host`

## Phase 3: Story 1 — find the hidden bearing (P1) 🎯

- [ ] T-R02G0401-003 [P] [US1] Create `Packages/ExperiencesRound02/HueCompass/CoreTests/HueCompassWheelTests.swift` (the sector rule agrees with an
  independent `atan2` reference on every direction of a 33 × 33 lattice away from boundaries; every boundary vector
  belongs to exactly one sector; distances and arcs; clues equal a brute-force computation for every bearing of 500
  seeded levels; the hue gap ignores fog and the depth ignores hue and offset); `--name host-2`

## Phase 4: Stories 2 and 3 — miss, run out, undo, redo, replay (P1)

- [ ] T-R02G0401-004 [P] [US1] [US2] [US3] Create `Packages/ExperiencesRound02/HueCompass/Core/HueCompassPlay.swift` (stages "loading, tutorial,
  playing, paused, won, failed, result"; actions validated for range, stage, previous fingerprint, allowance; turns free,
  probes and selections spend one; a probe spending the last unit fails `probes`; a selection wins or fails
  `selection`; records with previous and next fingerprints; turn-only undo and redo, cleared by a probe or selection;
  replay) with `Packages/ExperiencesRound02/HueCompass/CoreTests/HueCompassPlayTests.swift` (known solutions win; 500 seeded traces replay; undo restores
  exact fingerprints; both failures named; every refusal reason reachable); `--name host-3`

## Phase 5: Story 4 — contract and invariants (P2)

- [ ] T-R02G0401-005 [P] [US4] Create `Packages/ExperiencesRound02/HueCompass/Core/HueCompassRules.swift` (`PuzzleRules`: State = position (bearing,
  spent, outcome), Move = HueCompassAction; legal moves turn(+1), turn(−1), probe, select(current bearing, band 0 … 23)
  in that order) with `Packages/ExperiencesRound02/HueCompass/CoreTests/HueCompassRulesTests.swift` (agreement with the play on 200 walks); `--name host-4`
- [ ] T-R02G0401-006 [P] Create `Packages/ExperiencesRound02/HueCompass/CoreTests/HueCompassInvariantTests.swift` (`testHueCompassTimeBoundary`,
  `…InputbudgetBoundary`, `…GoalBoundary`, `…RepeatabilityBoundary`, `…UndoBoundary`, `…FailurehonestyBoundary`,
  `…StabilityBoundary`, `…SaveBoundary`, each with a seeded neighbouring-input check, seed 2_336); `--name host-5`

## Phase 6: Regression, documentation and close

- [ ] T-R02G0401-007 Docs: `docs/architecture/hue-compass.md` (rules), `Packages/ExperiencesRound02/README.md`,
  `docs/automatedtesting.md`; `--name round02-host`
- [ ] T-R02G0401-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`,
  `--name host-full`
- [ ] T-R02G0401-009 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G0401-010 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G0401-011 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G0401-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record

## Dependencies and parallel work

001 → 002 (lead) → {003 (agent A), 004 (agent B), 005 (agent C), 006 (agent D)} → 007 … 012. Agents C and D code
against the play contract in contracts/api.md; shared files (package, error, wheel, level, fixtures, docs) stay with the
lead. MVP: Story 1.
