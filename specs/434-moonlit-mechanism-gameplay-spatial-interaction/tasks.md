# Tasks: R02-G14-04 — Moonlit Mechanism: gameplay spatial interaction

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G14-04 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G14-04 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_434;
tests stay short (< 10 s each). No {owner} tasks. Lessons of features 414 and 424 taken into the first pass: refusal
codes may carry the engine's `action.rule.` prefix; the wiring-test agent gets the presenter's exact texts; the
offscreen host resizes before every still (R02-G14-03), so orbit changes the camera, never the meshes.

## Phase 1: Setup

- [X] T-R02G1404-001 Baselines on the committed tree after R02-G14-03 is recorded: `--name baseline-host`, `--name — Verified 2026-11-24: 2026-11-24: baseline-host, baseline-timing, baseline-round02 exit 0 on 599fb29eb (.autonomy/migration/checks/R02-G14-04.baseline-*.json); rendering baseline = R02-G14-03 rendering-27/26
  baseline-timing`, `--name baseline-round02 -- swift test --package-path Packages/ExperiencesRound02`; the rendering
  baseline is R02-G14-03's rendering runs (exit 0)

## Phase 2: Foundational — orbit, camera and picking

- [X] T-R02G1404-002 [P] Add `MoonlitMechanismOrbit` ("yaw ±25°, pitch −10° … +15°, authored (0, 0)", `clamped()`) and — Verified 2026-11-24: 2026-11-24: agent B orbit (yaw ±25°, pitch −10…+15°), camera(_:aspect:orbit:) refit with authored bit-identical, MoonlitMechanismPicker (lamp, ladder, cards, front-most gear); 500 seeded points × 3 levels × 3 sizes × 3 orbits vs an independent pick, 0 mismatches; lead retest host-2 exit 0 (.autonomy/migration/checks/R02-G14-04.host-2.json)
  `camera(_:aspect:orbit:)` (yaw about the y axis through the box centre, pitch about the authored view; field of view
  refit so the authored box x −0.95 … 0.95, y −0.45 … 1.5, z −0.6 … 0.4 stays inside the view with a 5 % margin at aspects
  0.4 … 2.5; `camera(_:aspect:)` equals the authored orbit, bit-identical) to
  `Packages/ExperiencesRound02/MoonlitMechanism/Core/MoonlitMechanismSceneGeometry.swift`; create
  `Packages/ExperiencesRound02/MoonlitMechanism/Core/MoonlitMechanismPicker.swift` (`MoonlitMechanismPick` lamp, ladder,
  card(index), gear(index), empty (FR-R02G1404-005; SC-R02G1404-001, 004); `viewPoint` projects a world point through
  the drawn camera into view points with the origin top-left, nil behind the eye; `segmentDistance`; `gearCentre`;
  `angle(of:about:)` clockwise on screen; in this order the lamp (centre within 22 points) or the ladder (within 22
  points of the segment from its bottom rung to its top rung), a key-frame card (inside its projected rectangle or its
  centre within 22 points; nearest centre, ties to the lower index), a gear (inside its projected outline circle of
  radius 3.75 s grown by 8 points; the front-most — higher depth, then higher index), else empty; the wall, the pips and
  the moves bars are empty; empty for unusable input) with
  `Packages/ExperiencesRound02/MoonlitMechanism/CoreTests/MoonlitMechanismPickerTests.swift` (an independent pick written
  in the test on 500 seeded points over certified levels, 3 sizes and 3 orbits; the 22-point target at 21 and 23
  points; lamp beats cards beat gears; front-most gear; ties; unusable input) and orbit framing in
  `Packages/ExperiencesRound02/MoonlitMechanism/CoreTests/MoonlitMechanismSceneGeometryTests.swift`; agent B; `--name
  host-2`

## Phase 3: Stories 1 to 4 — gear drags, lamp, taps, run (P1) 🎯

- [X] T-R02G1404-003 [US1] [US2] [US3] [US4] Create — Verified 2026-11-24: 2026-11-24: agent C gesture controller (rotary gear drags with unwrap, dead zone and cap, lamp drags 24 pt per rung, taps, double taps with the driver flag, card and lamp taps, orbit); 500 seeded scripts against an independent expectation and 6 targeted tests; lead retest host-3 exit 0 (.autonomy/migration/checks/R02-G14-04.host-3.json)
  `Packages/ExperiencesRound02/MoonlitMechanism/Core/MoonlitMechanismGestureController.swift` (FR-R02G1404-001 … 004,
  006; SC-R02G1404-001 … 003; `MoonlitMechanismGestureAction` chooseGear(g), pendingTurn(gear, teeth), turn(step, count),
  pendingLamp(steps), lampStep(step, count), reseat(gear), showFrame(k), run, resetView; states idle, gearPress,
  gearDrag, lampPress, lampDrag, cardPress, emptyPress, orbiting, cancelled; a tap (< 10 points, lifted before 0.5 s) on a
  gear: `chooseGear` in any stage, and a second tap on the same gear within 0.35 s and 22 points while playing:
  `reseat(g)` except on gear 0 (nothing); on a card: `showFrame(k)` in any stage; on the lamp while playing: `run`; on
  the ladder: nothing; on empty space: nothing, two such taps within 0.35 s and 22 points: `resetView`; a press lifted at
  0.5 s or later without moving: nothing; a drag (≥ 16 points) from a gear while playing accumulates the clockwise swept
  angle about the gear's projected centre (samples within 12 points of the centre skipped), sends `pendingTurn` on each
  move with n = round(swept ÷ (2π ÷ T)) capped at the actions left in magnitude, and on release `turn(step:
  direction(gear) × sign(n), count: |n|)` when n ≠ 0; a vertical drag from the lamp or ladder while playing counts
  round(−Δy ÷ 24 points) rungs, sends `pendingLamp`, and on release `lampStep(step: sign, count: |rungs|)` when non-zero;
  a drag on another stage, or from a card or empty space: nothing; 10 … 16 points: nothing; a second finger cancels
  (clearing any pending text with `pendingTurn`/`pendingLamp` of 0) and orbits (yaw 90° per width, pitch 60° per
  height, clamped; a third re-bases); cancelled phases send nothing; only event timestamps read) with
  `Packages/ExperiencesRound02/MoonlitMechanism/CoreTests/MoonlitMechanismGestureControllerTests.swift` (500 seeded
  scripted taps and drags against an independent expectation over certified levels at playing, won and failed plays,
  3 sizes and 3 orbits, every kernel action applied through the adapter; second fingers, cancels and finished plays send
  no kernel action; orbit changes no digest; the driver's double tap sends nothing; the cap at the actions left); agent
  C; `--name host-3`

## Phase 4: Story 6 — every move without gestures (P1)

- [X] T-R02G1404-004 [P] [US6] Create — Verified 2026-11-24: 2026-11-24: agent D, all 100 certified levels won through panel actions only in ten groups (witness action counts), panel undo/redo restore digests; lead retest host-4 exit 0 (.autonomy/migration/checks/R02-G14-04.host-4.json)
  `Packages/ExperiencesRound02/MoonlitMechanism/CoreTests/MoonlitMechanismPanelWinTests.swift`: all 100 certified levels
  won through panel actions only (FR-R02G1404-007; SC-R02G1404-005; turn − and +, the gear stepper and re-seat − and +,
  lamp − and +, and run, as the witnesses play them), split so each test is under 10 s, plus panel Undo then Redo
  restoring the digests; agent D; `--name host-4`

## Phase 5: Story 5 and wiring — orbit, reset, presenter

- [X] T-R02G1404-005 [US5] Wire `Packages/ExperiencesRound02/MoonlitMechanism/Experience/MoonlitMechanismPresenter.swift` — Verified 2026-11-24: 2026-11-24: presenter pointer entry (turns and lamp steps sent one per step, pending texts, driver message via refusedDriverReseat, finished message, refusal codes read with or without action.rule., refusalLog), scene orbit camera, panel Reset view and pending line; agent E 10 wiring tests; 33 simulator tests; sim-27-2 exit 0 (.autonomy/migration/checks/R02-G14-04.sim-27-2.json; sim-27 ran on E's draft before its final edit)
  (FR-R02G1404-001 … 004, 006 … 008; `pointer(_:viewSize:port:)` routing through the gesture controller with the drawn
  snapshot; turn × count, lamp step × count, re-seat, run and frame.show sent through the port; chooseGear changing the
  mirror's gear; the pending turn and lamp steps in the description and the panel ("Turn n teeth (n actions)", "Lamp n
  steps"); the
  driver's double tap described as "The driver cannot be re-seated"; on a won or failed play `describe` says "The play
  is over: undo or go to the next level"; a refused action shown in the mirror message and logged with its code,
  reading codes with or without the engine's `action.rule.` prefix; `resetView()`),
  `Packages/ExperiencesRound02/MoonlitMechanism/Experience/MoonlitMechanismClockworkScene.swift` (the orbit's camera) and
  `Packages/ExperiencesRound02/MoonlitMechanism/Experience/MoonlitMechanismControls.swift` ("Reset view"); agent E writes
  `Packages/ExperiencesRound02/MoonlitMechanism/ExperienceTests/MoonlitMechanismGestureWiringTests.swift` (touches
  through the pointer entry turn the train by a gear drag, step the lamp by a drag, choose and re-seat a gear, show a key
  frame, run by a lamp tap; orbit and reset change no digest; a refused action is shown; a drag on a won play sends
  nothing and says the play is over), given the presenter's exact status and description texts; `--name sim-27 --
  python3 scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package
  --destination sim-27.2 --action test --only-testing MoonlitMechanismExperienceTests`

## Phase 6: Regression, documentation and close

- [X] T-R02G1404-006 Docs: `docs/architecture/moonlit-mechanism.md` (gestures), `Packages/ExperiencesRound02/README.md`, — Verified 2026-11-24: 2026-11-24: architecture gestures section, ExperiencesRound02 README, testing doc (two lessons); round02-host exit 0 in 365 s (.autonomy/migration/checks/R02-G14-04.round02-host.json)
  `docs/automatedtesting.md`; `--name round02-host`
- [X] T-R02G1404-007 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`, — Verified 2026-11-24: 2026-11-24: rendering-27, rendering-26, experiences, host-full, app-unit exit 0 (.autonomy/migration/checks/R02-G14-04.{rendering-27,rendering-26,experiences,host-full,app-unit}.json)
  `--name host-full`, `--name app-unit`
- [X] T-R02G1404-008 Reference regression chunk 1 (`--name reference-1`) — Verified 2026-11-24: 2026-11-24: reference-1 exit 0 (.autonomy/migration/checks/R02-G14-04.reference-1.json)
- [X] T-R02G1404-009 Reference regression chunk 2 (`--name reference-2`) — Verified 2026-11-24: 2026-11-24: reference-2 exit 0 (.autonomy/migration/checks/R02-G14-04.reference-2.json)
- [ ] T-R02G1404-010 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G1404-011 {device} After ImplementationLock-100: touch feel and latency on D1/D2/D3 (SC-R02G1404-007)
- [ ] T-R02G1404-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record;
  README row and gate list updated

## Dependencies and parallel work

001 → {002 (agent B), 004 (agent D)} → 003 (agent C, on B's picker contract in contracts/api.md) → 005 (lead; agent E
writes the wiring tests) → 006 … 010, 012. 011 stays open until device testing. Agents B and D may start in isolated
copies before 001 (their files are new or B-only). Shared files (presenter, scene, controls, docs) stay with the lead.
MVP: Stories 1, 2, 4 and 6. Requirement coverage: FR-001 → 003, 005; FR-002, 003, 004 → 003, 005; FR-005 → 002; FR-006
→ 002, 003, 005; FR-007 → 004, 005; FR-008 → 003, 005 … 010.
