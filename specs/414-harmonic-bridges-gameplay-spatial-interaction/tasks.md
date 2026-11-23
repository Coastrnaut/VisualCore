# Tasks: R02-G12-04 — Harmonic Bridges: gameplay spatial interaction

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G12-04 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G12-04 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_414;
tests stay short (< 10 s each). No {owner} tasks.

## Phase 1: Setup

- [X] T-R02G1204-001 Baselines on the committed tree: `--name baseline-host`, `--name baseline-timing`, `--name — Verified 2026-11-23: Verified 2026-11-23: baseline-host, baseline-timing, baseline-round02 exit 0; rendering baseline is R02-G12-03's rendering runs (exit 0)
  baseline-round02 -- swift test --package-path Packages/ExperiencesRound02`; the rendering baseline is R02-G12-03's
  rendering runs (exit 0)

## Phase 2: Foundational — orbit, camera and picking

- [X] T-R02G1204-002 [P] Add `HarmonicBridgesOrbit` ("yaw ±35°, pitch −15° … +20°, authored (0, 0)", `clamped()`) and — Verified 2026-11-23: Verified 2026-11-23: host-2 exit 0 (HarmonicBridgesPickerTests 7: 500 seeded points × 3 sizes × 3 orbits over levels 1/50/100 against an independent projection and pick; the 22-point target at 21/23 points for pips, the goal and strings; pips beat the goal beats strings; ties to the lower index (equidistant overlapping strings of level 100); unusable input; HarmonicBridgesSceneGeometryTests 16 incl. 4 orbit tests: every island top, string end, gauge bar and pip inside 0.05…0.95 at the clamp corners and 7 aspects, tight fit, clamping, the authored orbit bit-identical to the fixed camera); agent B retested by the lead
  `camera(_:aspect:orbit:)` (yaw about the y axis through the box centre, pitch about the authored view; field of view
  refit so the authored box x −1 … 1, z −0.7 … 1.0, y 0 … 0.2 stays inside the view with a 5 % margin at aspects
  0.4 … 2.5; `camera(_:aspect:)` equals the authored orbit, bit-identical) to
  `Packages/ExperiencesRound02/HarmonicBridges/Core/HarmonicBridgesSceneGeometry.swift`; create
  `Packages/ExperiencesRound02/HarmonicBridges/Core/HarmonicBridgesPicker.swift` (`HarmonicBridgesPick` pip(step), goal,
  string(index), empty (FR-R02G1204-004, 005; SC-R02G1204-001, 004); `viewPoint` projects a world point through the drawn camera into view points with the origin
  top-left, nil behind the eye; `segmentDistance`; in this order a step pip whose centre lies within 22 points (nearest,
  ties to the lower step), the goal island's top centre within 22 points, a string whose projected segment between its
  islands' top centres lies within 22 points (nearest, ties to the lower string index), else empty; empty for unusable
  input) with `Packages/ExperiencesRound02/HarmonicBridges/CoreTests/HarmonicBridgesPickerTests.swift` (an independent
  pick written in the test on 500 seeded points over certified levels, 3 sizes and 3 orbits; the 22-point target at 21
  and 23 points; pips beat the goal beats strings; unusable input) and orbit framing in
  `Packages/ExperiencesRound02/HarmonicBridges/CoreTests/HarmonicBridgesSceneGeometryTests.swift`; agent B; `--name
  host-2`

## Phase 3: Stories 1 to 3 — pluck, drag the peg, tap freeze (P1) 🎯

- [X] T-R02G1204-003 [US1] [US2] [US3] Create — Verified 2026-11-23: Verified 2026-11-23: host-3 exit 0 (HarmonicBridgesGestureControllerTests 7: 500 seeded scripts in 12 kinds on levels 1/50/100 (opening, tuned, paused, won, failed) and a locked-string level, 3 views and 3 orbits, against an independent expectation, every tune and test applied through the adapter and accepted; finished plays, second fingers and cancels send no kernel action and leave the digest; preview rounding and clamping; tap and drag thresholds; orbit re-base and clamps; double tap); agent C retested by the lead
  `Packages/ExperiencesRound02/HarmonicBridges/Core/HarmonicBridgesGestureController.swift`
  (FR-R02G1204-001 … 003, 005; SC-R02G1204-001 … 003; `HarmonicBridgesGestureAction` choose(string, peg), preview(string, peg), tune(string, peg), test, resetView; states
  idle, stringPress, pegDrag, targetPress, orbiting, cancelled; a tap (< 10 points, lifted before 0.5 s) on a string:
  `choose` at its current peg in any stage; on a pip or the goal while playing: `test`; on empty space: nothing, two such
  taps within 0.35 s and 22 points: `resetView`; a press lifted at 0.5 s or later without moving: nothing; a drag
  (≥ 16 points) from an unlocked string while playing: `preview` with the previewed peg = current + round(upward / 24)
  half away from zero, clamped 1 … 12, on each move that changes it, and on release `tune` when the peg differs from the
  current one, else nothing; a drag from a locked string or on a stage other than playing: `choose` at the current peg,
  no preview, nothing on release; drags from a pip, the goal or empty space: nothing; 10 … 16 points: nothing; a second
  finger cancels and orbits (yaw 90° per width, pitch 60° per height, clamped; a third re-bases); cancelled phases send
  nothing; only event timestamps read) with
  `Packages/ExperiencesRound02/HarmonicBridges/CoreTests/HarmonicBridgesGestureControllerTests.swift` (500 seeded
  scripted taps and drags against an independent expectation over certified levels at playing, won and failed plays, 3
  sizes and 3 orbits, every kernel action applied through the adapter; second fingers, cancels and finished plays send
  no kernel action; orbit changes no digest; the preview's rounding and clamp at the bounds); agent C; `--name host-3`

## Phase 4: Story 5 — every move without gestures (P1)

- [X] T-R02G1204-004 [P] [US5] Create — Verified 2026-11-23: Verified 2026-11-23: host-4 exit 0 (HarmonicBridgesPanelWinTests: all 100 certified levels won through the string and peg steppers, Tune and Test alone in 10 groups, each in exactly its witness's action count; panel Undo then Redo restore the digests); agent D retested by the lead
  `Packages/ExperiencesRound02/HarmonicBridges/CoreTests/HarmonicBridgesPanelWinTests.swift`: all 100 certified levels
  won through panel actions only (FR-R02G1204-006; SC-R02G1204-005; the string and peg steppers, then Tune, and Test, as the witnesses play them), split
  so each test is under 10 s, plus panel Undo then Redo restoring the digests; agent D; `--name host-4`

## Phase 5: Story 4 and wiring — orbit, reset, presenter

- [X] T-R02G1204-005 [US4] Wire `Packages/ExperiencesRound02/HarmonicBridges/Experience/HarmonicBridgesPresenter.swift` — Verified 2026-11-23: Verified 2026-11-23: sim-27 exit 0 (37 Harmonic Bridges simulator tests incl. HarmonicBridgesGestureWiringTests 8: a tap on a string chooses it and describes its resonance, a drag up by 48 points tunes it by two pegs, a drag back sends nothing and restores the panel peg, a tap on the goal tests, orbit and reset change no digest, a refused tune is shown in words and logged with its code, a drag on a won play sends nothing and says the play is over, gesture actions are native actions); the first run found refusals shown as 'not available' because the engine prefixes kernel codes with action.rule. — refusalText now reads both forms; agent E's tests retested by the lead
  (FR-R02G1204-001 … 003, 005 … 007; `pointer(_:viewSize:port:)` routing through the gesture controller with the drawn snapshot; tune and test sent
  through the port; choose and preview changing the mirror's string and peg; the chosen string's resonance described
  (its modes in the shown step and how many of its five samples reach the threshold); a locked string's drag described
  as locked; on a won or failed play `describe` says "The play is over: undo or go to the next level" (the lesson of
  feature 404's convergence, in the first pass); a refused action shown in the mirror message and logged with its code;
  `resetView()`), `Packages/ExperiencesRound02/HarmonicBridges/Experience/HarmonicBridgesBridgeScene.swift` (the orbit's
  camera) and `Packages/ExperiencesRound02/HarmonicBridges/Experience/HarmonicBridgesControls.swift` ("Reset view");
  agent E writes `Packages/ExperiencesRound02/HarmonicBridges/ExperienceTests/HarmonicBridgesGestureWiringTests.swift`
  (touches through the pointer entry choose a string, tune it by a drag, test by a tap on the goal or a pip; orbit and
  reset change no digest; a refused action is shown; a drag on a won play sends nothing and says the play is over);
  `--name sim-27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme
  ExperiencesRound02-Package --destination sim-27.2 --action test --only-testing HarmonicBridgesExperienceTests`

## Phase 6: Regression, documentation and close

- [ ] T-R02G1204-006 Docs: `docs/architecture/harmonic-bridges.md` (gestures), `Packages/ExperiencesRound02/README.md`,
  `docs/automatedtesting.md`; `--name round02-host`
- [ ] T-R02G1204-007 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`,
  `--name host-full`, `--name app-unit`
- [ ] T-R02G1204-008 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G1204-009 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G1204-010 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G1204-011 {device} After ImplementationLock-100: touch feel and latency on D1/D2/D3 (SC-R02G1204-007)
- [ ] T-R02G1204-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record

## Dependencies and parallel work

001 → {002 (agent B), 004 (agent D)} → 003 (agent C, on B's picker contract in contracts/api.md) → 005 (lead; agent E
writes the wiring tests) → 006 … 010, 012. 011 stays open until device testing. Shared files (geometry is B's only;
presenter, scene, controls, docs) stay with the lead. MVP: Stories 1 to 3 and 5.
