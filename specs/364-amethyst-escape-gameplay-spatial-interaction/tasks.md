# Tasks: R02-G07-04 — Amethyst Escape: gameplay spatial interaction

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G07-04 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G07-04 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_364;
tests stay short (< 10 s each). No {owner} tasks.

## Phase 1: Setup

- [X] T-R02G0704-001 Baselines: `--name baseline-host`, `--name baseline-timing`, `--name baseline-round02 -- swift test — Verified 2026-11-22: 2026-11-22: baseline-host, baseline-timing, baseline-round02 exit 0; rendering baseline = R02-G07-03 rendering-27/26 exit 0
  --package-path Packages/ExperiencesRound02`; the rendering baseline is R02-G07-03's rendering runs (exit 0)

## Phase 2: Foundational — preview, orbit, picking and isolation

- [X] T-R02G0704-002 [P] Add `previewing(shell:sectors:)` to `Packages/ExperiencesRound02/AmethystEscape/Core/AmethystEscapeSceneSnapshot.swift` (the shell's — Verified 2026-11-22: 2026-11-22: host-2 (AmethystEscapePreviewTests, 2 tests: preview equals kernel turns on 6 levels, every shell, n in -S/2...S/2) exit 0
  offset turned by n sectors mod S, and the pearl's absolute sector with it when it rests in that shell; nothing else
  changes) with tests in `Packages/ExperiencesRound02/AmethystEscape/CoreTests/AmethystEscapePreviewTests.swift` (a preview equals the snapshot after n
  kernel turns of that shell for n in −⌊S/2⌋ … ⌊S/2⌋ on certified levels); lead; `--name host-2`
- [ ] T-R02G0704-003 [P] Add `AmethystEscapeOrbit` ("yaw ±40°, pitch 30° … 75°, authored (0, 50°)"),
  `camera(_:aspect:orbit:)` (distance refit to the bounding sphere of radius 1.1 with a 5 % margin;
  `camera(_:aspect:)` equals the authored orbit, bit-identical) and the isolation parameter (`crystalPart`/`crystalMesh`
  with `isolated: Int?`: every other shell's wedges, fins and marks at shade 0.25; nil leaves the mesh unchanged) to
  `Packages/ExperiencesRound02/AmethystEscape/Core/AmethystEscapeSceneGeometry.swift`; create `Packages/ExperiencesRound02/AmethystEscape/Core/AmethystEscapePicker.swift` (touch ray through the drawn
  camera; the pearl sphere or within 22 points of its projected centre first; else the shells' top planes y = h_k from
  the innermost outward, first hit inside r_k … r_k + w; else the shell whose projected top-ring midline lies within 22
  points; `angle(shell:at:…)` = atan2(z, x) on the shell's plane) with `Packages/ExperiencesRound02/AmethystEscape/CoreTests/AmethystEscapePickerTests.swift`
  (an independent pick and angle written in the test on 500 seeded points over certified levels, sizes and orbits;
  minimum target) and orbit framing and isolation in `Packages/ExperiencesRound02/AmethystEscape/CoreTests/AmethystEscapeSceneGeometryTests.swift`; agent B;
  `--name host-3`

## Phase 3: Stories 1 and 2 — turn a shell, advance the pearl (P1) 🎯

- [ ] T-R02G0704-004 [US1] [US2] [US3] Create `Packages/ExperiencesRound02/AmethystEscape/Core/AmethystEscapeGestureController.swift` (states idle, shellDrag,
  pearlPress, orbiting, cancelled; a shell drag while playing: unwrapped swept angle, n = round(swept / (2π/S)) reduced to
  −⌊S/2⌋ … ⌊S/2⌋, |n| `turn(shell, sign(n))` after ≥ 16 points, nothing when n = 0; a tap (< 10 points, ≤ 0.5 s) on
  the pearl while playing: `advance`; a tap on a shell: `select(shell)`; a double tap (≤ 0.35 s, ≤ 22 points) on a
  shell: `isolate(shell)` or `isolate(nil)` when it is already isolated; on empty space: `resetView`; a finished play
  sends no turn or advance; a second finger cancels and orbits (yaw 90° per width, pitch 60° per height, clamped), a third
  re-bases; cancelled phases send nothing; only event timestamps read) with
  `Packages/ExperiencesRound02/AmethystEscape/CoreTests/AmethystEscapeGestureControllerTests.swift` (500 seeded scripted drags and taps against an independent
  expectation over 3 sizes and 3 orbits; second fingers, cancels and finished plays send no action; 10 … 16 points send
  nothing; isolation and orbit change no digest); agent C; `--name host-4`

## Phase 4: Story 5 — every move without gestures (P1)

- [ ] T-R02G0704-005 [P] [US5] Create `Packages/ExperiencesRound02/AmethystEscape/CoreTests/AmethystEscapePanelWinTests.swift`: all 100 certified levels won
  through panel actions only (shell picker, turn − and + as `shell.rotate [k, ±1]`, advance as `pearl.advance`), split
  so each test is under 10 s, plus panel Undo then Redo after a turn restoring the digests before and after it; agent D;
  `--name host-5`

## Phase 5: Stories 3 and 4 and wiring — isolation, orbit, reset, presenter

- [ ] T-R02G0704-006 [US3] [US4] Wire `Packages/ExperiencesRound02/AmethystEscape/Experience/AmethystEscapePresenter.swift` (`pointer(_:viewSize:port:)` routing
  through the gesture controller, `select` setting the mirror's picked shell, `isolate`, `showAllLayers()` (also on
  `level.next`), `resetView()`, the descriptions "Shell k would turn n sectors clockwise" / "anticlockwise" / "would
  not turn" and, for a gesture on a finished play, "The play is over: undo or go to the next level"; a gesture's refused
  action shown in the mirror message like the panel's and logged with its code),
  `Packages/ExperiencesRound02/AmethystEscape/Experience/AmethystEscapeCrystalScene.swift` (the orbit's camera; the drag preview snapshot; the isolation; the
  fallback follows) and `Packages/ExperiencesRound02/AmethystEscape/Experience/AmethystEscapeControls.swift` ("Show all layers", "Reset view"); agent E writes
  `Packages/ExperiencesRound02/AmethystEscape/ExperienceTests/AmethystEscapeGestureWiringTests.swift` (touches through the pointer entry send the expected
  actions; orbit, isolation and reset change no digest; a refused gesture action is shown); `--name sim-27 -- python3
  scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package --destination
  sim-27.2 --action test --only-testing AmethystEscapeExperienceTests`

## Phase 6: Regression, documentation and close

- [ ] T-R02G0704-007 Docs: `docs/architecture/amethyst-escape.md` (gestures), `Packages/ExperiencesRound02/README.md`,
  `docs/automatedtesting.md`; `--name round02-host`
- [ ] T-R02G0704-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`,
  `--name host-full`, `--name app-unit`
- [ ] T-R02G0704-009 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G0704-010 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G0704-011 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G0704-012 {device} After ImplementationLock-100: touch feel and latency on D1/D2/D3 (SC-R02G0704-007)
- [ ] T-R02G0704-013 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record

## Dependencies and parallel work

001 → {002 (lead), 003 (agent B), 005 (agent D)} → 004 (agent C, on B's picker and the lead's preview) → 006 (lead;
agent E writes the wiring tests) → 007 … 011, 013. 012 stays open until device testing. Shared files (snapshot,
presenter, scene, controls, docs) stay with the lead. MVP: Stories 1, 2 and 5.
