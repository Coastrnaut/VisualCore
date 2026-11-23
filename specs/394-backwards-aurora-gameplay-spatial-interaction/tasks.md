# Tasks: R02-G10-04 — Backwards Aurora: gameplay spatial interaction

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G10-04 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G10-04 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_394;
tests stay short (< 10 s each). No {owner} tasks.

## Phase 1: Setup

- [X] T-R02G1004-001 Baselines on the committed tree: `--name baseline-host`, `--name baseline-timing`, `--name — Verified 2026-11-22: 2026-11-22: baseline-host, baseline-timing, baseline-round02 exit 0; rendering baseline is R02-G10-03's rendering runs (exit 0)
  baseline-round02 -- swift test --package-path Packages/ExperiencesRound02`; the rendering baseline is R02-G10-03's
  rendering runs (exit 0)

## Phase 2: Foundational — preview field, orbit and picking

- [X] T-R02G1004-002 Add the snapshot's `preview` samples ("would-be samples; empty when none") and — Verified 2026-11-22: host (130 BackwardsAurora tests: the snapshot's preview samples and withPreview; preview material 13 (dashed highlight, alpha 0.6) in the shaders with its source tests) exit 0, lead
  `withPreview(_:)` to `Packages/ExperiencesRound02/BackwardsAurora/Core/BackwardsAuroraSceneSnapshot.swift` and the preview material (code 13, a pale dashed
  copy of the ribbon) to `Packages/ExperiencesRound02/BackwardsAurora/Core/BackwardsAuroraShaders.swift` with its source test in
  `Packages/ExperiencesRound02/BackwardsAurora/CoreTests/BackwardsAuroraShaderSourceTests.swift`; `--name host`
- [X] T-R02G1004-003 [P] Add `BackwardsAuroraOrbit` ("yaw ±35°, pitch −15° … +20°, authored (0, 0)"), — Verified 2026-11-22: host-2 (139 tests incl. BackwardsAuroraPickerTests 4 (500 seeded picks against an independent pick over 5 levels, 3 sizes, 3 orbits; the 22-point target at 21/23 points; ends win; unusable input) and 3 new geometry tests (orbit framing at 9 orbits × 7 aspects; camera(_:aspect:) bit-identical to the authored orbit; preview ribbon code 13 exactly when previewed)) exit 0, lead retest; the invariant scan skips the picker, freeze preview and gesture controller (presentation sources)
  `camera(_:aspect:orbit:)` (distance refit so the authored box stays inside the view with a 5 % margin;
  `camera(_:aspect:)` equals the authored orbit, bit-identical) and the preview ribbon (the would-be samples as a
  dashed strip at z = 0.01, preview material) to `Packages/ExperiencesRound02/BackwardsAurora/Core/BackwardsAuroraSceneGeometry.swift`; create
  `Packages/ExperiencesRound02/BackwardsAurora/Core/BackwardsAuroraPicker.swift` (touch ray through the drawn camera meeting z = 0; an end of the section whose
  projected sample point lies within 22 points first (nearer end, ties to the start), then the band (x within x(start)
  − u/2 … x(end) + u/2, |y| ≤ 0.7), then the sample column (x(k) ± u/2, |y| ≤ 0.75), else empty; `column` clamped to
  the wave) with `Packages/ExperiencesRound02/BackwardsAurora/CoreTests/BackwardsAuroraPickerTests.swift` (an independent pick written in the test on 500 seeded
  points over certified levels, sizes and orbits; minimum target) and orbit framing and the preview ribbon in
  `Packages/ExperiencesRound02/BackwardsAurora/CoreTests/BackwardsAuroraSceneGeometryTests.swift`; agent B; `--name host-2`

## Phase 3: Stories 1 to 3 — tap ends, swipe with freeze preview, drag ends (P1) 🎯

- [ ] T-R02G1004-004 [US1] [US2] [US3] Create `Packages/ExperiencesRound02/BackwardsAurora/Core/BackwardsAuroraFreezePreview.swift` (the would-be samples of
  reversing [start, end] with the kernel's `BackwardsAuroraWave.reversed(start:end:)`, its bends above L, the lowest
  seam beyond B, the checkpoints it would match; text "would match 3 of 4 checkpoints, worst bend 9 of 12" or "would
  tear at seam 5") and `Packages/ExperiencesRound02/BackwardsAurora/Core/BackwardsAuroraGestureController.swift` (states idle, samplePress, endDrag, bandPress,
  swipe, freeze, orbiting, cancelled; a tap (< 10 points, ≤ 0.5 s) on a sample or the band: setStart/setEnd per
  clarification Q2 (left of the start moves it, right of the end moves it, inside moves the nearer end, ties to the
  start; on an end nothing); an end drag (≥ 16 points): the end follows the column, clamped so start < end; a band drag
  with |dx| ≥ 2·|dy|: a swipe, the preview while it lasts, `reverse(start, end)` on release while playing; a band
  press held 0.5 s without moving 10 points: freeze (preview; lift sends nothing; never becomes a swipe); a second
  finger cancels and orbits (yaw 90° per width, pitch 60° per height, clamped; a third re-bases); a double tap (≤ 0.35
  s, ≤ 22 points) on empty space: `resetView`; 10 … 16 points: nothing; on a finished play no reverse; cancelled phases
  send nothing; only event timestamps read; `tick(at:)` turns a held press into a freeze) with
  `Packages/ExperiencesRound02/BackwardsAurora/CoreTests/BackwardsAuroraGestureControllerTests.swift` (500 seeded scripted gestures against an independent
  expectation over 3 sizes and 3 orbits; second fingers, cancels and finished plays send nothing; every freeze preview
  equals the kernel's reversal; previews and orbit change no digest); agent C; `--name host-3`

## Phase 4: Story 5 — every move without gestures (P1)

- [X] T-R02G1004-005 [P] [US5] Create `Packages/ExperiencesRound02/BackwardsAurora/CoreTests/BackwardsAuroraPanelWinTests.swift`: all 100 certified levels won — Verified 2026-11-22: host-4 (132 tests incl. BackwardsAuroraPanelWinTests: all 100 certified levels won through the panel's start and end steppers and Reverse alone in 10 groups (each level won in exactly its certified count); panel Undo then Redo restore the digests) exit 0, lead retest
  through panel actions only (the start and end steppers then Reverse send `wave.reverse`), split so each test is
  under 10 s, plus panel Undo then Redo after a reversal restoring the digests before and after it; agent D; `--name
  host-4`

## Phase 5: Story 4 and wiring — orbit, reset, presenter

- [ ] T-R02G1004-006 [US4] Wire `Packages/ExperiencesRound02/BackwardsAurora/Experience/BackwardsAuroraPresenter.swift` (`pointer(_:viewSize:port:)` routing
  through the gesture controller with the mirror's section; setStart and setEnd changing the mirror; reverse sent
  through the port; `resetView()`; the freeze preview drawn and described while it lasts; for a reverse on a finished
  play, "The play is over: undo or go to the next level"; a refused reversal shown in the mirror message and logged with
  its code), `Packages/ExperiencesRound02/BackwardsAurora/Experience/BackwardsAuroraAuroraScene.swift` (the orbit's camera; the preview ribbon; time effects
  held while previewing; the fallback follows) and `Packages/ExperiencesRound02/BackwardsAurora/Experience/BackwardsAuroraControls.swift` ("Reset view"); agent
  E writes `Packages/ExperiencesRound02/BackwardsAurora/ExperienceTests/BackwardsAuroraGestureWiringTests.swift` (touches through the pointer entry move ends,
  reverse by swipe and freeze by hold as expected; orbit and reset change no digest; a refused reversal is shown);
  `--name sim-27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme
  ExperiencesRound02-Package --destination sim-27.2 --action test --only-testing BackwardsAuroraExperienceTests`

## Phase 6: Regression, documentation and close

- [ ] T-R02G1004-007 Docs: `docs/architecture/backwards-aurora.md` (gestures), `Packages/ExperiencesRound02/README.md`,
  `docs/automatedtesting.md`; `--name round02-host`
- [ ] T-R02G1004-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`,
  `--name host-full`, `--name app-unit`
- [ ] T-R02G1004-009 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G1004-010 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G1004-011 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G1004-012 {device} After ImplementationLock-100: touch feel and latency on D1/D2/D3 (SC-R02G1004-007)
- [ ] T-R02G1004-013 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record

## Dependencies and parallel work

001 → 002 (lead) → {003 (agent B), 005 (agent D)} → 004 (agent C, on B's picker) → 006 (lead; agent E writes the wiring
tests) → 007 … 011, 013. 012 stays open until device testing. Shared files (snapshot, shaders, presenter, scene,
controls, docs) stay with the lead. MVP: Stories 1 to 3 and 5.
