# Tasks: R02-G01-04 — Aurora Loom: gameplay spatial interaction

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G01-04 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G01-04 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_304;
tests stay short (< 10 s each).

## Phase 1: Setup

- [ ] T-R02G0104-001 Baselines: `--name baseline-host`, `--name baseline-timing`, `--name baseline-round02 -- swift test
  --package-path Packages/ExperiencesRound02`; the rendering baseline is R02-G01-03's rendering runs (exit 0)

## Phase 2: Foundational

- [ ] T-R02G0104-002 [P] Create `Packages/ExperiencesRound02/AuroraLoom/Core/AuroraLoomHandles.swift` (AuroraLoomHandleID "id = ribbon · 2 + control",
  anchor rail "x = +L/2 + 0.45, y = H · (2w/15 − 1)", dial "centre x = −L/2 − 0.45, radius 0.3, knob at p · 22.5°",
  waveStep "round((y/H + 1) · 7.5) clamped 0 … 15", phaseStep "start + round(angle / 22.5°) mod 16", six SpatialHandles)
  and edit `Packages/ExperiencesRound02/AuroraLoom/Core/AuroraLoomSceneGeometry.swift` (AuroraLoomOrbit "azimuth offset −40° … 40°, elevation 10° … 60°",
  camera(aspect:orbit:), content box including rails and dials) with `Packages/ExperiencesRound02/AuroraLoom/CoreTests/AuroraLoomHandlesTests.swift` and
  `Packages/ExperiencesRound02/AuroraLoom/CoreTests/AuroraLoomSceneGeometryTests.swift` updates (every step round-trips; framing for every orbit limit and aspect
  0.4 … 2.5); `--name host -- swift test --package-path Packages/ExperiencesRound02 --filter
  'AuroraLoomHandlesTests|AuroraLoomSceneGeometryTests'`

## Phase 3: Stories 1–3 — anchors, dials and camera (P1) 🎯

- [ ] T-R02G0104-003 [P] [US1] [US2] [US3] Create `Packages/ExperiencesRound02/AuroraLoom/Core/AuroraLoomGestureController.swift` (states idle, dragging,
  orbiting, cancelled; picking via HandlePicker; drags via HandleDrag; one move on release when changed; second finger
  cancels; cancelled touches; playing-only; orbit from two-finger midpoint "90° per width, 60° per height", clamped;
  resetOrbit; selection) with `Packages/ExperiencesRound02/AuroraLoom/CoreTests/AuroraLoomGestureControllerTests.swift` (500 seeded scripted drags agree with an
  independent computation of the end step; 1,000 seeded arbitration scripts; two handles under one touch pick the
  nearest, ties by the lower id; orbit limits; selection; determinism);
  `--name host-2`
- [ ] T-R02G0104-004 [US1] [US2] [US3] [US4] Wire the experience: `Packages/ExperiencesRound02/AuroraLoom/Experience/AuroraLoomPresenter.swift` (pointer events →
  controller → `ribbon.move` through the port; refusal text; orbit into the camera; selection and candidate in the
  description and mirror), `Packages/ExperiencesRound02/AuroraLoom/Experience/AuroraLoomRibbonScene.swift` (rails, anchors, dials with knobs, the selected ribbon's
  gold outline, the drag preview; camera with the orbit), `Packages/ExperiencesRound02/AuroraLoom/Experience/AuroraLoomControls.swift` ("Reset view"; steppers select
  their ribbon); `--name round02-build -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesRound02
  --scheme ExperiencesRound02-Package --destination sim-27.2 --action build`

## Phase 4: Story 4 and simulator proof (P2)

- [ ] T-R02G0104-005 [US4] Create `Packages/ExperiencesRound02/AuroraLoom/ExperienceTests/AuroraLoomGestureWiringTests.swift` (scripted touches through the presenter's
  pointer entry move the kernel by exactly the named step; a second finger and a cancel send nothing; gestures while
  paused or after the level ends send nothing and a refused move shows its text with the state unchanged; the selection
  outline is drawn; the description names the selection; undo after a gesture restores the digest; frame checks hold at
  the orbit limits; Reset view returns the authored pose); `--name sim-27 -- python3 scripts/xcodebuild_package.py
  --package Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package --destination sim-27.2 --action test`

## Phase 5: Regression, documentation and close

- [ ] T-R02G0104-006 Docs: `docs/architecture/aurora-loom.md` (controls), `Packages/ExperiencesRound02/README.md`,
  `docs/automatedtesting.md`; `--name round02-host -- swift test --package-path Packages/ExperiencesRound02`; the
  content audit `--name audits -- python3 scripts/verify_experiences.py --audits --only r02-g01.aurora-loom`
- [ ] T-R02G0104-007 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`,
  `--name host-full`, `--name app-unit -- python3 scripts/release_check.py --only app-build-for-testing-ios27
  app-unit-ios27`
- [ ] T-R02G0104-008 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G0104-009 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G0104-010 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G0104-011 {device} After ImplementationLock-100, on D1, D2 and D3: record gesture feel and touch-to-frame
  latency (SC-R02G0104-006). Not run before the lock; stays open and is carried to the device campaign.
- [ ] T-R02G0104-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record

## Dependencies and parallel work

001 → {002 (agent B), 003 (agent C, against the contract; uses 002's handle layout once it lands)} → 004 (lead) → 005
(agent D writes, lead runs) → 006 … 010, 012. 011 is a {device} task outside this campaign. MVP: Stories 1–3.
