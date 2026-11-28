# Tasks: R02-G22-04 — Mycelium Architect: gameplay spatial interaction

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G22-04. Evidence: `python3
scripts/migration_ledger.py run-check --gate R02-G22-04 --name <check> -- <command>` (never a scratchpad path; read
`exit=` before ticking). Commit after every task (no trailers). Tests short (< 10 s each), seed 2_514. New sources in
`Packages/ExperiencesRound02/MyceliumArchitect/Core/Presentation/`. Every `host` check runs `swift test --package-path Packages/ExperiencesRound02 --filter
MyceliumArchitect`.

## Phase 1: Setup

- [ ] T-R02G2204-001 Baselines after R02-G22-03 is recorded: `--name baseline-host`, `--name baseline-timing`, `--name
  baseline-round02-1` (`VoxelOrigami|MyceliumArchitect`), `-2`, `-3c`, `-3e`, `-3f`

## Phase 2: Foundational

- [ ] T-R02G2204-002 Create `Packages/ExperiencesRound02/MyceliumArchitect/Core/Presentation/MyceliumArchitectViewOrbit.swift` (yaw ±60°, pitch −20° … +35°,
  re-fitted camera with ≥ 5 % margin at aspects 0.4 … 2.5); edit `MyceliumArchitectSceneSnapshot.swift` (tool,
  preview, inspected cell, orbit as presentation state), `MyceliumArchitectSceneGeometry.swift` (dashed ghost veins,
  inspection ring, orbit camera) and `MyceliumArchitectExperienceCore.swift` (`previewReport(_:)` through the kernel's
  change rule and growth; presentation state reset at opening, next level, reset and restore); host tests for these;
  `--name host`

## Phase 3: Stories 1–5 — gestures (P1) 🎯

- [ ] T-R02G2204-003 [P] [US1] [US2] [US3] [US4] Create `Packages/ExperiencesRound02/MyceliumArchitect/Core/Presentation/MyceliumArchitectPicker.swift` (agent A:
  clarification Q1 priority and hit rules, cast onto z = 0, direction by board angle, pulse by the gauge formula) with
  `Packages/ExperiencesRound02/MyceliumArchitect/CoreTests/MyceliumArchitectPickerTests.swift` (500 seeded cases against an independent projection at several sizes
  and orbits); `--name host-2`
- [ ] T-R02G2204-004 [P] [US1] [US2] [US3] [US4] [US5] Create `Packages/ExperiencesRound02/MyceliumArchitect/Core/Presentation/MyceliumArchitectGestureController.swift`
  (agent B: clarification Q2–Q5 state machine, feature 504's constants, reasons in words) with
  `Packages/ExperiencesRound02/MyceliumArchitect/CoreTests/MyceliumArchitectGestureControllerTests.swift` (taps, presses, previews, seed and unseed drags, scrubs,
  second fingers, cancels, outside playing; 200 previews equal the kernel's); `--name host-3`

## Phase 4: Story 6 — every move without gestures (P1)

- [ ] T-R02G2204-005 [US6] Create `Packages/ExperiencesRound02/MyceliumArchitect/CoreTests/MyceliumArchitectPanelWinTests.swift` (all 100 certified witnesses won
  through panel actions within their budgets, in groups); `--name host-4`
- [ ] T-R02G2204-006 [US1] [US6] Edit `Packages/ExperiencesRound02/MyceliumArchitect/Experience/MyceliumArchitectPresenter.swift`, `MyceliumArchitectBoardScene.swift`,
  `MyceliumArchitectControls.swift` (pointer routing through the controller, tool buttons Nutrient and Blocker, place
  at cursor, Inspect: none, Reset view, ghosts and inspection drawn) and create
  `Packages/ExperiencesRound02/MyceliumArchitect/ExperienceTests/MyceliumArchitectGestureWiringTests.swift` (agent C); `--name sim-27`

## Phase 5: Regression, documentation and close

- [ ] T-R02G2204-007 Docs: `docs/architecture/mycelium-architect.md` (gestures), package README,
  `docs/automatedtesting.md`; `--name round02-host-1`, `-2`, `-3c`, `-3e`, `-3f`
- [ ] T-R02G2204-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`,
  `--name host-full`
- [ ] T-R02G2204-009 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G2204-010 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G2204-011 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G2204-012 {device} After ImplementationLock-100: touch feel and latency on D1/D2/D3 (SC-R02G2204-008)
- [ ] T-R02G2204-013 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record;
  README row and gate list updated

## Dependencies and parallel work

001 → 002 (lead) → {003 (agent A), 004 (agent B)} → 005 (lead) → 006 (agent C) → 007 … 011, 013; 012 stays open. Shared
files (snapshot, geometry, adapter, orbit, docs) stay with the lead. MVP: Stories 1–3. Coverage: FR-001, 002 → 003, 004;
FR-003, 004, 005 → 003, 004; FR-006 → 002, 004; FR-007 → 003; FR-008 → 002, 004; FR-009, 010 → 004; FR-011 → 005, 006;
FR-012 → 003 … 006; FR-013 → 002, 006; FR-014 → 002; SC-001 … 004, 006 → 003, 004; SC-005 → 005; SC-007 → 007 … 011;
SC-008 → 012.
