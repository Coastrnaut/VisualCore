# Tasks: R02-G13-04 — Acoustic Constellator: gameplay spatial interaction

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G13-04 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G13-04 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_424;
tests stay short (< 10 s each). No {owner} tasks. Lessons of feature 414 taken into the first pass: the painter's order
of the stars follows the drawn camera's eye at every orbit, and refusal codes may carry the engine's `action.rule.`
prefix.

## Phase 1: Setup

- [X] T-R02G1304-001 Baselines on the committed tree: `--name baseline-host`, `--name baseline-timing`, `--name — Verified 2026-11-23: 2026-11-23: baseline-host, baseline-timing, baseline-round02 exit 0 on 8a35986f3 (.autonomy/migration/checks/R02-G13-04.baseline-*.json); rendering baseline = R02-G13-03 rendering-27/26
  baseline-round02 -- swift test --package-path Packages/ExperiencesRound02`; the rendering baseline is R02-G13-03's
  rendering runs (exit 0)

## Phase 2: Foundational — orbit, camera, picking and the drag filament

- [ ] T-R02G1304-002 [P] Add `AcousticConstellatorOrbit` ("yaw ±35°, pitch −15° … +20°, authored (0, 0)", `clamped()`)
  and `camera(_:aspect:orbit:)` (yaw about the y axis through the box centre, pitch about the authored view; field of
  view refit so the authored box x −0.9 … 0.9, z −0.7 … 1.25, y 0 … 0.3 stays inside the view with a 5 % margin at aspects
  0.4 … 2.5; `camera(_:aspect:)` equals the authored orbit, bit-identical), star painter's order by distance from the
  drawn camera's eye (far first; the authored eye keeps today's order) and `filamentMesh(from:to:_:)` (the drag preview,
  a strip 0.01 wide in constellation material `tealLink` from the star's centre to a world point) to
  `Packages/ExperiencesRound02/AcousticConstellator/Core/AcousticConstellatorSceneGeometry.swift`; create
  `Packages/ExperiencesRound02/AcousticConstellator/Core/AcousticConstellatorPicker.swift` (`AcousticConstellatorPick`
  coherence(bar), hold(pip), star(index), link(index), empty (FR-R02G1304-004, 005; SC-R02G1304-001, 004); `viewPoint`
  projects a world point through the drawn camera into view points with the origin top-left, nil behind the eye;
  `segmentDistance`; in this order a coherence bar or hold pip whose centre lies within 22 points (nearest, ties to the
  coherence bars and then the lower index), a star centre within 22 points (nearest, ties to the lower index), a link
  whose projected spline (16 segments) lies within 22 points (nearest, ties to the lower link index), else empty; the
  moves gauge and guides are empty; `starAt(_:size:snapshot:orbit:excluding:)` for drag targets; `fingerPoint(_:size:camera:height:)`, the world point under
  the finger on the plane y = height (the dragged star's height), nil when the ray misses it — the filament ends there,
  or at the target star's centre when there is one; empty for unusable
  input) with `Packages/ExperiencesRound02/AcousticConstellator/CoreTests/AcousticConstellatorPickerTests.swift` (an
  independent pick written in the test on 500 seeded points over certified levels, 3 sizes and 3 orbits; the 22-point
  target at 21 and 23 points; gauges beat stars beat links; ties; unusable input) and orbit framing, star order under
  orbit and the filament in `Packages/ExperiencesRound02/AcousticConstellator/CoreTests/AcousticConstellatorSceneGeometryTests.swift`;
  agent B; `--name host-2`

## Phase 3: Stories 1 to 4 — link drags, nudge taps, listening, inspection (P1) 🎯

- [ ] T-R02G1304-003 [US1] [US2] [US3] [US4] Create
  `Packages/ExperiencesRound02/AcousticConstellator/Core/AcousticConstellatorGestureController.swift`
  (FR-R02G1304-001 … 004, 006; SC-R02G1304-001 … 003; `AcousticConstellatorGestureAction` choose(star), choosePair(a, b),
  preview(from, target, point), link(a, b), unlink(a, b), nudge(star), listen, resetView; states idle, starPress,
  linkDrag, targetPress, linkPress, orbiting, cancelled; a tap (< 10 points, lifted before 0.5 s) on a star while
  playing: `nudge` and `choose`; on a finished play or another stage: `choose` only; on a link: `choosePair` in any stage;
  on a gauge target while playing: `listen`; on empty space: nothing, two such taps within 0.35 s and 22 points:
  `resetView`; a press lifted at 0.5 s or later without moving: nothing; a drag (≥ 16 points) from a star while playing:
  `preview` on each move (the target is the other star nearest the finger within 22 points, ties to the lower index, or
  nil), and on release with a target: `link(a, b)` (a < b) when unlinked, `unlink(a, b)` when the player linked it,
  nothing for a fixed link, with `choosePair(start, target)`; without a target: nothing; a drag from a star on another
  stage, or from a link, a gauge or empty space: nothing; 10 … 16 points: nothing; a second finger cancels and orbits (yaw
  90° per width, pitch 60° per height, clamped; a third re-bases); cancelled phases send nothing; only event timestamps
  read) with `Packages/ExperiencesRound02/AcousticConstellator/CoreTests/AcousticConstellatorGestureControllerTests.swift`
  (500 seeded scripted taps and drags against an independent expectation over certified levels at playing, won and
  failed plays, 3 sizes and 3 orbits, every kernel action applied through the adapter; second fingers, cancels and
  finished plays send no kernel action; orbit changes no digest; fixed pairs send nothing); agent C; `--name host-3`

## Phase 4: Story 6 — every move without gestures (P1)

- [X] T-R02G1304-004 [P] [US6] Create — Verified 2026-11-23: 2026-11-23: agent D AcousticConstellatorPanelWinTests (all 100 certified levels won through the star and partner steppers, Link, Nudge and Listen in 10 groups, each in exactly its witness's action count; panel Undo then Redo restore the digests), lead retest host-4 exit 0 (.autonomy/migration/checks/R02-G13-04.host-4.json)
  `Packages/ExperiencesRound02/AcousticConstellator/CoreTests/AcousticConstellatorPanelWinTests.swift`: all 100
  certified levels won through panel actions only (FR-R02G1304-007; SC-R02G1304-005; the star and partner steppers, then
  Link, the star stepper and Nudge, and Listen, as the witnesses play them), split so each test is under 10 s, plus
  panel Undo then Redo restoring the digests; agent D; `--name host-4`

## Phase 5: Story 5 and wiring — orbit, reset, presenter

- [ ] T-R02G1304-005 [US5] Wire `Packages/ExperiencesRound02/AcousticConstellator/Experience/AcousticConstellatorPresenter.swift`
  (FR-R02G1304-001 … 004, 006 … 008; `pointer(_:viewSize:port:)` routing through the gesture controller with the drawn
  snapshot; link, unlink, nudge and listen sent through the port; choose, choosePair and preview changing the mirror's
  star and partner (`choose(star)` moves the partner to the next star, modulo the star count, when it equals the star); a chosen link described (its stars, its gap at the shown tick, fixed or placed); a fixed pair's drag
  described as fixed; on a won or failed play `describe` says "The play is over: undo or go to the next level"; a
  refused action shown in the mirror message and logged with its code, reading codes with or without the engine's
  `action.rule.` prefix; `resetView()`),
  `Packages/ExperiencesRound02/AcousticConstellator/Experience/AcousticConstellatorConstellationScene.swift` (the orbit's
  camera, the star order for the drawn eye, the drag filament) and
  `Packages/ExperiencesRound02/AcousticConstellator/Experience/AcousticConstellatorControls.swift` ("Reset view"); agent
  E writes `Packages/ExperiencesRound02/AcousticConstellator/ExperienceTests/AcousticConstellatorGestureWiringTests.swift`
  (touches through the pointer entry nudge a star by a tap, link and unlink by drags, listen by a tap on the gauge,
  inspect a link; orbit and reset change no digest; a refused action is shown; a drag on a won play sends nothing and
  says the play is over), given the presenter's exact status and description texts; `--name sim-27 -- python3
  scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package --destination
  sim-27.2 --action test --only-testing AcousticConstellatorExperienceTests`

## Phase 6: Regression, documentation and close

- [ ] T-R02G1304-006 Docs: `docs/architecture/acoustic-constellator.md` (gestures),
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host`
- [ ] T-R02G1304-007 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`,
  `--name host-full`, `--name app-unit`
- [ ] T-R02G1304-008 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G1304-009 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G1304-010 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G1304-011 {device} After ImplementationLock-100: touch feel and latency on D1/D2/D3 (SC-R02G1304-007)
- [ ] T-R02G1304-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record;
  README row and gate list updated

## Dependencies and parallel work

001 → {002 (agent B), 004 (agent D)} → 003 (agent C, on B's picker contract in contracts/api.md) → 005 (lead; agent E
writes the wiring tests) → 006 … 010, 012. 011 stays open until device testing. Shared files (geometry is B's only;
presenter, scene, controls, docs) stay with the lead. MVP: Stories 1 to 3 and 6. Requirement coverage: FR-001 → 003,
005; FR-002, 003, 004 → 003, 005; FR-005 → 002; FR-006 → 002, 003, 005; FR-007 → 004, 005; FR-008 → 003, 005 … 010.
