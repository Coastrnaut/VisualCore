# Tasks: R02-G04-01 — Hue Compass: playable rule kernel

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G04-01 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G04-01 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Fixture seed
2_331, neighbouring checks seed 2_336; tests stay short (< 10 s each). No {owner} or {device} tasks (pure logic).

## Phase 1: Setup

- [X] T-R02G0401-001 Baselines: `--name baseline-host`, `--name baseline-timing`, `--name baseline-round02 -- swift test — Verified 2026-11-21: 2026-11-21 R02-G04-01.baseline-host/timing/round02 exit 0
  --package-path Packages/ExperiencesRound02`; the rendering baseline is R02-G03-10's rendering runs (exit 0)

## Phase 2: Foundational

- [X] T-R02G0401-002 Edit `Packages/ExperiencesRound02/Package.swift` (+ `HueCompassCore`, `HueCompassCoreTests`, product); create — Verified 2026-11-21: 2026-11-21 host exit 0 (package targets; error codes; exact wheel with the 96-vector boundary table; level with ranges, start rule, clue, acceptance, stored form; fixtures with known solutions, 500 verified to select an accepted pair; 7 level tests). The lead also wrote HueCompassPlay (the rules and invariants depend on it); agent B writes its tests
  `Packages/ExperiencesRound02/HueCompass/Core/HueCompassError.swift` (codes "r02-g04.level, .action, .stage, .stale, .allowance, .newer-schema,
  .malformed"), `Packages/ExperiencesRound02/HueCompass/Core/HueCompassWheel.swift` ("96 bearings, 24 bands of 4"; 96 integer boundary constants at angle
  2πk/96 × 65 536 rounded; sector test by cross products; band(b) = (⌊b/4⌋ + offset) mod 24; circular distances; shorter
  arc, counter-clockwise from the probe on a tie; clue), `Packages/ExperiencesRound02/HueCompass/Core/HueCompassLevel.swift` (offset "0 … 23", fog "96 ×
  (0 … 9)", target "0 … 95", bearing tolerance "0 … 4", band tolerance "0 … 2", allowance "2 … 24", start bearing
  "0 … 95" not within the bearing tolerance of the target, band "1 … 5"; JSON schema 1 with sorted keys and fingerprint;
  decode re-checks) and `Packages/ExperiencesRound02/HueCompass/CoreTests/HueCompassFixtures.swift` (seeded levels with a known probe sequence and correct
  selection) with `Packages/ExperiencesRound02/HueCompass/CoreTests/HueCompassLevelTests.swift`; `--name host`

## Phase 3: Story 1 — find the hidden bearing (P1) 🎯

- [X] T-R02G0401-003 [P] [US1] Create `Packages/ExperiencesRound02/HueCompass/CoreTests/HueCompassWheelTests.swift` (the sector rule agrees with an — Verified 2026-11-21: 2026-11-21 host-2 exit 0 (wheel, 9 tests: the sector rule agrees with atan2 on all 960 off-boundary directions of the 33 x 33 lattice (1e-6 rad) and on 4,000 seeded large directions (1e-5 rad, above the 8.6e-6 rad rounding of the table); every boundary in exactly one sector; distances and arcs on all pairs; clues equal a brute-force walk for every bearing of 500 fixtures; hue gap independent of fog, depth independent of offset)
  independent `atan2` reference on every direction of a 33 × 33 lattice whose reference angle is more than
  10⁻⁶ rad from every boundary; every boundary vector
  belongs to exactly one sector; distances and arcs; clues equal a brute-force computation for every bearing of 500
  seeded levels; the hue gap ignores fog and the depth ignores hue and offset); `--name host-2`

## Phase 4: Stories 2 and 3 — miss, run out, undo, redo, replay (P1)

- [X] T-R02G0401-004 [P] [US1] [US2] [US3] Create `Packages/ExperiencesRound02/HueCompass/Core/HueCompassPlay.swift` (stages "loading, tutorial, — Verified 2026-11-21: 2026-11-21 host-3 exit 0 (play by the lead, 9 tests by agent B: 500 known solutions win exactly at the selection; every refusal in order stage, stale, range with no change; both failures; undo/redo exact; 500 seeded traces replay, tampered traces refused; full stage table; fingerprint against an independent byte statement). Agent B found that a selection changed within its verdict replayed; the lead pinned the selected bearing and band in the play fingerprint (spec Q5 updated) and the tamper test now catches any changed selection
  playing, paused, won, failed, result"; actions validated for range, stage, previous fingerprint, allowance; turns free,
  probes and selections spend one; a probe spending the last unit fails `probes`; a selection wins or fails
  `selection`; records with previous and next fingerprints; turn-only undo and redo, cleared by a probe or selection;
  replay) with `Packages/ExperiencesRound02/HueCompass/CoreTests/HueCompassPlayTests.swift` (known solutions win; 500 seeded traces replay; undo restores
  exact fingerprints; both failures named; every refusal reason reachable); `--name host-3`

## Phase 5: Story 4 — contract and invariants (P2)

- [X] T-R02G0401-005 [P] [US4] Create `Packages/ExperiencesRound02/HueCompass/Core/HueCompassRules.swift` (`PuzzleRules`: State = position (bearing, — Verified 2026-11-21: 2026-11-21 host-4 exit 0 (HueCompassRules as PuzzleRules, 8 tests: 27 moves in order, ended positions offer nothing, agreement with the play on 200 seeded walks, 100 known solutions as single-step turns, PuzzleValidator certifies a hand-made level with a unique shortest solution)
  spent, outcome), Move = HueCompassAction; legal moves turn(+1), turn(−1), probe, select(current bearing, band 0 … 23)
  in that order) with `Packages/ExperiencesRound02/HueCompass/CoreTests/HueCompassRulesTests.swift` (agreement with the play on 200 walks); `--name host-4`
- [X] T-R02G0401-006 [P] Create `Packages/ExperiencesRound02/HueCompass/CoreTests/HueCompassInvariantTests.swift` (`testHueCompassTimeBoundary`, — Verified 2026-11-21: 2026-11-21 host-5 exit 0 (8 invariant tests, each with a seeded neighbouring-input check, seed 2_336)
  `…InputbudgetBoundary`, `…GoalBoundary`, `…RepeatabilityBoundary`, `…UndoBoundary`, `…FailurehonestyBoundary`,
  `…StabilityBoundary`, `…SaveBoundary`, each with a seeded neighbouring-input check, seed 2_336); `--name host-5`

## Phase 6: Regression, documentation and close

- [X] T-R02G0401-007 Docs: `docs/architecture/hue-compass.md` (rules), `Packages/ExperiencesRound02/README.md`, — Verified 2026-11-21: 2026-11-21 round02-host exit 0; docs/architecture/hue-compass.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md
  `docs/automatedtesting.md`; `--name round02-host`
- [X] T-R02G0401-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`, — Verified 2026-11-21: 2026-11-21 rendering-27, rendering-26, experiences, host-full exit 0
  `--name host-full`
- [X] T-R02G0401-009 Reference regression chunk 1 (`--name reference-1`) — Verified 2026-11-21: 2026-11-21 reference-1 exit 0
- [X] T-R02G0401-010 Reference regression chunk 2 (`--name reference-2`) — Verified 2026-11-21: 2026-11-21 reference-2 exit 0: 7 of 7 with chunk 1
- [ ] T-R02G0401-011 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G0401-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record

## Dependencies and parallel work

001 → 002 (lead) → {003 (agent A), 004 (agent B), 005 (agent C), 006 (agent D)} → 007 … 012. Agents C and D code
against the play contract in contracts/api.md; shared files (package, error, wheel, level, fixtures, docs) stay with the
lead. MVP: Story 1.

## Phase 7: Convergence

- [X] T-R02G0401-013 Document `HueCompassSelection` and `HueCompassPlay.selection` (the selected bearing and band pinned in the play fingerprint, spec clarification Q5) in `specs/331-hue-compass-playable-rule-kernel/contracts/api.md` and `specs/331-hue-compass-playable-rule-kernel/data-model.md` per plan: contracts (unrequested) — Verified 2026-11-21: 2026-11-21 HueCompassSelection and HueCompassPlay.selection documented in contracts/api.md and data-model.md (grep: present in both); code unchanged
