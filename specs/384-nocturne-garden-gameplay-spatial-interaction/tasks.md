# Tasks: R02-G09-04 — Nocturne Garden: gameplay spatial interaction

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G09-04 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G09-04 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_384;
tests stay short (< 10 s each). No {owner} tasks.

## Phase 1: Setup

- [X] T-R02G0904-001 Baselines on the committed tree: `--name baseline-host`, `--name baseline-timing`, `--name — Verified 2026-11-22: baseline-host, baseline-timing, baseline-round02 exit=0 on the committed tree (the feature's work held aside); rendering baseline is R02-G09-03's rendering runs (exit 0)
  baseline-round02 -- swift test --package-path Packages/ExperiencesRound02`; the rendering baseline is R02-G09-03's
  rendering runs (exit 0)

## Phase 2: Foundational — preview field, orbit and picking

- [X] T-R02G0904-002 Add the snapshot's `preview` cells ("sorted would-be cells; empty when none") and — Verified 2026-11-22: host exit=0 (29 tests: NocturneGardenShaderSourceTests with the preview material 12 in the selection, emissive set and dashed outline; adapter suite unchanged); snapshot preview cells and withPreview
  `withPreview(_:)` to `Packages/ExperiencesRound02/NocturneGarden/Core/NocturneGardenSceneSnapshot.swift` and the preview material (code 12, a pale dashed
  outline drawn from world coordinates) to `Packages/ExperiencesRound02/NocturneGarden/Core/NocturneGardenShaders.swift` with its source test in
  `Packages/ExperiencesRound02/NocturneGarden/CoreTests/NocturneGardenShaderSourceTests.swift`; `--name host`
- [X] T-R02G0904-003 [P] Add `NocturneGardenOrbit` ("yaw ±35°, pitch 0° … 30° down, authored (0, 8°)"), — Verified 2026-11-22: host-2 exit=0 (22 tests: NocturneGardenPickerTests 6 incl. 500 seeded picks and bed cells against an independent pick, 22-point targets, nearest bloom, 500 seeded sun steps and pinch sizes; geometry suite with orbit clamping, authored camera bit-identical, framing at the orbit corners and aspects, preview outline along the boundary edges; agent B's files retested by the lead)
  `camera(_:aspect:orbit:)` (distance refit so the level's framing sphere stays inside the view with a 5 % margin;
  `camera(_:aspect:)` equals the authored orbit, bit-identical) and the preview outline (the boundary edges of the
  preview cells, z = 0.0035, preview material) to `Packages/ExperiencesRound02/NocturneGarden/Core/NocturneGardenSceneGeometry.swift`; create
  `Packages/ExperiencesRound02/NocturneGarden/Core/NocturneGardenPicker.swift` (touch ray through the drawn camera; the lantern's projected centre within 22
  points first, then the blooms — the ray meets a head box at z = 0.37 or the projected foot or head centre lies within
  22 points, nearest to the eye, ties to the lower index — then the bed cell under the ray on z = 0, else outside the
  bed or empty; `bedCell`; `sunElevation`: one step per 48 points of vertical drag, down = larger elevation, nearest
  allowed; `pinchSize`: the allowed size nearest size·scale) with `Packages/ExperiencesRound02/NocturneGarden/CoreTests/NocturneGardenPickerTests.swift` (an
  independent pick, cell, sun step and pinch size written in the test on 500 seeded points over certified levels, sizes
  and orbits; minimum target) and orbit framing and the preview outline in
  `Packages/ExperiencesRound02/NocturneGarden/CoreTests/NocturneGardenSceneGeometryTests.swift`; agent B; `--name host-2`

## Phase 3: Stories 1 to 3 — plant, drag with preview, pinch, sun (P1) 🎯

- [X] T-R02G0904-004 [US1] [US2] [US3] Create `Packages/ExperiencesRound02/NocturneGarden/Core/NocturneGardenDragPreview.swift` (the would-be mask with the — Verified 2026-11-22: host-3 exit=0 (NocturneGardenGestureControllerTests 7: 500 seeded scripts over 3 sizes and 3 orbits against an independent expectation with every preview equal to the kernel's mask, 10-16 points send nothing, second fingers, cancels and finished plays send nothing, double tap resets, orbit clamps and re-bases, previews and orbit never change the digest; agent C's files retested by the lead)
  bloom moved to (column, row) or removed, computed with `NocturneGardenMask.union` on a copy of the blooms; shared,
  either and leak; text "would match 12/16, leak 0 cells" or "would remove: match …") and
  `Packages/ExperiencesRound02/NocturneGarden/Core/NocturneGardenGestureController.swift` (states idle, bedPress, bloomPress, bloomDrag, lanternDrag, pinch,
  orbiting, cancelled; a tap (< 10 points, ≤ 0.5 s) on a bed cell while playing: `plant(kind, column, row, size)`; on
  a bloom: `choose(bloom)`; a bloom drag (≥ 16 points): the preview at the grab-offset target while moving, on release
  `move` (nothing at its own anchor) or `remove` outside the bed; a lantern drag: `sun` on release when the
  elevation changed; a second finger cancels the one-finger gesture and pinches a bloom (`resize` on release when the
  size changed) or orbits (yaw 90° per width, pitch 60° per height, clamped; a third re-bases); a double tap (≤ 0.35 s,
  ≤ 22 points) on empty space: `resetView`; 10 … 16 points: nothing; on a finished play no action; cancelled phases
  send nothing; only event timestamps read) with `Packages/ExperiencesRound02/NocturneGarden/CoreTests/NocturneGardenGestureControllerTests.swift` (500 seeded
  scripted gestures against an independent expectation over 3 sizes and 3 orbits; second fingers, cancels and finished
  plays send nothing; every drag preview equals the kernel's shadow after the move; previews and orbit change no
  digest); agent C; `--name host-3`

## Phase 4: Story 5 — every move without gestures (P1)

- [X] T-R02G0904-005 [P] [US5] Create `Packages/ExperiencesRound02/NocturneGarden/CoreTests/NocturneGardenPanelWinTests.swift`: all 100 certified levels won — Verified 2026-11-22: host-4 exit=0 (NocturneGardenPanelWinTests: all 100 certified levels won through panel presses alone in 10 groups, panel undo and redo restore the digests; note: single-step Sun ± costs up to 2 extra moves on 35 levels, addressed in T-006 by a sun picker; agent D's file retested by the lead)
  through panel actions only (the kind, column, row and size pickers then Plant send `bloom.plant`; the bloom picker
  with Move, Resize and Remove; Sun − and + send `sun.set`), split so each test is under 10 s, plus panel Undo then
  Redo after a plant restoring the digests before and after it; agent D; `--name host-4`

## Phase 5: Story 4 and wiring — orbit, reset, presenter

- [X] T-R02G0904-006 [US4] Wire `Packages/ExperiencesRound02/NocturneGarden/Experience/NocturneGardenPresenter.swift` (`pointer(_:viewSize:port:)` routing — Verified 2026-11-22: sim-27 exit=0 (NocturneGardenExperienceTests, 40 tests in 5 suites on iOS 27.2, incl. 8 gesture wiring tests: tap plants, drag moves with the exact preview, drag off the bed removes, lantern drag steps the sun, pinch resizes, orbit and reset change no digest, a finished play says so, a refused gesture is shown and logged); host-5 exit=0 (155 Nocturne Garden host tests); the panel's sun became a picker with Set sun so the panel wins all 100 levels in their certified move counts (spec US5 corrected); the invariant scan skips the three new presentation sources; agent E's tests retested by the lead
  through the gesture controller with the mirror's kind and size; `choose` setting the mirror's bloom; actions sent
  through the port; `resetView()`; the preview drawn and described while dragging; for an action on a finished play,
  "The play is over: undo or go to the next level"; a refused gesture action shown in the mirror message and logged with
  its code), `Packages/ExperiencesRound02/NocturneGarden/Experience/NocturneGardenGardenScene.swift` (the orbit's camera; the preview outline; the fallback
  follows) and `Packages/ExperiencesRound02/NocturneGarden/Experience/NocturneGardenControls.swift` ("Reset view"); agent E writes
  `Packages/ExperiencesRound02/NocturneGarden/ExperienceTests/NocturneGardenGestureWiringTests.swift` (touches through the pointer entry plant, move, remove,
  resize and change the sun as expected; orbit and reset change no digest; a refused gesture action is shown);
  `--name sim-27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme
  ExperiencesRound02-Package --destination sim-27.2 --action test --only-testing NocturneGardenExperienceTests`

## Phase 6: Regression, documentation and close

- [ ] T-R02G0904-007 Docs: `docs/architecture/nocturne-garden.md` (gestures), `Packages/ExperiencesRound02/README.md`,
  `docs/automatedtesting.md`; `--name round02-host`
- [ ] T-R02G0904-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`,
  `--name host-full`, `--name app-unit`
- [ ] T-R02G0904-009 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G0904-010 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G0904-011 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G0904-012 {device} After ImplementationLock-100: touch feel and latency on D1/D2/D3 (SC-R02G0904-007)
- [ ] T-R02G0904-013 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record

## Dependencies and parallel work

001 → 002 (lead) → {003 (agent B), 005 (agent D)} → 004 (agent C, on B's picker) → 006 (lead; agent E writes the wiring
tests) → 007 … 011, 013. 012 stays open until device testing. Shared files (snapshot, shaders, presenter, scene,
controls, docs) stay with the lead. MVP: Stories 1 to 3 and 5.
