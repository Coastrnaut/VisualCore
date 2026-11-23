# Tasks: R02-G11-04 — Echo Cartographer: gameplay spatial interaction

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G11-04 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G11-04 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_404;
tests stay short (< 10 s each). No {owner} tasks.

## Phase 1: Setup

- [ ] T-R02G1104-001 Baselines on the committed tree: `--name baseline-host`, `--name baseline-timing`, `--name
  baseline-round02 -- swift test --package-path Packages/ExperiencesRound02`; the rendering baseline is R02-G11-03's
  rendering runs (exit 0)

## Phase 2: Foundational — orbit, camera and picking

- [ ] T-R02G1104-002 [P] Add `EchoCartographerOrbit` ("yaw ±35°, pitch −15° … +20°, authored (0, 0)", `clamped()`) and
  `camera(_:aspect:orbit:)` (yaw about the y axis through the box centre, pitch about the authored view; distance refit
  so the authored box x −1 … 1, z −1 … 1.1, y 0 … 0.8 stays inside the view with a 5 % margin at aspects 0.4 … 2.5;
  `camera(_:aspect:)` equals the authored orbit, bit-identical) to
  `Packages/ExperiencesRound02/EchoCartographer/Core/EchoCartographerSceneGeometry.swift`; create
  `Packages/ExperiencesRound02/EchoCartographer/Core/EchoCartographerPicker.swift` (`EchoCartographerPick`; the touch
  ray through the drawn camera meeting the floor plane y = 0; a marker whose projected ring centre lies within 22
  points first (nearest, ties to the lower cell index), then the cell whose square contains the hit point inside the
  chamber, else empty; `floorCell`; nil for unusable input) with
  `Packages/ExperiencesRound02/EchoCartographer/CoreTests/EchoCartographerPickerTests.swift` (an independent pick
  written in the test on 500 seeded points over certified levels, 3 sizes and 3 orbits; the 22-point target at 21/23
  points; markers win over cells; unusable input) and orbit framing in
  `Packages/ExperiencesRound02/EchoCartographer/CoreTests/EchoCartographerSceneGeometryTests.swift`; agent B; `--name
  host-2`

## Phase 3: Stories 1 to 3 — tap to pulse, drag markers, hold to claim (P1) 🎯

- [ ] T-R02G1104-003 [US1] [US2] [US3] Create
  `Packages/ExperiencesRound02/EchoCartographer/Core/EchoCartographerGestureController.swift`
  (`EchoCartographerGestureAction` pulse, claim, mark, moveCursor, resetView; states idle, cellPress, markerDrag,
  cellDrag, held, orbiting, cancelled; a tap (< 10 points, lifted before 0.5 s) on a known-open cell while playing:
  `pulse`, on another chamber cell or a marker's cell that is not known open: `moveCursor`, on empty space: nothing, two
  such taps within 0.35 s and 22 points: `resetView`; a drag (≥ 16 points) from a marker: on release over another
  chamber cell without a marker `mark` old then `mark` new, else nothing; a drag from a cell without a marker: on
  release over a chamber cell without a marker `mark` there, else nothing; a press held 0.5 s (by `tick(at:)` or the
  lift timestamp) without moving 10 points arms a claim, lifting sends `claim` of the held cell (a marker's cell for a
  marker) while playing, moving 10 points after arming cancels; drags and holds from empty space send nothing; 10 … 16
  points: nothing; the cursor follows each placed, moved or claimed cell (`moveCursor` after the kernel action); a
  second finger cancels and orbits (yaw 90° per width, pitch 60° per height, clamped; a third re-bases); on a won,
  failed or result stage only `moveCursor` and `resetView` are produced; cancelled phases send nothing; only event
  timestamps read) with `Packages/ExperiencesRound02/EchoCartographer/CoreTests/EchoCartographerGestureControllerTests.swift`
  (500 seeded scripted taps, drags and held presses against an independent expectation over certified levels, 3 sizes
  and 3 orbits; second fingers, cancels and finished plays send no kernel action; orbit changes no digest); agent C;
  `--name host-3`

## Phase 4: Story 5 — every move without gestures (P1)

- [ ] T-R02G1104-004 [P] [US5] Create
  `Packages/ExperiencesRound02/EchoCartographer/CoreTests/EchoCartographerPanelWinTests.swift`: all 100 certified
  levels won through panel actions only (the cursor's column and row steppers, then Pulse or Claim at the cursor, as
  the witnesses play them), split so each test is under 10 s, plus panel Undo then Redo restoring the digests; agent D;
  `--name host-4`

## Phase 5: Story 4 and wiring — orbit, reset, presenter

- [ ] T-R02G1104-005 [US4] Wire `Packages/ExperiencesRound02/EchoCartographer/Experience/EchoCartographerPresenter.swift`
  (`pointer(_:viewSize:port:)` routing through the gesture controller with the drawn snapshot and play; pulse, claim and
  mark sent through the port; moveCursor changing the mirror's cursor; `resetView()`; a kernel action on a finished
  play described as "The play is over: undo or go to the next level"; a refused action shown in the mirror message and
  logged with its code; `tick` from the frame clock),
  `Packages/ExperiencesRound02/EchoCartographer/Experience/EchoCartographerChamberScene.swift` (the orbit's camera) and
  `Packages/ExperiencesRound02/EchoCartographer/Experience/EchoCartographerControls.swift` ("Reset view"); add the
  picker and gesture controller to the kernel invariant scan's presentation sources; agent E writes
  `Packages/ExperiencesRound02/EchoCartographer/ExperienceTests/EchoCartographerGestureWiringTests.swift` (touches
  through the pointer entry pulse, place and move markers and claim as expected; orbit and reset change no digest; a
  refused action is shown; a tap on a won play sends nothing and says the play is over); `--name sim-27 -- python3
  scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package --destination
  sim-27.2 --action test --only-testing EchoCartographerExperienceTests`

## Phase 6: Regression, documentation and close

- [ ] T-R02G1104-006 Docs: `docs/architecture/echo-cartographer.md` (gestures), `Packages/ExperiencesRound02/README.md`,
  `docs/automatedtesting.md`; `--name round02-host`
- [ ] T-R02G1104-007 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`,
  `--name host-full`, `--name app-unit`
- [ ] T-R02G1104-008 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G1104-009 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G1104-010 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G1104-011 {device} After ImplementationLock-100: touch feel and latency on D1/D2/D3 (SC-R02G1104-007)
- [ ] T-R02G1104-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record

## Dependencies and parallel work

001 → {002 (agent B), 004 (agent D)} → 003 (agent C, on B's picker contract) → 005 (lead; agent E writes the wiring
tests) → 006 … 010, 012. 011 stays open until device testing. Shared files (geometry is B's only; presenter, scene,
controls, invariant scan, docs) stay with the lead. MVP: Stories 1 to 3 and 5.
