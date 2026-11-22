# Tasks: R02-G06-04 — Chrono Constellator: gameplay spatial interaction

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G06-04 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G06-04 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_354;
tests stay short (< 10 s each). No {owner} tasks; no GLSL change (the highlight is a ring drawn with the existing field
program).

## Phase 1: Setup

- [X] T-R02G0604-001 Baselines: `--name baseline-host`, `--name baseline-timing`, `--name baseline-round02 -- swift test — Verified 2026-11-21: 2026-11-21: baseline-host, baseline-timing, baseline-round02 exit 0; rendering baseline = R02-G06-03 rendering-27/26 exit 0
  --package-path Packages/ExperiencesRound02`; the rendering baseline is R02-G06-03's rendering runs (exit 0)

## Phase 2: Foundational — orbit and picking

- [X] T-R02G0604-002 [P] Add `ChronoConstellatorOrbit` ("yaw ±40°, pitch 30° … 75°, authored (0, 55°)"), — Verified 2026-11-21: 2026-11-21: host-2 (PickerTests + SceneGeometryTests, 20 tests: 500 seeded points x 3 sizes x 5 orbits vs independent pick; orbit framing at 9 orbits x 7 aspects; authored camera bit-identical) exit 0, lead retest
  `camera(_:aspect:orbit:)` (distance refit to the bounding sphere with a 5 % margin; `camera(_:aspect:)` equals the
  authored orbit) and `candidatePart(_:_:)` (the pearl ring of research R6) to
  `Packages/ExperiencesRound02/ChronoConstellator/Core/ChronoConstellatorSceneGeometry.swift`; create `Packages/ExperiencesRound02/ChronoConstellator/Core/ChronoConstellatorPicker.swift` (touch ray through the
  drawn camera; star spheres of radius 0.3·u at 0.25·u, nearest hit; else the field plane y = 0: the timeline band 0 …
  0.25·u inside the near edge, then the cell; else the nearest projected star centre within 22 points; `loopIndex` for
  a star's loop cell under a point or within 22 points; `tick` = round(tickLimit × x-fraction) clamped) with
  `Packages/ExperiencesRound02/ChronoConstellator/CoreTests/ChronoConstellatorPickerTests.swift` (an independent pick written in the test on 500 seeded points over
  certified levels, sizes and orbits; minimum target; loop index and tick formulas) and orbit framing in
  `Packages/ExperiencesRound02/ChronoConstellator/CoreTests/ChronoConstellatorSceneGeometryTests.swift` (every element inside the view with a 5 % margin at the orbit
  bounds and aspects 0.4 … 2.5); agent B; `--name host-2`

## Phase 3: Stories 1–3 — drag a star, scrub, record a hold (P1) 🎯

- [ ] T-R02G0604-003 [US1] [US2] [US3] Create `Packages/ExperiencesRound02/ChronoConstellator/Core/ChronoConstellatorGestureController.swift` (states idle, starDrag,
  scrub, orbiting, cancelled; star drag at tick 0 while playing: `phase(star, index)` after ≥ 16 points when the loop
  index differs from the current phase; scrub in playing and failed: `step(t′ − t)`, or `rewind` then `step(t′)` when
  t′ < t (no step when t′ = 0), nothing when t′ = t; long press ≥ 0.5 s under 10 points on a star at tick 0 while
  playing: `hold(star, 1, 10)` or `release(star, 1)`; tap on a star: `select(star)`; double tap on empty space within
  0.35 s: `resetView` in every stage; second finger cancels and orbits (yaw 90° per width, pitch 60° per height,
  clamped), a third re-bases; cancelled phases send nothing; only event timestamps read) with
  `Packages/ExperiencesRound02/ChronoConstellator/CoreTests/ChronoConstellatorGestureControllerTests.swift` (500 seeded scripted drags, scrubs, presses and taps
  against an independent expectation; second fingers, cancels and edits after tick 0 send no edit; every scrub ends in
  the digest of a plain replay to its tick); agent C; `--name host-3`

## Phase 4: Story 5 — every move without gestures (P1)

- [X] T-R02G0604-004 [P] [US5] Create `Packages/ExperiencesRound02/ChronoConstellator/CoreTests/ChronoConstellatorPanelWinTests.swift`: all 100 certified levels won — Verified 2026-11-21: 2026-11-21: host-4 (ChronoConstellatorPanelWinTests: all 100 levels won through panel actions in 4 groups; undo/redo digests) exit 0, lead retest
  through panel actions only (star picker order, phase − and + as `star.phase` of the neighbouring index, Run as
  `time.step` of the ticks left), split so each test is under 10 s, plus panel Undo then Redo after a phase change
  restoring the digests before and after it; agent D; `--name host-4`

## Phase 5: Story 4 and wiring — orbit, reset, presenter

- [ ] T-R02G0604-005 [US4] Wire `Packages/ExperiencesRound02/ChronoConstellator/Experience/ChronoConstellatorPresenter.swift` (`pointer(_:viewSize:port:)` routing
  through the gesture controller, `select` setting the mirror's picked star, `resetView()`, the descriptions "Star n
  (shape) would start at row r, column c", "Scrub to tick t of T" and, for a star drag or press after tick 0, "Edits
  are made at tick 0: rewind first"; a gesture's refused action shown in the mirror message like the panel's and logged
  with its code),
  `Packages/ExperiencesRound02/ChronoConstellator/Experience/ChronoConstellatorSkyScene.swift` (the orbit's camera; the candidate ring through the field program;
  fallback ring) and `Packages/ExperiencesRound02/ChronoConstellator/Experience/ChronoConstellatorControls.swift` ("Reset view"); agent E writes
  `Packages/ExperiencesRound02/ChronoConstellator/ExperienceTests/ChronoConstellatorGestureWiringTests.swift` (touches through the pointer entry send the expected
  actions; orbit and reset change no digest; a refused gesture action is shown); `--name sim-27 -- python3 scripts/xcodebuild_package.py --package
  Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package --destination sim-27.2 --action test --only-testing
  ChronoConstellatorExperienceTests`

## Phase 6: Regression, documentation and close

- [ ] T-R02G0604-006 Docs: `docs/architecture/chrono-constellator.md` (gestures), `Packages/ExperiencesRound02/README.md`,
  `docs/automatedtesting.md`; `--name round02-host`
- [ ] T-R02G0604-007 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`,
  `--name host-full`, `--name app-unit`
- [ ] T-R02G0604-008 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G0604-009 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G0604-010 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G0604-011 {device} After ImplementationLock-100: touch feel and latency on D1/D2/D3 (SC-R02G0604-007)
- [ ] T-R02G0604-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record

## Dependencies and parallel work

001 → 002 (agent B) → {003 (agent C), 004 (agent D)} → 005 (lead; agent E writes the wiring tests) → 006 … 010, 012.
004 needs only the adapter and may start with 002. 011 stays open until device testing. Shared files (presenter, scene,
controls, docs) stay with the lead. MVP: Stories 1–3 and 5.
