# Tasks: R02-G18-04 — Apsides Workshop: gameplay spatial interaction

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G18-04 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G18-04 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_474;
tests stay short (< 10 s each). No {owner} tasks. Lessons taken into the first pass: refusal codes carry the engine's
`action.rule.` prefix; the wiring-test agent gets the presenter's exact texts; meshes are rebuilt when the orbit (the
drawn eye) changes, never on a resize alone; one agent owns the snapshot fields, the ghost geometry and its shader
material (the vertex-contract lesson of R02-G16-03 and R02-G17-03); the panel's − and + move a pending orbit (the lesson
of R02-G17-04's CHK013).

## Phase 1: Setup

- [X] T-R02G1804-001 Baselines on the committed tree after R02-G18-03 is recorded: `--name baseline-host`, `--name — Verified 2026-11-25: 2026-11-25 baseline-host, baseline-timing and round02-1, -2, -3c, -3e, -3f exit 0 on the committed R02-G18-03 record; rendering baseline is R02-G18-03's rendering runs (exit 0)
  baseline-timing`, `--name baseline-round02-1`, `-2`, `-3c`, `-3e`, `-3f`; the rendering baseline is R02-G18-03's
  rendering runs (exit 0)

## Phase 2: Foundational — view orbit, camera, tuning preview and picking

- [X] T-R02G1804-002 [P] Add `previewOrbit` ("nil when no preview"), `previewPositions` and `previewGauges` ("the — Verified 2026-11-25: 2026-11-25 view orbit, camera(aspect:orbit:), preview fields, ghost (material 22) and ApsidesWorkshopPicker with picker, geometry and shader tests (40) pass (host-2 exit 0)
  kernel's positions and readings of the previewed orbit; presentation only; never in the digest; only for a valid
  pending orbit") and `previewing(_:)` to
  `Packages/ExperiencesRound02/ApsidesWorkshop/Core/ApsidesWorkshopSceneSnapshot.swift`; add `ApsidesWorkshopViewOrbit`
  ("yaw ±60°, pitch −20° … +35°; authored (0, 0); presentation only", `clamped()`), `camera(aspect:orbit:)` (yaw about
  the vertical axis through the authored box centre, pitch about the authored view; refit so the box x −1.0 … 1.0, y
  −1.65 … 1.0 stays inside the view with at least a 5 % margin at aspects 0.4 … 2.5; the eye outside the box;
  `camera(aspect:)` equals the authored orbit, bit-identical), `knobCentre`, `handleCentre`, the ghost (the previewed
  orbit's positions as a dashed loop with outlined apsis markers, material 22 `ghostPreview`), the gauges drawn from the
  preview's readings while previewing, and camera-taking `compassMesh`, `glowMesh`, `compassPart`, `glowPart`
  (billboards for the given camera; the existing signatures use the authored camera) to
  `Packages/ExperiencesRound02/ApsidesWorkshop/Core/ApsidesWorkshopSceneGeometry.swift`; add material 22 `ghostPreview`
  to `Packages/ExperiencesRound02/ApsidesWorkshop/Core/ApsidesWorkshopShaders.swift`; create
  `Packages/ExperiencesRound02/ApsidesWorkshop/Core/ApsidesWorkshopPicker.swift` (FR-R02G1804-001 … 003, 005;
  SC-R02G1804-001, 004; `ApsidesWorkshopPick` orbiter, sizeHandle, knob, loop, empty; `viewPoint` projects a world point
  through the drawn camera into view points with the origin top-left, nil behind the eye; `pick`: the orbiter within its
  projected radius grown by 8 points, else the apoapsis square, else the periapsis diamond within their projected
  half-size grown by 12 points, else the loop within 10 points of its projected chords, else empty; empty for unusable
  input; `skyPoint`: the view point cast onto the plane z = 0 in lattice units; `knobSteps`: d = round(angle / 15°) mod
  24 (a point at the star keeps the current direction), k = round(20 − 20 r / a) clamped to 0 … 15 at the current size;
  `handleSize`: a = round(20 R / (20 + k)) clamped to 8 … 48 at the current knob; `crankTick`: the tick whose projected
  position is nearest to the point, lower on ties) with
  `Packages/ExperiencesRound02/ApsidesWorkshop/CoreTests/ApsidesWorkshopPickerTests.swift` (an independent pick, step
  and tick rule written in the test on 500 seeded points over certified levels, 3 sizes and 3 orbits; the allowances at
  their edges; overlapping handles; unusable input) and in
  `Packages/ExperiencesRound02/ApsidesWorkshop/CoreTests/ApsidesWorkshopSceneGeometryTests.swift` (every element and a
  ghost of extreme valid orbits inside the view at the orbit corners and 7 aspects; the ghost and preview gauges; no
  preview identical to R02-G18-03's geometry) and
  `Packages/ExperiencesRound02/ApsidesWorkshop/CoreTests/ApsidesWorkshopShaderSourceTests.swift` (the new material);
  agent B; `--name host-2`

## Phase 3: Stories 1, 2 and 3 — knob, size and crank (P1) 🎯

- [X] T-R02G1804-003 [US1] [US2] [US3] Create — Verified 2026-11-25: 2026-11-25 ApsidesWorkshopGestureController (pick order, knob/size drags with preview, invalid-orbit explanations, crank, orbit, double tap) and ApsidesWorkshopGestureControllerTests (6 tests, 500 seeded scripts against an independent expectation, thresholds at their edges); host-3 exit 0 (ApsidesWorkshopCoreTests)
  `Packages/ExperiencesRound02/ApsidesWorkshop/Core/ApsidesWorkshopGestureController.swift` (FR-R02G1804-001 … 004,
  006, 007; SC-R02G1804-001 … 003; `ApsidesWorkshopGestureAction` tunePeriapsis(k, d), tuneSize(a), showTick(tick),
  preview(orbit), clearPreview, resetView, explain(reason); states idle, knobPress, knobDrag, handlePress, handleDrag,
  orbiterPress, crankDrag, emptyPress, orbiting, cancelled; a tap (< 10 points, lifted before 0.5 s) on the orbiter or
  the loop: `showTick` in any stage; on a handle: `explain` that the handle is dragged; on empty space: nothing, two
  such taps within 0.35 s and 22 points: `resetView`; a press lifted at 0.5 s or later without moving: nothing; a crank
  drag from the orbiter: `showTick` on every change from touch-down, any stage; a knob or size drag (≥ 16 points) while
  playing: `preview(orbit)` when the pending orbit changes and is valid, `explain(reason)` once when it turns invalid,
  and on release one `tunePeriapsis` or `tuneSize` when the pending orbit is valid and differs, else `clearPreview`;
  outside playing: `explain` once and nothing else; 10 … 16 points: nothing; a second finger cancels (clearing a
  preview) and orbits (yaw 90° per width, pitch 60° per height, clamped; a third re-bases); cancelled phases send
  nothing; only event timestamps read) with
  `Packages/ExperiencesRound02/ApsidesWorkshop/CoreTests/ApsidesWorkshopGestureControllerTests.swift` (500 seeded
  scripted taps, knob, size and crank drags against an independent expectation over certified levels at playing, won and
  failed plays, 3 sizes and 3 orbits, every kernel action applied through the adapter; second fingers, cancels and
  finished plays send no kernel action; orbit and the preview change no digest); agent C; `--name host-3`

## Phase 4: Story 5 — every move without gestures (P1)

- [X] T-R02G1804-004 [P] [US5] Create — Verified 2026-11-25: 2026-11-25 ApsidesWorkshopPanelWinTests pass (host-4 exit 0): all 100 certified levels won through the modelled panel (pending orbit, Set periapsis, Set size, Play) within their budgets; undo and redo restore the digests
  `Packages/ExperiencesRound02/ApsidesWorkshop/CoreTests/ApsidesWorkshopPanelWinTests.swift`: all 100 certified levels
  won through panel actions only (FR-R02G1804-008; SC-R02G1804-005; eccentricity, direction and size − and + moving the
  pending orbit, "Set periapsis" sending one `orbit.periapsis` and "Set size" one `orbit.size`, in the witness's valid
  order, then Play; never more actions than the budget), split so each test is under 10 s, plus panel Undo then Redo
  restoring the digests; agent D; `--name host-4`

## Phase 5: Story 4 and wiring — orbit, reset, presenter, panel

- [X] T-R02G1804-005 [US4] Wire `Packages/ExperiencesRound02/ApsidesWorkshop/Experience/ApsidesWorkshopPresenter.swift` — Verified 2026-11-25: 2026-11-25 presenter pointer entry with the gesture controller, drawn preview, refusalLog and resetView; compass scene at the view orbit with camera-taking meshes; panel pending orbit with Set periapsis, Set size and Reset view (pendingReason narrowed to the pending orbit after agent E's review); ApsidesWorkshopGestureWiringTests (11); sim-27 exit 0 (ApsidesWorkshopExperienceTests, 37 tests)
  (FR-R02G1804-001 … 009; `pointer(_:viewSize:port:)` routing through the gesture controller with the drawn snapshot;
  tunings sent through `orbit.periapsis` and `orbit.size`, ticks through `clock.show`; the preview kept as presentation
  state and drawn; explain texts for a handle tap, an invalid orbit and a finished play ("The play is over: undo or go
  to the next level"); a refused action shown in the mirror message and logged with its code, reading codes with or
  without the engine's `action.rule.` prefix; `resetView()`),
  `Packages/ExperiencesRound02/ApsidesWorkshop/Experience/ApsidesWorkshopCompassScene.swift` (the orbit's camera and
  meshes, rebuilt when the orbit changes) and
  `Packages/ExperiencesRound02/ApsidesWorkshop/Experience/ApsidesWorkshopControls.swift` (− and + move the pending orbit
  and preview it; the pending orbit follows the current orbit after any accepted action and a drag's preview replaces
  it; "Set periapsis", "Set size" and "Reset view"; the pending line); agent E writes
  `Packages/ExperiencesRound02/ApsidesWorkshop/ExperienceTests/ApsidesWorkshopGestureWiringTests.swift` (touches through
  the pointer entry tune the knob and the size by drags, turn the crank; orbit and reset change no digest; a refused
  tuning is shown; a drag on a won play sends nothing and says the play is over; the panel's Set buttons), given the
  presenter's exact status and description texts; `--name sim-27 -- python3 scripts/xcodebuild_package.py --package
  Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package --destination sim-27.2 --action test --only-testing
  ApsidesWorkshopExperienceTests`

## Phase 6: Regression, documentation and close

- [X] T-R02G1804-006 Docs: `docs/architecture/apsides-workshop.md` (gestures and the tuning preview), — Verified 2026-11-25: 2026-11-25 docs/architecture/apsides-workshop.md (gameplay spatial interaction), round-two README, docs/automatedtesting.md; round02-host-1, -2, -3c, -3e, -3f exit 0
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host-1`, `-2`, `-3c`, `-3e`,
  `-3f`
- [X] T-R02G1804-007 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`, — Verified 2026-11-25: 2026-11-25 rendering-27, rendering-26, experiences, host-full, app-unit exit 0
  `--name host-full`, `--name app-unit`
- [ ] T-R02G1804-008 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G1804-009 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G1804-010 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G1804-011 {device} After ImplementationLock-100: touch feel and latency on D1/D2/D3 (SC-R02G1804-007)
- [ ] T-R02G1804-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record;
  README row and gate list updated

## Dependencies and parallel work

001 → {002 (agent B), 004 (agent D)} → 003 (agent C, on B's contract) → 005 (lead; agent E writes the wiring tests) →
006 … 010, 012. 011 stays open until device testing. Agents may draft in isolated copies before 001 (new files only).
MVP: Story 1. Requirement coverage: FR-001 → 002, 003, 005; FR-002 → 002, 003, 005; FR-003 → 002, 003; FR-004 → 002,
003; FR-005 → 002; FR-006 → 002, 003, 005; FR-007 → 003, 005; FR-008 → 004, 005; FR-009 → 005 … 010.
