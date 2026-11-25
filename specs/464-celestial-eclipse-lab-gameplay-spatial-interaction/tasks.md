# Tasks: R02-G17-04 — Celestial Eclipse Lab: gameplay spatial interaction

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G17-04 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G17-04 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_464;
tests stay short (< 10 s each). No {owner} tasks. Lessons taken into the first pass: refusal codes may carry the
engine's `action.rule.` prefix; the wiring-test agent gets the presenter's exact texts; meshes are rebuilt when the
orbit (the drawn eye) changes, never on a resize alone; one agent owns the snapshot fields, the ghost geometry and its
shader material (the vertex-contract lesson of R02-G16-03 and R02-G17-03).

## Phase 1: Setup

- [X] T-R02G1704-001 Baselines on the committed tree after R02-G17-03 is recorded: `--name baseline-host`, `--name — Verified 2026-11-25: 2026-11-25 baseline-host, baseline-timing and round02-1, -2, -3c, -3e, -3f exit 0; rendering baseline is R02-G17-03's rendering runs (exit 0)
  baseline-timing`, `--name baseline-round02-1`, `-2`, `-3c`, `-3e`, `-3f`; the rendering baseline is R02-G17-03's
  rendering runs (exit 0)

## Phase 2: Foundational — orbit, camera, phase preview and picking

- [X] T-R02G1704-002 [P] Add `previewBody`, `previewOffset` ("nil when no drag"), `previewIntervals` and — Verified 2026-11-25: 2026-11-25 orbit and camera(_:aspect:orbit:), phase preview in the snapshot, ghost (material 17) and preview timeline, camera-taking meshes, picker (pick, dial box, nearest-tick dial, ring offset); 154 CelestialEclipseLab host tests pass (host-2 exit 0); the dial rule corrected from a linear fraction (missed by one under perspective) to the nearest projected tick, spec, research, tasks and checklist updated
  `previewMatched` ("the kernel's timeline of the current phases with the previewed body at the previewed offset;
  presentation only; never in the digest") and `previewing(body:offset:)` to
  `Packages/ExperiencesRound02/CelestialEclipseLab/Core/CelestialEclipseLabSceneSnapshot.swift`; add
  `CelestialEclipseLabOrbit` ("yaw ±60°, pitch −20° … +35°; authored (0, 0); presentation only", `clamped()`),
  `camera(_:aspect:orbit:)` (yaw about the vertical axis through the authored box centre, pitch about the authored view;
  field of view refit so the box x −0.95 … 0.95, y −1.45 … 0.95, z −0.95 … 0.95 stays inside the view with at least a 5
  % margin at aspects 0.4 … 2.5; the eye outside the box; `camera(_:aspect:)` equals the authored orbit, bit-identical),
  `ringPosition`, `ghostCentre`, the ghost (a dashed outline disc of the dragged body at the previewed orbit position,
  material 17 `ghost`), the timeline marks drawn from the preview's intervals while previewing, and camera-taking
  `skyMesh`, `glowMesh`, `skyPart`, `glowPart` (billboards and paint order for the given camera; the existing signatures
  use the authored camera) to
  `Packages/ExperiencesRound02/CelestialEclipseLab/Core/CelestialEclipseLabSceneGeometry.swift`; add material 17 `ghost`
  to `Packages/ExperiencesRound02/CelestialEclipseLab/Core/CelestialEclipseLabShaders.swift`; create
  `Packages/ExperiencesRound02/CelestialEclipseLab/Core/CelestialEclipseLabPicker.swift` (FR-R02G1704-003, 005;
  SC-R02G1704-001, 004; `CelestialEclipseLabPick` body(index), dial, empty; `viewPoint` projects a world point through
  the drawn camera into view points with the origin top-left, nil behind the eye; `pick`: the front-most body (painted
  last) whose projected disc radius r · s grown by 8 points holds the point, else the dial when inside the projected
  strip-and-brackets box grown by 8 points, else empty; empty for unusable input; `dialTick`: the tick whose projected
  place on the strip is nearest to the point (lower on ties; a linear fraction misses under perspective);
  `ringOffset`: the phase whose orbit position at the shown tick projects nearest to the point, ties to the lower
  phase) with
  `Packages/ExperiencesRound02/CelestialEclipseLab/CoreTests/CelestialEclipseLabPickerTests.swift` (an independent pick,
  dial and ring rule written in the test on 500 seeded points over certified levels, 3 sizes and 3 orbits; the 8-point
  allowance at 7 and 9 points; the front-most body; unusable input) and in
  `Packages/ExperiencesRound02/CelestialEclipseLab/CoreTests/CelestialEclipseLabSceneGeometryTests.swift` (every element
  and a ghost at every orbit position inside the view at the orbit corners and 7 aspects; the ghost and preview
  timeline; no preview identical to R02-G17-03's geometry) and
  `Packages/ExperiencesRound02/CelestialEclipseLab/CoreTests/CelestialEclipseLabShaderSourceTests.swift` (the new
  material); agent B; `--name host-2`

## Phase 3: Stories 1, 2 and 3 — phase drags, taps and the time dial (P1) 🎯

- [X] T-R02G1704-003 [US1] [US2] [US3] Create — Verified 2026-11-25: 2026-11-25 gesture controller (taps choose, phase drags preview and set one phase, dial shows ticks, empty double tap resets, two-finger orbit, cancels and finished plays send no kernel action); 5 tests incl. 500 seeded scripts pass (host-3 exit 0)
  `Packages/ExperiencesRound02/CelestialEclipseLab/Core/CelestialEclipseLabGestureController.swift` (FR-R02G1704-001 …
  004, 006, 007; SC-R02G1704-001 … 003; `CelestialEclipseLabGestureAction` choosePlanet(body), showTick(tick),
  setPhase(body, offset), preview(body, offset), clearPreview, resetView, explain(reason); states idle, planetPress,
  planetDrag, dialDrag, emptyPress, orbiting, cancelled; a tap (< 10 points, lifted before 0.5 s) on a body:
  `choosePlanet` in any stage; on the dial: `showTick`; on empty space: nothing, two such taps within 0.35 s and 22
  points: `resetView`; a press lifted at 0.5 s or later without moving: nothing; a dial drag: `showTick` on every change
  from touch-down, any stage; a phase drag (≥ 16 points) from a movable body while playing: `preview(body, offset)` when
  the ring offset changes, and on release `setPhase(body, offset)` once when it differs from the current phase, else
  `clearPreview`; from a fixed body or outside playing: `explain` once and nothing else; 10 … 16 points: nothing; a
  second finger cancels (clearing a preview) and orbits (yaw 90° per width, pitch 60° per height, clamped; a third
  re-bases); cancelled phases send nothing; only event timestamps read) with
  `Packages/ExperiencesRound02/CelestialEclipseLab/CoreTests/CelestialEclipseLabGestureControllerTests.swift` (500
  seeded scripted taps, phase drags and dial drags against an independent expectation over certified levels at playing,
  won and failed plays, 3 sizes and 3 orbits, every kernel action applied through the adapter; second fingers, cancels
  and finished plays send no kernel action; orbit and the preview change no digest); agent C; `--name host-3`

## Phase 4: Story 5 — every move without gestures (P1)

- [X] T-R02G1704-004 [P] [US5] Create — Verified 2026-11-25: 2026-11-25 all 100 certified levels won through a panel model (planet choose, pending offset, Set phase, run) within each budget in 10 groups, undo and redo digests restored; host-4 exit 0
  `Packages/ExperiencesRound02/CelestialEclipseLab/CoreTests/CelestialEclipseLabPanelWinTests.swift`: all 100 certified
  levels won through panel actions only (FR-R02G1704-008; SC-R02G1704-005; planet − and + through `orbit.choose`, phase
  − and + moving the pending offset, "Set phase" sending one `orbit.phase`, then run; never more actions than the
  budget), split so each test is under 10 s, plus panel Undo then Redo restoring the digests; agent D; `--name host-4`

## Phase 5: Story 4 and wiring — orbit, reset, presenter, panel

- [X] T-R02G1704-005 [US4] Wire — Verified 2026-11-25: 2026-11-25 presenter pointer entry through the gesture controller, preview and pending offset drawn, refusals shown and logged, scene on the orbit camera rebuilt on orbit and preview changes, panel phase -/+ pending with Set phase and Reset view; sim-27b 34 tests incl. 8 wiring tests exit 0 (sim-27 failed only on a missing import VisualCoreScenes)
  `Packages/ExperiencesRound02/CelestialEclipseLab/Experience/CelestialEclipseLabPresenter.swift` (FR-R02G1704-001 …
  009; `pointer(_:viewSize:port:)` routing through the gesture controller with the drawn snapshot; setPhase sent through
  `orbit.phase`, the choices through `orbit.choose` and `clock.show`; the preview kept as presentation state and drawn;
  explain texts for a fixed body and a finished play ("The play is over: undo or go to the next level"); a refused
  action shown in the mirror message and logged with its code, reading codes with or without the engine's `action.rule.`
  prefix; `resetView()`), `Packages/ExperiencesRound02/CelestialEclipseLab/Experience/CelestialEclipseLabSkyScene.swift`
  (the orbit's camera and meshes, rebuilt when the orbit changes) and
  `Packages/ExperiencesRound02/CelestialEclipseLab/Experience/CelestialEclipseLabControls.swift` (phase − and + move the
  pending offset and preview it; "Set phase" and "Reset view"; the pending line); agent E writes
  `Packages/ExperiencesRound02/CelestialEclipseLab/ExperienceTests/CelestialEclipseLabGestureWiringTests.swift` (touches
  through the pointer entry choose a planet by a tap, set a phase by a ring drag, show ticks on the dial; orbit and
  reset change no digest; a refused phase change is shown; a drag on a won play sends nothing and says the play is over;
  the panel's Set phase), given the presenter's exact status and description texts; `--name sim-27 -- python3
  scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package --destination
  sim-27.2 --action test --only-testing CelestialEclipseLabExperienceTests`

## Phase 6: Regression, documentation and close

- [X] T-R02G1704-006 Docs: `docs/architecture/celestial-eclipse-lab.md` (gestures and the phase preview), — Verified 2026-11-25: 2026-11-25 architecture gestures section, round-two README and automatedtesting entry written; round02-host-1, -2, -3c, -3e, -3f exit 0
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host-1`, `-2`, `-3c`, `-3e`,
  `-3f`
- [X] T-R02G1704-007 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`, — Verified 2026-11-25: 2026-11-25 rendering-27, rendering-26, experiences, host-full, app-unit exit 0
  `--name host-full`, `--name app-unit`
- [X] T-R02G1704-008 Reference regression chunk 1 (`--name reference-1`) — Verified 2026-11-25: 2026-11-25 reference-1 exit 0
- [X] T-R02G1704-009 Reference regression chunk 2 (`--name reference-2`) — Verified 2026-11-25: 2026-11-25 reference-2 exit 0
- [X] T-R02G1704-010 Script tests, run alone (`--name script-tests`) — Verified 2026-11-25: 2026-11-25 script-tests exit 0, run alone
- [ ] T-R02G1704-011 {device} After ImplementationLock-100: touch feel and latency on D1/D2/D3 (SC-R02G1704-007)
- [X] T-R02G1704-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record; — Verified 2026-11-25: 2026-11-25 /speckit-converge: converged (nothing appended); README row, feature count and gate list updated
  README row and gate list updated

## Dependencies and parallel work

001 → {002 (agent B), 004 (agent D)} → 003 (agent C, on B's contract) → 005 (lead; agent E writes the wiring tests) →
006 … 010, 012. 011 stays open until device testing. Agents may draft in isolated copies before 001 (new files only).
MVP: Story 1. Requirement coverage: FR-001 → 003, 005; FR-002 → 003; FR-003 → 002, 003; FR-004 → 002, 003; FR-005 →
002; FR-006 → 002, 003, 005; FR-007 → 003, 005; FR-008 → 004, 005; FR-009 → 005 … 010.
