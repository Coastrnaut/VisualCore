# Tasks: R02-G15-04 — Voxel Origami: gameplay spatial interaction

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G15-04 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G15-04 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_444;
tests stay short (< 10 s each). No {owner} tasks. Lessons of features 424 and 434 taken into the first pass: refusal
codes may carry the engine's `action.rule.` prefix; the wiring-test agent gets the presenter's exact texts; the
offscreen host resizes before every still, so the meshes are rebuilt when the orbit (the drawn eye) changes, never on a
resize alone.

## Phase 1: Setup

- [X] T-R02G1504-001 Baselines on the committed tree after R02-G15-03 is recorded: `--name baseline-host`, `--name — Verified 2026-11-24: 2026-11-24: baseline-host, baseline-timing, baseline-round02 exit 0 on the committed tree after R02-G15-03's record
  baseline-timing`, `--name baseline-round02 -- swift test --package-path Packages/ExperiencesRound02`; the rendering
  baseline is R02-G15-03's rendering runs (exit 0)

## Phase 2: Foundational — orbit, camera, picking and prediction

- [X] T-R02G1504-002 [P] Add `VoxelOrigamiOrbit` ("yaw ±60°, pitch −20° … +35°; authored (0, 0); presentation only", — Verified 2026-11-24: 2026-11-24: agent B orbit (yaw ±60°, pitch −20…+35°), camera(_:aspect:orbit:) bit-identical at the authored orbit, camera-taking mesh overloads, VoxelOrigamiPicker (front-most cube outline + 8 pt) and turn prediction; lead changed the prediction from the swinging centroid to the tracked cube (farthest from the hinge line; a symmetric subtree's centroid never moves) in code, test reference, spec Q2/FR-001, research, data model, tasks and CHK006, with a symmetric-subtree test; host-2 and host-2b exit 0
  `clamped()`), `camera(_:aspect:orbit:)` (yaw about the vertical axis through the authored box centre, pitch about the
  authored view; field of view refit so the box x −0.95 … 0.95, y −1.25 … 0.95, z −0.95 … 0.95 stays inside the view
  with at least a 5 % margin at aspects 0.4 … 2.5; the eye outside the box; `camera(_:aspect:)` equals the authored
  orbit, bit-identical) and camera-taking `voxelMesh`, `glowMesh`, `voxelPart`, `glowPart` (billboards, paint order and
  winding for the given camera; the existing signatures use the authored camera, unchanged) to
  `Packages/ExperiencesRound02/VoxelOrigami/Core/VoxelOrigamiSceneGeometry.swift`; create
  `Packages/ExperiencesRound02/VoxelOrigami/Core/VoxelOrigamiPicker.swift` (FR-R02G1504-001, 003; SC-R02G1504-001, 004;
  `VoxelOrigamiPick` cube(index), empty; `viewPoint` projects a world point through the drawn camera into view points
  with the origin top-left, nil behind the eye; `outline` the counter-clockwise convex hull of a cube's eight projected
  corners (side 0.9 s, turned by its orientation); `pick`: the front-most cube (drawn last in the paint order) whose
  outline grown by 8 points holds the point, else empty; empty for unusable input; `VoxelOrigamiTurnPrediction` "nil
  when the hinge swings nothing or for the root" with the projected centre of the tracked cube (`trackedCube`: of the swinging cubes, the one farthest from the hinge
  line, lowest index on ties) after a +1 and a −1
  turn minus before, and `step(for:threshold:)` choosing the sign with the larger projection of the travel once it
  reaches the threshold) with `Packages/ExperiencesRound02/VoxelOrigami/CoreTests/VoxelOrigamiPickerTests.swift` (an
  independent pick and prediction written in the test on 500 seeded points over certified levels, 3 sizes and 3 orbits;
  the 8-point allowance at 7 and 9 points; the front-most cube; the root; unusable input) and orbit framing in
  `Packages/ExperiencesRound02/VoxelOrigami/CoreTests/VoxelOrigamiSceneGeometryTests.swift` (every element inside the
  view at the orbit corners and 7 aspects; winding suits culling for an orbited camera); agent B; `--name host-2`

## Phase 3: Stories 1 and 2 — drags and taps (P1) 🎯

- [ ] T-R02G1504-003 [US1] [US2] Create `Packages/ExperiencesRound02/VoxelOrigami/Core/VoxelOrigamiGestureController.swift`
  (FR-R02G1504-001, 002, 004, 005; SC-R02G1504-001 … 003; `VoxelOrigamiGestureAction` chooseHinge(h), pendingTurn(hinge,
  step), clearPending, turn(hinge, step), resetView, explain(reason); states idle, cubePress, cubeDrag, emptyPress,
  orbiting, cancelled; a tap (< 10 points, lifted before 0.5 s) on a non-root cube: `chooseHinge` in any stage, and a
  second tap on the same cube within 0.35 s and 22 points while playing: `turn(h, +1)` when hinge h can turn (else
  `explain`); on the root: nothing; on empty space: nothing, two such taps within 0.35 s and 22 points: `resetView`; a
  press lifted at 0.5 s or later without moving: nothing; a drag (≥ 16 points) from a turnable non-root cube while
  playing sends `pendingTurn` when the predicted step changes (from 24 points of projected travel) and `clearPending`
  when it falls below, and on release `turn(h, step)` once; a drag from the root, an idle hinge or on another stage:
  `explain` once and nothing else; 10 … 16 points: nothing; a second finger cancels (clearing a pending turn) and orbits
  (yaw 90° per width, pitch 60° per height, clamped; a third re-bases); cancelled phases send nothing; only event
  timestamps read) with `Packages/ExperiencesRound02/VoxelOrigami/CoreTests/VoxelOrigamiGestureControllerTests.swift`
  (500 seeded scripted taps and drags against an independent expectation over certified levels at playing, won and
  failed plays, 3 sizes and 3 orbits, every kernel action applied through the adapter; second fingers, cancels and
  finished plays send no kernel action; orbit changes no digest); agent C; `--name host-3`

## Phase 4: Story 4 — every move without gestures (P1)

- [X] T-R02G1504-004 [P] [US4] Create `Packages/ExperiencesRound02/VoxelOrigami/CoreTests/VoxelOrigamiPanelWinTests.swift`: — Verified 2026-11-24: 2026-11-24: agent D, all 100 certified levels won through panel actions only (hinge −/+ then turn −/+) in ten groups, panel undo/redo restore digests on levels 41, 61, 81 (level 1 wins in two turns, and a won play refuses undo); lead retest host-4 exit 0
  all 100 certified levels won through panel actions only (FR-R02G1504-006; SC-R02G1504-005; hinge − and + through
  `hinge.choose` to each witness turn's hinge, then turn − or +), split so each test is under 10 s, plus panel Undo then
  Redo restoring the digests; agent D; `--name host-4`

## Phase 5: Story 3 and wiring — orbit, reset, presenter

- [ ] T-R02G1504-005 [US3] Wire `Packages/ExperiencesRound02/VoxelOrigami/Experience/VoxelOrigamiPresenter.swift`
  (FR-R02G1504-001 … 007; `pointer(_:viewSize:port:)` routing through the gesture controller with the drawn snapshot;
  turn sent through `hinge.turn`, chooseHinge through `hinge.choose`; the pending turn in the description and the panel
  ("Turn hinge h forward" or "back"); explain texts "The root cube has no hinge", "Nothing would move: hinge h swings no
  cube"; on a won or failed play `describe` says "The play is over: undo or go to the next level"; a refused action shown
  in the mirror message and logged with its code, reading codes with or without the engine's `action.rule.` prefix;
  `resetView()`), `Packages/ExperiencesRound02/VoxelOrigami/Experience/VoxelOrigamiVoxelScene.swift` (the orbit's camera
  and meshes, rebuilt when the orbit changes) and `Packages/ExperiencesRound02/VoxelOrigami/Experience/VoxelOrigamiControls.swift`
  ("Reset view", the pending line); agent E writes
  `Packages/ExperiencesRound02/VoxelOrigami/ExperienceTests/VoxelOrigamiGestureWiringTests.swift` (touches through the
  pointer entry choose a hinge by a tap, turn it by a drag and by a double tap; orbit and reset change no digest; a
  refused or failing turn is shown; a drag on a won play sends nothing and says the play is over), given the presenter's
  exact status and description texts; `--name sim-27 -- python3 scripts/xcodebuild_package.py --package
  Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package --destination sim-27.2 --action test --only-testing
  VoxelOrigamiExperienceTests`

## Phase 6: Regression, documentation and close

- [ ] T-R02G1504-006 Docs: `docs/architecture/voxel-origami.md` (gestures), `Packages/ExperiencesRound02/README.md`,
  `docs/automatedtesting.md`; `--name round02-host` (split by test bundle if it nears 450 s)
- [ ] T-R02G1504-007 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`,
  `--name host-full`, `--name app-unit`
- [ ] T-R02G1504-008 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G1504-009 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G1504-010 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G1504-011 {device} After ImplementationLock-100: touch feel and latency on D1/D2/D3 (SC-R02G1504-007)
- [ ] T-R02G1504-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record;
  README row and gate list updated

## Dependencies and parallel work

001 → {002 (agent B), 004 (agent D)} → 003 (agent C, on B's picker contract in contracts/api.md) → 005 (lead; agent E
writes the wiring tests) → 006 … 010, 012. 011 stays open until device testing. Agents B and D may start in isolated
copies before 001 (their files are new or B-only). Shared files (presenter, scene, controls, docs) stay with the lead.
MVP: Stories 1, 2 and 4. Requirement coverage: FR-001 → 002, 003, 005; FR-002 → 003, 005; FR-003 → 002; FR-004 → 002,
003, 005; FR-005 → 003, 005; FR-006 → 004, 005; FR-007 → 003, 005 … 010.
