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

- [X] T-R02G0404-002 Edit `Packages/ExperiencesRound02/HueCompass/Core/HueCompassSceneGeometry.swift` (`HueCompassOrbit` "yaw −40° … 40°, tilt 15° … 60°, — Verified 2026-11-21: 2026-11-21 host-2 exit 0 (agent B: HueCompassOrbit yaw ±40°, tilt 15° … 60°, authored 35°, camera(aspect:orbit:) with the authored orbit bit-equal to camera(aspect:); HueCompassDial centre, hub ≥ 30 pt, angle with the 20 pt dead zone, shortest-way accumulation, rounding and wrapping; 300 seeded swipes; every orbit limit × 7 aspects keeps the compass inside with 5 %)
  authored 35°", `camera(aspect:orbit:)` refitting the 1.45 sphere for a 5 % margin; `camera(aspect:)` equals the
  authored orbit) and create `Packages/ExperiencesRound02/HueCompass/Core/HueCompassDial.swift` (projected centre, hub radius "0.3 world units, at least 30
  points", angle atan2(−dy, dx) with "dead zone 20 points", steps round(angle · 96 / 2π), wrapping into "−47 … 48") with
  `Packages/ExperiencesRound02/HueCompass/CoreTests/HueCompassDialTests.swift` and orbit framing tests in `Packages/ExperiencesRound02/HueCompass/CoreTests/HueCompassSceneGeometryTests.swift`
  (agent B: angles and hub against an independent computation; every orbit limit and 7 aspects keep the compass inside
  with 5 %); `--name host-2`

## Phase 3: Stories 1, 2 and 3 — swipe, press, orbit (P1) 🎯

- [X] T-R02G0404-003 [US1] [US2] [US3] Create `Packages/ExperiencesRound02/HueCompass/Core/HueCompassGestureController.swift` (idle, swiping, orbiting, — Verified 2026-11-21: 2026-11-21 host-3 exit 0 (agent C: gesture controller idle/swiping/orbiting/cancelled; 500 seeded swipes at 3 views equal an independent screen-geometry computation; hub taps probe, a tap is a touch whose farthest travel stays under 10 pt; double tap outside the wheel within 0.35 s resets; second finger cancels and orbits at 90° per width and 60° per height, clamped; nothing while not playing; 9 tests)
  cancelled; accumulated angle with the dead zone; preview bearing; release sends at most one `turn(steps)`, "tap
  within 10 points" in the hub sends `probe`, double tap "within 0.35 s" outside the wheel resets the view; a second
  finger cancels and orbits "90° per view width, 60° per view height"; nothing while not playing) with
  `Packages/ExperiencesRound02/HueCompass/CoreTests/HueCompassGestureControllerTests.swift` (agent C: 500 seeded swipes equal an independent computation;
  every arbitration case of SC-R02G0404-002; orbit rates and limits; determinism); `--name host-3`

## Phase 4: Story 4 — play with the panel alone (P1)

- [X] T-R02G0404-004 [US4] Create `Packages/ExperiencesRound02/HueCompass/CoreTests/HueCompassPanelWinTests.swift` (agent D: all 100 certified levels won — Verified 2026-11-21: 2026-11-21 host-4 exit 0 (agent D: all 100 certified levels won through the panel's actions — witness turns as ±4 and ±1 presses, probes, the selection — one test per band, each about 1–2 s)
  through the adapter actions the panel sends — a witness turn of k as ⌊|k|/4⌋ turns of ±4 and |k| mod 4 turns of ±1,
  then the probe and the select — split by band); `--name host-4`

## Phase 5: Wiring — preview, presenter, panel

- [X] T-R02G0404-005 Edit `Packages/ExperiencesRound02/HueCompass/Experience/HueCompassPresenter.swift` (pointer entry through the gesture controller, — Verified 2026-11-21: 2026-11-21 sim-27 exit 0 (agent E wired the presenter, scene and controls: pointer entry through the gesture controller, orbit camera, ghost needle at the preview, 'Turning to bearing n of 96', Reset view; 6 wiring tests on sim-27.2: swipes turn by the scripted steps, hub tap probes, orbit never changes the digest, reset and double tap, cancel sends nothing, nothing while won; 25 Hue Compass simulator tests pass)
  `resetView()`, orbit-aware camera, ghost needle at the preview, description "Turning to bearing n of 96"),
  `Packages/ExperiencesRound02/HueCompass/Experience/HueCompassCompassScene.swift` (orbit camera, ghost needle "pearl at half opacity") and
  `Packages/ExperiencesRound02/HueCompass/Experience/HueCompassControls.swift` ("Reset view"), with `Packages/ExperiencesRound02/HueCompass/ExperienceTests/HueCompassGestureWiringTests.swift`
  (agent E: scripted swipes and hub taps through the experience's pointer entry turn and probe; orbit never changes the
  digest); `--name sim-27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme
  ExperiencesRound02-Package --destination sim-27.2 --action test`

## Phase 6: Regression, documentation and close

- [X] T-R02G0404-006 Docs: `docs/architecture/hue-compass.md` (interaction), `Packages/ExperiencesRound02/README.md`, — Verified 2026-11-21: 2026-11-21 round02-host exit 0; docs/architecture/hue-compass.md (interaction), Packages/ExperiencesRound02/README.md, docs/automatedtesting.md (atan2 negative zero)
  `docs/automatedtesting.md`; `--name round02-host`
- [X] T-R02G0404-007 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`, — Verified 2026-11-21: 2026-11-21 rendering-27, rendering-26, experiences, host-full, app-unit exit 0
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

## Phase 7: Convergence

- [ ] T-R02G0404-013 Add `cancel()` to `Packages/ExperiencesRound02/HueCompass/Core/HueCompassGestureController.swift` (drops the pointers and any swipe, sends nothing, keeps the orbit), use it in `HueCompassPresenter.cancelPointers()` instead of replacing the controller, with a host test in `HueCompassGestureControllerTests.swift` (cancel mid-swipe and mid-orbit: no action, orbit kept, next gesture works), per FR-R02G0404-003 / clarification Q3 (partial); `--name host-5 -- swift test --package-path Packages/ExperiencesRound02 --filter HueCompassGestureControllerTests` and the wiring tests on sim-27.2 (`--name sim-27-2`)
