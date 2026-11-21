# Tasks: R02-G04-04 — Hue Compass: gameplay spatial interaction

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G04-04 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G04-04 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_334;
tests stay short (< 10 s each). No {owner} tasks.

## Phase 1: Setup

- [X] T-R02G0404-001 Baselines: `--name baseline-host`, `--name baseline-timing`, `--name baseline-round02 -- swift test — Verified 2026-11-21: 2026-11-21 R02-G04-04.baseline-host/timing/round02 exit 0
  --package-path Packages/ExperiencesRound02`; the rendering baseline is R02-G04-03's runs (exit 0)

## Phase 2: Foundational

- [ ] T-R02G0404-002 Edit `Packages/ExperiencesRound02/HueCompass/Core/HueCompassSceneGeometry.swift` (`HueCompassOrbit` "yaw −40° … 40°, tilt 15° … 60°,
  authored 35°", `camera(aspect:orbit:)` refitting the 1.45 sphere for a 5 % margin; `camera(aspect:)` equals the
  authored orbit) and create `Packages/ExperiencesRound02/HueCompass/Core/HueCompassDial.swift` (projected centre, hub radius "0.3 world units, at least 30
  points", angle atan2(−dy, dx) with "dead zone 20 points", steps round(angle · 96 / 2π), wrapping into "−47 … 48") with
  `Packages/ExperiencesRound02/HueCompass/CoreTests/HueCompassDialTests.swift` and orbit framing tests in `Packages/ExperiencesRound02/HueCompass/CoreTests/HueCompassSceneGeometryTests.swift`
  (agent B: angles and hub against an independent computation; every orbit limit and 7 aspects keep the compass inside
  with 5 %); `--name host-2`

## Phase 3: Stories 1, 2 and 3 — swipe, press, orbit (P1) 🎯

- [ ] T-R02G0404-003 [US1] [US2] [US3] Create `Packages/ExperiencesRound02/HueCompass/Core/HueCompassGestureController.swift` (idle, swiping, orbiting,
  cancelled; accumulated angle with the dead zone; preview bearing; release sends at most one `turn(steps)`, "tap
  within 10 points" in the hub sends `probe`, double tap "within 0.35 s" outside the wheel resets the view; a second
  finger cancels and orbits "90° per view width, 60° per view height"; nothing while not playing) with
  `Packages/ExperiencesRound02/HueCompass/CoreTests/HueCompassGestureControllerTests.swift` (agent C: 500 seeded swipes equal an independent computation;
  every arbitration case of SC-R02G0404-002; orbit rates and limits; determinism); `--name host-3`

## Phase 4: Story 4 — play with the panel alone (P1)

- [ ] T-R02G0404-004 [US4] Create `Packages/ExperiencesRound02/HueCompass/CoreTests/HueCompassPanelWinTests.swift` (agent D: all 100 certified levels won
  through the adapter actions the panel sends — a witness turn of k as ⌊|k|/4⌋ turns of ±4 and |k| mod 4 turns of ±1,
  then the probe and the select — split by band); `--name host-4`

## Phase 5: Wiring — preview, presenter, panel

- [ ] T-R02G0404-005 Edit `Packages/ExperiencesRound02/HueCompass/Experience/HueCompassPresenter.swift` (pointer entry through the gesture controller,
  `resetView()`, orbit-aware camera, ghost needle at the preview, description "Turning to bearing n of 96"),
  `Packages/ExperiencesRound02/HueCompass/Experience/HueCompassCompassScene.swift` (orbit camera, ghost needle "pearl at half opacity") and
  `Packages/ExperiencesRound02/HueCompass/Experience/HueCompassControls.swift` ("Reset view"), with `Packages/ExperiencesRound02/HueCompass/ExperienceTests/HueCompassGestureWiringTests.swift`
  (agent E: scripted swipes and hub taps through the experience's pointer entry turn and probe; orbit never changes the
  digest); `--name sim-27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme
  ExperiencesRound02-Package --destination sim-27.2 --action test`

## Phase 6: Regression, documentation and close

- [ ] T-R02G0404-006 Docs: `docs/architecture/hue-compass.md` (interaction), `Packages/ExperiencesRound02/README.md`,
  `docs/automatedtesting.md`; `--name round02-host`
- [ ] T-R02G0404-007 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`,
  `--name host-full`, `--name app-unit`
- [ ] T-R02G0404-008 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G0404-009 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G0404-010 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G0404-011 {device} After ImplementationLock-100, on D1, D2 and D3: record gesture feel and touch-to-frame
  latency (SC-R02G0404-006)
- [ ] T-R02G0404-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record

## Dependencies and parallel work

001 → 002 (agent B) → {003 (agent C), 004 (agent D)} → 005 (lead; agent E writes the wiring tests) → 006 … 010, 012.
011 stays open until device testing. Shared files (presenter, scene, controls, docs) stay with the lead. MVP: Stories 1–3.
