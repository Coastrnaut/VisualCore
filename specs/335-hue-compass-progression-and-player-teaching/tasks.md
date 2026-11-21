# Tasks: R02-G04-05 — Hue Compass: progression and player teaching

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G04-05 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G04-05 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_335;
tests stay short (< 10 s each). No {owner} or {device} tasks.

## Phase 1: Setup

- [X] T-R02G0405-001 Baselines: `--name baseline-host`, `--name baseline-timing`, `--name baseline-round02 -- swift test — Verified 2026-11-21: 2026-11-21 R02-G04-05.baseline-host/timing/round02 exit 0
  --package-path Packages/ExperiencesRound02`; the rendering baseline is R02-G04-04's runs (exit 0)

## Phase 2: Stories 2 and 3 — hints and failure explanations (P1) 🎯

- [X] T-R02G0405-002 [P] [US2] [US3] Create `Packages/ExperiencesRound02/HueCompass/Core/HueCompassHints.swift` (consistent set from the clues seen; hint — Verified 2026-11-21: 2026-11-21 host exit 0 (agent B: hints from the consistent set (never the target), probe/select/guess with octant wording, failure explanations with distances and tolerances; 8 tests: exact hints win all 100 levels within the allowance (2 steps per level in bands 1-3, at most 3 in bands 4-5), 2,000 seeded states with legal hints that never spend the last unit on a probe, 500 failures explained exactly)
  "levels 1 … 3: what, where (octant, north = bearing 24), exact"; selection when one selection accepts the consistent
  set; else with at least two units a probe at the first settling bearing, else the bearing with the smallest largest
  class, lowest on a tie; with one unit the best-guess selection; nil when not playing; HueCompassFailureExplanation
  "The target was bearing T (band B). Your selection was d bearings and e bands away; the tolerances are t and u." or
  "The last unit went to a probe; keep one for the selection.", each followed by "Retry the level.") with
  `Packages/ExperiencesRound02/HueCompass/CoreTests/HueCompassHintsTests.swift` (agent B: following exact hints from the start wins all 100 levels within
  the allowance; 2,000 seeded reachable states: every exact hint is legal and never spends the last unit on a probe;
  hint levels agree; no hint after the end; 500 seeded failures explained exactly); `--name host`

## Phase 3: Stories 1 and 4 — tutorial, progress, daily, practice (P1, P2)

- [X] T-R02G0405-003 [P] [US1] [US4] Create `Packages/ExperiencesRound02/HueCompass/Core/HueCompassProgress.swift` (HueCompassTutorialStep "aim → probe (an — Verified 2026-11-21: 2026-11-21 host-2 exit 0 (agent C: tutorial steps aim/probe/select/done with Q2 texts and transitions, in every mode on levels 1-3; modes; progress with best units and stars 3/2/1, campaign unlocks, daily awards but never opens, practice records nothing; daily level x 47 by civil-date arithmetic; 21 tests incl. every date 2026-2036 and 100-day coverage)
  accepted turn) → select (an accepted probe) → done (the level ends); dismiss → done; undo never moves it back" with the
  texts of clarification Q2; HueCompassMode "campaign, practice, daily(level)"; HueCompassProgress "level 1 open; a
  campaign win opens the next; a better result replaces a worse one; stars 3 at most smallest + 1 units, 2 at most
  smallest + 2, else 1"; dailyLevel "(days from 2026-01-01 × 47) mod 100 + 1, negative counts wrapped; nil for an
  impossible date") with `Packages/ExperiencesRound02/HueCompass/CoreTests/HueCompassProgressTests.swift` (agent C: tutorial scripts on levels 1 … 3;
  scripted progress through 100 levels; stars; every date 2026-01-01 … 2036-12-31 maps to 1 … 100 and 100 consecutive
  days visit every level; impossible dates refused; all 100 levels reachable by progress alone); `--name host-2`

## Phase 4: Adapter, scenarios and panel

- [X] T-R02G0405-004 [US1] [US2] [US3] [US4] Edit `Packages/ExperiencesRound02/HueCompass/Core/HueCompassExperienceCore.swift` (controls "level.select — Verified 2026-11-21: 2026-11-21 host-3 exit 0 (agent F: adapter with level.select, mode.daily, mode.practice (allowance 24), mode.campaign, tutorial.dismiss; level.next to the next open level; locked daily playable without opening; wins record units and stars; digest v2 with progress and mode, tutorial in the snapshot only; schema 2 with a 1 -> 2 migration; scenarios gain 6 rejection entries and the manifest is regenerated; 31 tests incl. migration, tutorial with undo, hint and failure accessors)
  [1 … 100], mode.daily [year, month, day], mode.practice, mode.campaign, tutorial.dismiss"; practice
  allowance 24; daily wins record results without opening levels and a locked daily level is playable; choosing daily
  or practice drops the left level's records, mode.campaign returns to a fresh campaign play of the same level; the
  tutorial on levels 1 … 3 in every mode, once per opening; progress and mode in the digest, the tutorial step in the
  snapshot only; snapshot schema 2 `{level, records, progress, mode, tutorial}` with a 1 → 2 migration; codes
  r02-g04.locked, r02-g04.date), `Packages/ExperiencesRound02/HueCompass/Core/HueCompassScenarios.swift` and the regenerated `Packages/ExperiencesRound02/HueCompass/scenario-manifest.json`,
  with `Packages/ExperiencesRound02/HueCompass/CoreTests/HueCompassExperienceCoreTests.swift` updates (conformance; actions; migration of a schema-1 payload;
  undo restores the digest with the tutorial advanced); `--name host-3 -- swift test --package-path
  Packages/ExperiencesRound02 --filter 'HueCompassExperienceCoreTests|HueCompassScenarios|HueCompassRendererPurity|HueCompassPanelWin'`
- [X] T-R02G0405-005 [US1] [US2] [US3] [US4] Edit `Packages/ExperiencesRound02/HueCompass/Experience/HueCompassPresenter.swift` and — Verified 2026-11-21: 2026-11-21 sim-27 exit 0 on sim-27.2: HueCompassTeachingTests and every Hue Compass experience test (presenter teaching mirror, hints, retry, daily date, mode and level controls)
  `Packages/ExperiencesRound02/HueCompass/Experience/HueCompassControls.swift` (instruction with Dismiss; Hint revealing the next level, reset after any
  change of the play; failure explanation with Retry; level picker of open levels with bands and stars; Campaign /
  Daily (local calendar date) / Practice) and create `Packages/ExperiencesRound02/HueCompass/ExperienceTests/HueCompassTeachingTests.swift` (agent D: hint
  levels through the presenter, failure text, picker refusals, daily and practice through the port, the tutorial on
  level 1); `--name sim-27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme
  ExperiencesRound02-Package --destination sim-27.2 --action test`

## Phase 5: Regression, documentation and close

- [ ] T-R02G0405-006 Docs: `docs/architecture/hue-compass.md` (teaching and progression),
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host`
- [ ] T-R02G0405-007 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`,
  `--name host-full`, `--name app-unit`
- [ ] T-R02G0405-008 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G0405-009 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G0405-010 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G0405-011 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record

## Dependencies and parallel work

001 → {002 (agent B), 003 (agent C)} → 004 (lead) → 005 (lead; agent D writes the simulator tests) → 006 … 011. Shared
files (adapter, scenarios, presenter, controls, docs) stay with the lead. MVP: Stories 1–3.

## Phase 6: Convergence

- [ ] T-R02G0405-012 Show hue bands as 1 … 24 in every player-facing text, matching the panel, the band picker and the descriptions: the select and guess hint texts in `Packages/ExperiencesRound02/HueCompass/Core/HueCompassHints.swift` ("Select bearing b with band h+1") and the failure text ("band B+1", band distances unchanged), with `HueCompassHintsTests.swift` and `HueCompassTeachingTests.swift` expecting the 1-based band, per FR-R02G0405-002, FR-R02G0405-003 (contradicts); `--name host-4 -- swift test --package-path Packages/ExperiencesRound02 --filter 'HueCompassHintsTests|HueCompassExperienceCoreTests'`
