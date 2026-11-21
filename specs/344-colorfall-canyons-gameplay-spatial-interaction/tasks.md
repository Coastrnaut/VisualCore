# Tasks: R02-G05-04 — Colorfall Canyons: gameplay spatial interaction

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G05-04 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G05-04 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_344;
tests stay short (< 10 s each). No {owner} tasks; no GLSL change (the highlight is a pearl outline drawn with the
existing programs).

## Phase 1: Setup

- [X] T-R02G0504-001 Baselines: `--name baseline-host`, `--name baseline-timing`, `--name baseline-round02 -- swift test — Verified 2026-11-21: 2026-11-21 baseline-host, baseline-timing, baseline-round02 exit 0 (.autonomy/migration/checks/R02-G05-04.baseline-*.json); rendering baseline: R02-G05-03 rendering-27/26 exit 0
  --package-path Packages/ExperiencesRound02`; the rendering baseline is R02-G05-03's rendering runs (exit 0)

## Phase 2: Foundational — orbit and picking

- [X] T-R02G0504-002 [P] Add `ColorfallCanyonsOrbit` ("yaw ±40°, pitch 25° … 70°, authored (0, 50°)") and — Verified 2026-11-21: 2026-11-21 host-2 exit 0: 20 tests in 2 suites (picker 5 incl. 500 seeded points vs independent pick; scene geometry 15 incl. orbit framing, authored camera bit-identical, highlight ring) (.autonomy/migration/checks/R02-G05-04.host-2.json); lead retest
  `camera(_:aspect:orbit:)` (distance refit to the bounding sphere with a 5 % margin; `camera(_:aspect:)` equals the
  authored orbit) to `Packages/ExperiencesRound02/ColorfallCanyons/Core/ColorfallCanyonsSceneGeometry.swift`; create `Packages/ExperiencesRound02/ColorfallCanyons/Core/ColorfallCanyonsPicker.swift` (touch
  ray through the drawn camera, block tops at their heights, emitter boxes of half-width 0.18·u, nearest hit, else the
  nearest projected top centre or emitter top within 22 points, else empty) with `Packages/ExperiencesRound02/ColorfallCanyons/CoreTests/ColorfallCanyonsPickerTests.swift`
  (an independent pick written in the test on 500 seeded points over certified levels, sizes and orbits; minimum target;
  hidden cells resolved to the nearer block) and orbit framing in `Packages/ExperiencesRound02/ColorfallCanyons/CoreTests/ColorfallCanyonsSceneGeometryTests.swift`
  (every element inside the view with a 5 % margin at the orbit bounds and aspects 0.4 … 2.5); `--name host-2`

## Phase 3: Stories 1 and 2 — drag to carve, tap a valve (P1) 🎯

- [X] T-R02G0504-003 [US1] [US2] Create `Packages/ExperiencesRound02/ColorfallCanyons/Core/ColorfallCanyonsGestureController.swift` (states idle, dragging, — Verified 2026-11-21: 2026-11-21 host-3 exit 0: 10 tests (4,500 seeded drags and taps vs independent expectation over 3 sizes and 3 orbits; second fingers, cancels and 6 non-playing stages send no game action; double tap; orbit clamps; carvability equals the level rule) (.autonomy/migration/checks/R02-G05-04.host-3.json); lead retest
  orbiting, cancelled; carve after ≥ 16 points from a carvable start cell; valve on a spring tap (< 10 points); double tap
  on empty space within 0.35 s resets the view; second finger cancels a drag and orbits (yaw 90° per width, pitch 60° per
  height, clamped); cancelled phases send nothing; nothing but view resets while not playing; highlighted cell from
  touch-down) with `Packages/ExperiencesRound02/ColorfallCanyons/CoreTests/ColorfallCanyonsGestureControllerTests.swift` (500 seeded scripted drags and taps
  against an independent expectation; second fingers, cancels and non-playing stages send no game action); `--name host-3`

## Phase 4: Story 4 — every move without gestures (P1)

- [X] T-R02G0504-004 [P] [US4] Create `Packages/ExperiencesRound02/ColorfallCanyons/CoreTests/ColorfallCanyonsPanelWinTests.swift`: all 100 certified levels won — Verified 2026-11-21: 2026-11-21 host-4 exit 0: 9 tests (all 100 certified levels won through panel actions in 8 groups; panel undo/redo restores digests), suite 7.6 s (.autonomy/migration/checks/R02-G05-04.host-4.json); lead retest
  through panel actions only (the picker's carvable-cell order then `canyon.carve`, the valve buttons, Run as
  `time.step` of the ticks left), split so each test is under 10 s, plus panel Undo then Redo after a carve restoring
  the digests before and after it; `--name host-4`

## Phase 5: Story 3 and wiring — orbit, reset, presenter

- [X] T-R02G0504-005 [US3] Wire `Packages/ExperiencesRound02/ColorfallCanyons/Experience/ColorfallCanyonsPresenter.swift` (`pointer(_:viewSize:port:)` routing through — Verified 2026-11-21: 2026-11-21 sim-27 exit 0: ColorfallCanyonsExperienceTests 29 tests in 5 suites on sim-27.2 incl. 4 gesture wiring tests (drag carve, spring valve, orbit/double tap/reset send nothing, cancel mid-drag) (.autonomy/migration/checks/R02-G05-04.sim-27.json); lead run
  the gesture controller, `resetView()`, gesture and native action sets, the description "Carving row r, column c" while
  dragging), `Packages/ExperiencesRound02/ColorfallCanyons/Experience/ColorfallCanyonsCanyonScene.swift` (the orbit's camera; the pearl rim ring of the highlighted
  cell, research R5, through the terrain program) and `Packages/ExperiencesRound02/ColorfallCanyons/Experience/ColorfallCanyonsControls.swift` ("Reset view"); agent E writes
  `Packages/ExperiencesRound02/ColorfallCanyons/ExperienceTests/ColorfallCanyonsGestureWiringTests.swift` (touches through the pointer entry send the expected
  actions; orbit and reset change no digest); `--name sim-27`

## Phase 6: Regression, documentation and close

- [X] T-R02G0504-006 Docs: `docs/architecture/colorfall-canyons.md` (gestures), `Packages/ExperiencesRound02/README.md`, — Verified 2026-11-21: 2026-11-21 docs updated (architecture touch controls, package README, testing lesson); round02-host exit 0 (.autonomy/migration/checks/R02-G05-04.round02-host.json); validate_docs pass
  `docs/automatedtesting.md`; `--name round02-host`
- [X] T-R02G0504-007 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`, — Verified 2026-11-21: 2026-11-21 rendering-27, rendering-26, experiences, host-full, app-unit exit 0 (.autonomy/migration/checks/R02-G05-04.*.json)
  `--name host-full`, `--name app-unit`
- [ ] T-R02G0504-008 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G0504-009 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G0504-010 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G0504-011 {device} After ImplementationLock-100: touch feel and latency on D1/D2/D3 (SC-R02G0504-006)
- [ ] T-R02G0504-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record

## Dependencies and parallel work

001 → 002 (agent B) → {003 (agent C), 004 (agent D)} → 005 (lead; agent E writes the wiring tests) → 006 … 010, 012. 011
stays open until device testing. Shared files (presenter, scene, controls, docs) stay with the lead. MVP: Stories 1, 2, 4.

## Phase 7: Convergence

- [ ] T-R02G0504-013 Add a simulator test to `Packages/ExperiencesRound02/ColorfallCanyons/ExperienceTests/ColorfallCanyonsGestureWiringTests.swift`: with the fluid shader broken (fallback), a drag from a carvable cell highlights it and the frame draws without error (the unlit pearl ring), and release still sends one carve, per FR-R02G0504-005 (partial)
