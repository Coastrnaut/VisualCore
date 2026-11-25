# Tasks: R02-G16-04 — Starlit Cartouche: gameplay spatial interaction

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G16-04 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G16-04 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_454;
tests stay short (< 10 s each). No {owner} tasks. Lessons taken into the first pass: refusal codes may carry the
engine's `action.rule.` prefix; the wiring-test agent gets the presenter's exact texts; the offscreen host resizes
before every still, so the meshes are rebuilt when the orbit (the drawn eye) changes, never on a resize alone; one agent
owns the snapshot fields, the preview geometry and its shader material (R02-G16-03's vertex-contract lesson).

## Phase 1: Setup

- [X] T-R02G1604-001 Baselines on the committed tree after R02-G16-03 is recorded: `--name baseline-host`, `--name — Verified 2026-11-24: baseline-host, baseline-timing, baseline-round02-1..3 exit 0 (.autonomy/migration/checks/R02-G16-04.baseline-*.json)
  baseline-timing`, `--name baseline-round02-1 … 3` (the three round-two filters of feature 446); the rendering
  baseline is R02-G16-03's rendering runs (exit 0)

## Phase 2: Foundational — orbit, camera, launch preview and picking

- [X] T-R02G1604-002 [P] Add `launchBeat` ("beat + chosen wait") and `launchPositions` ("every star at the launch beat; — Verified 2026-11-24: host-2 exit 0 (.autonomy/migration/checks/R02-G16-04.host-2.json); snapshot launch beat and positions, orbit and orbiting camera (authored bit-identical), launch preview ribbon and material 22, camera-taking meshes, picker with 500-point independent test; sim test support gains the preview element kind
  presentation only; never in the digest; at wait 0 equal to the current positions") to
  `Packages/ExperiencesRound02/StarlitCartouche/Core/StarlitCartoucheSceneSnapshot.swift`; add `StarlitCartoucheOrbit`
  ("yaw ±60°, pitch −20° … +35°; authored (0, 0); presentation only", `clamped()`), `camera(_:aspect:orbit:)` (yaw about
  the vertical axis through the authored box centre, pitch about the authored view; field of view refit so the box x
  −0.95 … 0.95, y −1.45 … 0.95, z −0.95 … 0.95 stays inside the view with at least a 5 % margin at aspects 0.4 … 2.5;
  the eye outside the box; `camera(_:aspect:)` equals the authored orbit, bit-identical), `launchCentre`, the stars and
  the ship drawn at the launch positions, `previewEnds` and the preview ribbon ("dashed sapphire ribbon 0.03 wide,
  a_normal.x distance along; drawn only while playing and when a corridor joins the ship's star and the destination",
  from the ship's star at L to the destination at L + travel; trails stay where flown) and camera-taking `chartMesh`,
  `glowMesh`, `chartPart`, `glowPart` (billboards and paint order for the given camera; the existing signatures use the
  authored camera) to `Packages/ExperiencesRound02/StarlitCartouche/Core/StarlitCartoucheSceneGeometry.swift`; add
  material 22 `preview` (dashed, ship colour) to
  `Packages/ExperiencesRound02/StarlitCartouche/Core/StarlitCartoucheShaders.swift`; create
  `Packages/ExperiencesRound02/StarlitCartouche/Core/StarlitCartouchePicker.swift` (FR-R02G1604-002, 005;
  SC-R02G1604-001, 004; `StarlitCartouchePick` star(index), ship, slider, empty; `viewPoint` projects a world point
  through the drawn camera into view points with the origin top-left, nil behind the eye; `pick`: the front-most star
  (drawn last in the paint order) whose projected ring radius 0.098 grown by 8 points holds the point — the ship's star
  is `ship` — else the slider when inside the projected wait-pip box grown by 8 points, else empty; empty for unusable
  input; `sliderWait`: the pip nearest to the point's projection onto the screen line through pips 0 and 8, clamped 0 …
  8) with `Packages/ExperiencesRound02/StarlitCartouche/CoreTests/StarlitCartouchePickerTests.swift` (an independent
  pick and slider rule written in the test on 500 seeded points over certified levels, 3 sizes, 3 orbits and waits 0, 4
  and 8; the 8-point allowance at 7 and 9 points; the front-most star; the ship; unusable input) and in
  `Packages/ExperiencesRound02/StarlitCartouche/CoreTests/StarlitCartoucheSceneGeometryTests.swift` (every element
  inside the view at the orbit corners, waits 0 … 8 and 7 aspects; the stars at the launch positions; the preview
  ribbon's ends and its absence without a corridor or outside playing; wait 0 identical to R02-G16-03's geometry) and
  `Packages/ExperiencesRound02/StarlitCartouche/CoreTests/StarlitCartoucheShaderSourceTests.swift` (the new material);
  agent B; `--name host-2`

## Phase 3: Stories 1, 2 and 3 — taps, the slider and ship drags (P1) 🎯

- [X] T-R02G1604-003 [US1] [US2] [US3] Create — Verified 2026-11-24: host-3 exit 0 (.autonomy/migration/checks/R02-G16-04.host-3.json); gesture controller (taps, double taps, slider and ship drags, orbit, cancellation), 500 seeded scripts against an independent expectation, run with the real picker (agent's stand-in discarded)
  `Packages/ExperiencesRound02/StarlitCartouche/Core/StarlitCartoucheGestureController.swift` (FR-R02G1604-001, 002,
  004, 006, 007; SC-R02G1604-001 … 003; `StarlitCartoucheGestureAction` chooseDestination(star), chooseWait(wait),
  fly(star, wait), preview(star), clearPreview, resetView, explain(reason); states idle, starPress, shipPress, shipDrag,
  sliderDrag, emptyPress, orbiting, cancelled; a tap (< 10 points, lifted before 0.5 s) on a star other than the ship's:
  `chooseDestination` in any stage, and a second tap on the same star within 0.35 s and 22 points while playing:
  `fly(star, wait)`; on the ship: nothing; on the slider: `chooseWait` of its nearest pip; on empty space: nothing, two
  such taps within 0.35 s and 22 points: `resetView`; a press lifted at 0.5 s or later without moving: nothing; a slider
  drag: `chooseWait` on every change from touch-down, any stage; a ship drag (≥ 16 points) while playing:
  `preview(star)` when the star under the finger (not the ship's) changes, `clearPreview` when it leaves, and on release
  over such a star `fly(star, wait)` once, else `clearPreview` and `explain` when no corridor joins them; a ship drag
  outside playing: `explain` once and nothing else; 10 … 16 points: nothing; a second finger cancels (clearing a
  preview) and orbits (yaw 90° per width, pitch 60° per height, clamped; a third re-bases); cancelled phases send
  nothing; only event timestamps read) with
  `Packages/ExperiencesRound02/StarlitCartouche/CoreTests/StarlitCartoucheGestureControllerTests.swift` (500 seeded
  scripted taps, slider drags and ship drags against an independent expectation over certified levels at playing, won
  and failed plays, 3 sizes and 3 orbits, every kernel action applied through the adapter; second fingers, cancels and
  finished plays send no kernel action; orbit and the preview change no digest); agent C; `--name host-3`

## Phase 4: Story 5 — every move without gestures (P1)

- [X] T-R02G1604-004 [P] [US5] Create — Verified 2026-11-24: host-4 exit 0 (.autonomy/migration/checks/R02-G16-04.host-4.json); all 100 certified levels won through panel actions (route.choose stepping, route.fly), undo/redo digests
  `Packages/ExperiencesRound02/StarlitCartouche/CoreTests/StarlitCartouchePanelWinTests.swift`: all 100 certified levels
  won through panel actions only (FR-R02G1604-008; SC-R02G1604-005; star − and + and wait − and + through
  `route.choose` to each witness leg's destination and wait, then fly), split so each test is under 10 s, plus panel
  Undo then Redo restoring the digests; agent D; `--name host-4`

## Phase 5: Story 4 and wiring — orbit, reset, presenter

- [X] T-R02G1604-005 [US4] Wire — Verified 2026-11-24: sim-27 exit 0, 35 simulator tests incl. 9 gesture wiring tests (.autonomy/migration/checks/R02-G16-04.sim-27.json; sim-27a exit 0 before the wiring tests); presenter pointer entry, preview restore, refusal log, orbit in the scene, Reset view and pending line in the panel
  `Packages/ExperiencesRound02/StarlitCartouche/Experience/StarlitCartouchePresenter.swift` (FR-R02G1604-001 … 009;
  `pointer(_:viewSize:port:)` routing through the gesture controller with the drawn snapshot; fly sent through
  `route.fly`, the choices and the preview's destination through `route.choose` (on `clearPreview` the destination
  chosen before the ship drag is restored through `route.choose`); the pending leg in the description and the panel;
  explain texts for the ship's own star, a missing corridor and a finished play ("The play is over: undo or go to the
  next level"); a refused action shown in the mirror message and logged with its code, reading codes with or without the
  engine's `action.rule.` prefix; `resetView()`),
  `Packages/ExperiencesRound02/StarlitCartouche/Experience/StarlitCartoucheChartScene.swift` (the orbit's camera and
  meshes, rebuilt when the orbit changes) and
  `Packages/ExperiencesRound02/StarlitCartouche/Experience/StarlitCartoucheControls.swift` ("Reset view", the pending
  line); agent E writes
  `Packages/ExperiencesRound02/StarlitCartouche/ExperienceTests/StarlitCartoucheGestureWiringTests.swift` (touches
  through the pointer entry choose a star by a tap, fly by a double tap and by a ship drag, set the wait on the slider;
  orbit and reset change no digest; a refused or failing leg is shown; a ship drag on a won play sends nothing and says
  the play is over), given the presenter's exact status and description texts; `--name sim-27 -- python3
  scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package --destination
  sim-27.2 --action test --only-testing StarlitCartoucheExperienceTests`

## Phase 6: Regression, documentation and close

- [X] T-R02G1604-006 Docs: `docs/architecture/starlit-cartouche.md` (gestures and the launch preview), — Verified 2026-11-24: round02-host-1..3 exit 0 (.autonomy/migration/checks/R02-G16-04.round02-host-*.json; chunk 3 337 s); architecture, package README and testing doc updated
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host-1 … 3`
- [ ] T-R02G1604-007 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`,
  `--name host-full`, `--name app-unit`
- [ ] T-R02G1604-008 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G1604-009 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G1604-010 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G1604-011 {device} After ImplementationLock-100: touch feel and latency on D1/D2/D3 (SC-R02G1604-007)
- [ ] T-R02G1604-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record;
  README row and gate list updated

## Dependencies and parallel work

001 → {002 (agent B), 004 (agent D)} → 003 (agent C, on B's contract) → 005 (lead; agent E writes the wiring tests) →
006 … 010, 012. 011 stays open until device testing. Agents may draft in isolated copies before 001 (new files only).
Requirement coverage: FR-001 → 003, 005; FR-002 → 002, 003; FR-003 → 002; FR-004 → 003; FR-005 → 002; FR-006 → 002,
003, 005; FR-007 → 003, 005; FR-008 → 004, 005; FR-009 → 005 … 010.
