# Tasks: R02-G03-04 — Wave Knot Keeper: gameplay spatial interaction

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G03-04 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G03-04 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_324;
tests stay short (< 10 s each). No {owner} tasks.

## Phase 1: Setup

- [X] T-R02G0304-001 Baselines: `--name baseline-host`, `--name baseline-timing`, `--name baseline-round02 -- swift test — Verified 2026-11-21: 2026-11-21 R02-G03-04.baseline-host/timing/round02 exit 0
  --package-path Packages/ExperiencesRound02`; the rendering baseline is R02-G03-03's runs (exit 0)

## Phase 2: Foundational

- [X] T-R02G0304-002 Edit `Packages/ExperiencesRound02/WaveKnotKeeper/Core/WaveKnotKeeperSceneGeometry.swift` (`WaveKnotKeeperOrbit` "yaw −40° … 40°, pitch 5° … — Verified 2026-11-21: 2026-11-21 host-2 exit 0 (orbit yaw ±40 pitch 5-60 with refit inside 5 % at every limit and 7 aspects; handle picking nearest to the eye; 500 seeded drags equal an independent candidate; 20 tests)
  60°, authored 20°", `camera(for:aspect:orbit:)` refitting the bounds for a 5 % margin; the existing camera equals the
  authored orbit) and create `Packages/ExperiencesRound02/WaveKnotKeeper/Core/WaveKnotKeeperHandles.swift` (`pick` with "touch radius 22 points, nearest to
  the eye wins"; `candidate` "best-aligned projected unit step, ties to the lower direction index, snap ≥ max(6 points,
  half the projected step)") with `Packages/ExperiencesRound02/WaveKnotKeeper/CoreTests/WaveKnotKeeperHandlesTests.swift` and orbit framing tests in
  `Packages/ExperiencesRound02/WaveKnotKeeper/CoreTests/WaveKnotKeeperSceneGeometryTests.swift` (agent B: 500 seeded drags equal an independent computation;
  every orbit limit and 7 aspects keep the scene inside with 5 %); `--name host-2`

## Phase 3: Stories 1 and 2 — drag to move, orbit to look (P1) 🎯

- [X] T-R02G0304-003 [US1] [US2] Create `Packages/ExperiencesRound02/WaveKnotKeeper/Core/WaveKnotKeeperGestureController.swift` (idle, dragging, orbiting, — Verified 2026-11-21: 2026-11-21 host-3 exit 0 (gesture controller: 10 tests incl. 300 seeded drags equal Handles.candidate, every arbitration case, orbit rates and limits, double-tap reset, determinism)
  cancelled; one finger on a handle drags and selects; a tap selects only; a second finger cancels and orbits; release
  returns at most one `point.move [point, direction]`; nothing while not playing except selection; double tap on empty
  space resets the orbit) with `Packages/ExperiencesRound02/WaveKnotKeeper/CoreTests/WaveKnotKeeperGestureControllerTests.swift` (agent C: every arbitration
  case of SC-R02G0304-002; orbit rates and limits; determinism); `--name host-3`

## Phase 4: Story 3 — play with the panel alone (P1)

- [X] T-R02G0304-004 [US3] Create `Packages/ExperiencesRound02/WaveKnotKeeper/CoreTests/WaveKnotKeeperPanelWinTests.swift` (agent D: all 100 certified levels — Verified 2026-11-21: 2026-11-21 host-4 exit 0 (all 100 certified levels won through point.select and point.move panel actions in exactly their certified shortest moves; 5 band tests, each under 3.2 s)
  won through the adapter's `point.select` and `point.move` actions the panel sends, in exactly their certified shortest
  number of moves, split by band); `--name host-4`

## Phase 5: Story 4 and wiring — selection, preview, presenter (P2)

- [ ] T-R02G0304-005 [US4] Edit `Packages/ExperiencesRound02/WaveKnotKeeper/Experience/WaveKnotKeeperPresenter.swift` (pointer entry through the gesture
  controller, `resetView()`, orbit-aware camera, ghost preview of the candidate, announcements of refusals),
  `Packages/ExperiencesRound02/WaveKnotKeeper/Experience/WaveKnotKeeperRopeScene.swift` (orbit camera, ember ghost sphere) and
  `Packages/ExperiencesRound02/WaveKnotKeeper/Experience/WaveKnotKeeperControls.swift` ("Reset view"), with `Packages/ExperiencesRound02/WaveKnotKeeper/ExperienceTests/WaveKnotKeeperGestureWiringTests.swift`
  (agent E: scripted drags through the experience's pointer entry move the point; selection drawn in ember and
  described; orbit never changes the digest); `--name sim-27 -- python3 scripts/xcodebuild_package.py --package
  Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package --destination sim-27.2 --action test`

## Phase 6: Regression, documentation and close

- [ ] T-R02G0304-006 Docs: `docs/architecture/wave-knot-keeper.md` (interaction), `Packages/ExperiencesRound02/README.md`,
  `docs/automatedtesting.md`; `--name round02-host`
- [ ] T-R02G0304-007 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`,
  `--name host-full`, `--name app-unit`
- [ ] T-R02G0304-008 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G0304-009 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G0304-010 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G0304-011 {device} After ImplementationLock-100, on D1, D2 and D3: record gesture feel and touch-to-frame
  latency (SC-R02G0304-007)
- [ ] T-R02G0304-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record

## Dependencies and parallel work

001 → 002 (agent B) → {003 (agent C), 004 (agent D)} → 005 (lead; agent E) → 006 … 010, 012. 011 stays open until
device testing. Shared files (presenter, scene, controls, docs) stay with the lead. MVP: Stories 1–3.
