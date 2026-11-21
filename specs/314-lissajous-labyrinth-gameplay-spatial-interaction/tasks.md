# Tasks: R02-G02-04 — Lissajous Labyrinth: gameplay spatial interaction

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G02-04 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G02-04 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_314;
tests stay short (< 10 s each).

## Phase 1: Setup

- [X] T-R02G0204-001 Baselines: `--name baseline-host`, `--name baseline-timing`, `--name baseline-round02 -- swift test — Verified 2026-11-21: 2026-11-21 baseline-host, baseline-timing, baseline-round02 exit 0; rendering baseline R02-G02-03 rendering-27/26 exit 0
  --package-path Packages/ExperiencesRound02`; the rendering baseline is R02-G02-03's rendering runs (exit 0)

## Phase 2: Foundational

- [X] T-R02G0204-002 [P] Edit `Packages/ExperiencesRound02/LissajousLabyrinth/Core/LissajousLabyrinthSceneGeometry.swift` — Verified 2026-11-21: 2026-11-21 host exit 0: LissajousLabyrinthHandlesTests 5/5 (layout, every value round-trips through its knob, rounding/clamping/wrapping, four handles, picker picks every projected knob at 3 sizes × 3 orbits) and LissajousLabyrinthSceneGeometryTests 11/11 (stage holds every path of all 100 levels at start and solution dials; stage and rings inside 90 % NDC for 9 orbits × 7 aspects × 4 levels; orbit clamping; authored camera = authored orbit)
  (`stageBounds(level:)` "the amplitude box ±amplitude per axis grown by pathMargin, and every checkpoint and obstacle
  ball; independent of the dials"; `contentBounds(level:)` stage plus rings; `LissajousLabyrinthOrbit` "azimuth offset
  −40° … 40° around atan2(0.55, 1.0), elevation 10° … 60°, authored ≈ 21.5°"; `camera(aspect:snapshot:orbit:)` fitting
  `contentBounds` with `distance(radius:aspect:)`; `viewProjection`, `depthRange`, `project` gain `orbit: = .authored`)
  and create `Packages/ExperiencesRound02/LissajousLabyrinth/Core/LissajousLabyrinthHandles.swift` (rings "radius 0.18 R,
  centres 0.45 R apart, offset 1.35 R along the authored right vector, order frequencyA, frequencyB, phaseA, phaseC from
  top, facing the authored eye"; knob "value · 40° (frequencies 1 … 9) or value · 22.5° (phases 0 … 15)"; value(dial,
  start, turnedAngle) "start + round(angle / step), clamped 1 … 9 or modulo 16"; four SpatialHandles, id = dial index)
  with `Packages/ExperiencesRound02/LissajousLabyrinth/CoreTests/LissajousLabyrinthHandlesTests.swift` and
  `Packages/ExperiencesRound02/LissajousLabyrinth/CoreTests/LissajousLabyrinthSceneGeometryTests.swift` updates (every
  value round-trips through its knob; the stage holds every path of all 100 levels at start and solution dials; stage and
  rings inside 5 % for orbit limits × aspects 0.4, 0.5, 0.75, 1, 1.5, 2, 2.5); `--name host -- swift test --package-path
  Packages/ExperiencesRound02 --filter 'LissajousLabyrinthHandlesTests|LissajousLabyrinthSceneGeometryTests'`
- [X] T-R02G0204-003 [P] Create `Packages/ExperiencesRound02/LissajousLabyrinth/Core/LissajousLabyrinthPending.swift` — Verified 2026-11-21: 2026-11-21 host-pending exit 0: LissajousLabyrinthPendingTests 13/13 (all 100 certified levels won through pending values in exactly their certified shortest number of actions; frequency-B-first swap; no coprime order refused first; stepping wraps; set clamps/wraps; clear)
  (values "only dials that differ from the current value"; set, step "wraps in range", clear; actions(from:) "one per
  changed dial in the order frequencyA, frequencyB, phaseA, phaseC; frequencyB first when only that keeps every
  intermediate pair coprime; when neither order does, the refused order is returned so Apply stops with the reason")
  with `Packages/ExperiencesRound02/LissajousLabyrinth/CoreTests/LissajousLabyrinthPendingTests.swift` (all 100
  certified levels won by applying the solution's final dials in exactly the certified shortest number of actions;
  swap case; no-coprime-order case; stepping wraps; setting the current value removes it); `--name host-pending`

## Phase 3: Stories 1, 2 and 4 — dial rings, camera, selection (P1/P2) 🎯

- [X] T-R02G0204-004 [P] [US1] [US2] [US4] Create — Verified 2026-11-21: 2026-11-21 host-2 exit 0: LissajousLabyrinthGestureControllerTests 15/15 (500 seeded turns end in the independently computed value at 390×844, 96×64, 1024×768; full and 1.5 turns; frequency clamps; preview; 1,000 seeded arbitration scripts send nothing; nearest-knob picking with lower-id ties; ring-band picking 0.7 … 1.3 with knob priority; orbit limits and double-tap reset; selection; determinism)
  `Packages/ExperiencesRound02/LissajousLabyrinth/Core/LissajousLabyrinthGestureController.swift` (states idle, turning,
  orbiting, cancelled; picking via HandlePicker; turns via HandleDrag on the ring plane with accumulated angle; one
  `LissajousLabyrinthAction` on release when changed; second finger cancels; cancelled touches; playing-only; orbit from
  the two-finger midpoint "90° per width, 60° per height", clamped; double tap on empty space resets; selection) with
  `Packages/ExperiencesRound02/LissajousLabyrinth/CoreTests/LissajousLabyrinthGestureControllerTests.swift` (500 seeded
  scripted turns agree with an independent computation of the end value at 390×844, 96×64 and 1024×768; 1,000 seeded
  arbitration scripts; two handles under one touch pick the nearest, ties by the lower id; orbit limits; selection;
  determinism); `--name host-2`

## Phase 4: Story 3 — panel play, wiring (P1)

- [X] T-R02G0204-005 [US1] [US2] [US3] [US4] Wire the experience: — Verified 2026-11-21: 2026-11-21 round02-build exit 0 (presenter routes touches through the gesture controller and sends dial.set; pending values with Apply/Clear, outside changes drop them, announcements; scene draws four cobalt dial rings, copper knobs, the selected dial's copper outline and the violet turn preview with the orbited camera; controls: pending steppers, Apply, Clear, Reset view); behaviour proven by T-R02G0204-006
  `Packages/ExperiencesRound02/LissajousLabyrinth/Experience/LissajousLabyrinthPresenter.swift` (pointer events →
  controller → `dial.set` through the port; refusal text; orbit into the camera; selection, candidate and pending values
  in the description and mirror; pending dropped on any committed change, undo, redo, next level, restore),
  `Packages/ExperiencesRound02/LissajousLabyrinth/Experience/LissajousLabyrinthThreadScene.swift` (rings, knobs, the
  selected dial's copper outline and brighter knob, the turn preview; camera with the orbit),
  `Packages/ExperiencesRound02/LissajousLabyrinth/Experience/LissajousLabyrinthControls.swift` (steppers set pending
  values and select their dial; Apply and Clear with labels, shown only while pending; "Reset view"; announcements
  "<Dial name> <value> pending. Apply to change."); `--name round02-build -- python3 scripts/xcodebuild_package.py
  --package Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package --destination sim-27.2 --action build`

## Phase 5: Simulator proof (P2)

- [X] T-R02G0204-006 [US1] [US2] [US3] [US4] Create — Verified 2026-11-21: 2026-11-21 sim-27 exit 0 on sim-27.2: LissajousLabyrinthGestureWiringTests 15/15 (turns through the shell's pointer entry set the named value; second finger, cancel, empty space, paused, won and failed play send nothing; a refused turn shows and announces its text; selection described and outlined; undo/redo after a gesture; orbit limits keep the frame and Reset view returns; pending Apply wins all 100 levels in their certified shortest; Clear, outside changes and a partway win). The run found two defects, fixed: the presenter did not drop a touch on suspend (cancelPointers added) and the selection outline lay outside the framed content (now inside the ring, 0.6 R). The new framing shrinks the figure, so the 313 frame checks run at 12 × (spec FR-R02G0204-008 amended); all Lissajous experience tests pass
  `Packages/ExperiencesRound02/LissajousLabyrinth/ExperienceTests/LissajousLabyrinthGestureWiringTests.swift` (scripted
  touches through the presenter's pointer entry change a dial by exactly the named value; a second finger and a cancel
  send nothing; paused or ended play sends nothing; a refused action shows its text with the state unchanged; the
  selection outline is drawn; the description names the selection; undo after a gesture restores the digest; frame checks
  hold at the orbit limits; Reset view returns the authored pose; pending Apply through the presenter wins all 100 levels
  in their certified shortest; Clear and an outside change drop pending values; Apply that wins partway stops and announces the win); `--name sim-27 -- python3
  scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package --destination
  sim-27.2 --action test`

## Phase 6: Regression, documentation and close

- [X] T-R02G0204-007 Docs: `docs/architecture/lissajous-labyrinth.md` (controls, stage, pending play), — Verified 2026-11-21: 2026-11-21 round02-host exit 0; audits exit 0 (content audit of r02-g02.lissajous-labyrinth); docs/architecture/lissajous-labyrinth.md touch controls and panel play; package README; docs/automatedtesting.md (sub-pixel checks scaled with the framing)
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host -- swift test --package-path
  Packages/ExperiencesRound02`; `--name audits -- python3 scripts/verify_experiences.py --audits --only
  r02-g02.lissajous-labyrinth`
- [X] T-R02G0204-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`, — Verified 2026-11-21: 2026-11-21 rendering-27, rendering-26, experiences, host-full and app-unit exit 0
  `--name host-full`, `--name app-unit -- python3 scripts/release_check.py --only app-build-for-testing-ios27
  app-unit-ios27`
- [X] T-R02G0204-009 Reference regression chunk 1 (`--name reference-1`) — Verified 2026-11-21: 2026-11-21 reference-1 exit 0
- [X] T-R02G0204-010 Reference regression chunk 2 (`--name reference-2`) — Verified 2026-11-21: 2026-11-21 reference-2 exit 0: 7 of 7 with chunk 1
- [ ] T-R02G0204-011 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G0204-012 {device} After ImplementationLock-100, on D1, D2 and D3: record gesture feel and touch-to-frame
  latency (SC-R02G0204-007). Not run before the lock; stays open and is carried to the device campaign.
- [ ] T-R02G0204-013 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record

## Dependencies and parallel work

001 → {002 (agent B), 003 (agent D), 004 (agent C, against the contract; uses 002's handles once they land)} → 005
(lead) → 006 (agent E writes, lead runs) → 007 … 011, 013. 012 is a {device} task outside this campaign. MVP: Stories 1
and 3.
