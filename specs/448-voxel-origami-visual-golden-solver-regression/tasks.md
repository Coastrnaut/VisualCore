# Tasks: R02-G15-08 — Voxel Origami: visual golden and solver regression

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/](contracts/), [quickstart.md](quickstart.md). Gate R02-G15-08 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G15-08 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_448;
tests stay short (< 10 s each); no wall-clock assertion.

## Phase 1: Setup

- [X] T-R02G1508-001 Baselines after R02-G15-07 is recorded: `--name baseline-host`, `--name baseline-timing`, `--name — Verified 2026-11-24: 2026-11-24 baseline-host, baseline-timing, baseline-round02-1/2/3 exit 0 (.autonomy/migration/checks/R02-G15-08.baseline-*.json)
  baseline-round02-1 … 3` (the three round-two filters of feature 446: `--filter VoxelOrigami`, `--filter
  'MoonlitMechanism|AcousticConstellator|HarmonicBridges'`, `--skip` of both)

## Phase 2: Story 1 — every level stays solvable as certified (P1) 🎯

- [X] T-R02G1508-002 [P] [US1] Create `Packages/ExperiencesRound02/VoxelOrigami/CoreTests/VoxelOrigamiRegressionSolverTests.swift` (agent A: for every — Verified 2026-11-24: 2026-11-24 host exit 0, 24 tests, slowest group ~3.7 s parallel (.autonomy/migration/checks/R02-G15-08.host.json)
  level in twenty groups of 5, "the generated level equals its witness's level (fingerprint); the witness's turns replay
  on a fresh play to a win on exactly the last turn and not before, within the budget, with its per-action fingerprints
  (after begin, after the tutorial on a tutorial level, then one per turn) and digests; plan returns exactly the
  witness's turns with statesByDepth[size − 1] equal to the counterexample's states at depth size − 1, with work ≤
  workBound"; eleven named alterations of clarification Q2 (a cube's parent, a cube's direction, a cube's start turn, a
  target cell, the allowed orientations, the budget; a plan turn; a witness action, a per-action fingerprint, a
  per-action digest; the counterexample's state count) each fail naming the level and the part); `--name host -- swift
  test --package-path Packages/ExperiencesRound02 --filter VoxelOrigamiRegressionSolverTests`

## Phase 3: Story 2 — the picture does not drift (P1)

- [X] T-R02G1508-003 [US2] Create `Packages/ExperiencesRound02/VoxelOrigami/Core/VoxelOrigamiGolden.swift` (DEBUG or VISUALCORE_AUTOMATION; "16 frames: — Verified 2026-11-24: 2026-11-24 VoxelOrigamiGolden + golden-frames.json (16 frames, chosen hinge recorded) generated with VOXEL_ORIGAMI_WRITE_GOLDEN=1; RELEASE_FORBIDDEN gains VoxelOrigamiGolden; host-2 exit 0
  levels 1, 21, 41, 61, 81 at tiers 0 … 2 at presentation time 0 after all of the witness's turns but the last (a
  one-turn witness applies none) with hinge 1 chosen, plus the hero frame of `scenario-manifest.json` at tier 0; at 1,152 × 768 with the
  authored camera: every cube centre, every hinge mark centre, every target cell centre (index order), the first covered
  pip and the first moves bar, positions rounded to 1/8 px and a point behind the eye null; the counts of cubes, hinges,
  target cells, cubes in place, lit pips and lit and total moves bars; the night, ivory, ivory shade, target, target
  glow, hinge, chosen hinge, solid and hollow glyph, dots, covered lit and unlit, moves lit and unlit, broken and glow
  colours 8-bit sRGB; JSON with sorted keys; SHA-256"; manifest; compare with the one-quantum fallback and the
  pinned-digest self-check), generate `Packages/ExperiencesRound02/VoxelOrigami/golden-frames.json` (schema 1) with
  `VOXEL_ORIGAMI_WRITE_GOLDEN=1`, and add `VoxelOrigamiGolden` to `RELEASE_FORBIDDEN` in `scripts/release_check.py`
- [X] T-R02G1508-004 [P] [US2] Create `Packages/ExperiencesRound02/VoxelOrigami/CoreTests/VoxelOrigamiRegressionGoldenTests.swift` (agent B: every frame's — Verified 2026-11-24: 2026-11-24 host-2 exit 0, 11 tests (.autonomy/migration/checks/R02-G15-08.host-2.json)
  recomputed description matches its pinned one; each pinned digest equals the digest of its pinned description; a moved
  position beyond a quantum, a changed colour or count, a missing frame, an unknown frame, schema ≠ 1 and a hand-edited
  description all fail naming the frame; the file is rewritten only with the switch); `--name host-2 -- swift test
  --package-path Packages/ExperiencesRound02 --filter VoxelOrigamiRegressionGoldenTests`

## Phase 4: Stories 2 and 3 — simulator frames and memory (P1, P2)

- [X] T-R02G1508-005 [US2] [US3] Create `Packages/ExperiencesRound02/VoxelOrigami/ExperienceTests/VoxelOrigamiRegressionGoldenFrameTests.swift` and — Verified 2026-11-24: 2026-11-24 sim-27 exit 0, 59 Voxel simulator tests incl. 3 golden-frame and 3 memory tests (.autonomy/migration/checks/R02-G15-08.sim-27.json)
  `Packages/ExperiencesRound02/VoxelOrigami/ExperienceTests/VoxelOrigamiRegressionMemoryTests.swift` (agent C: the 16 frames rendered and checked
  against their descriptions with the feature-443 tolerances (a cube centre 0.25 brighter than the night in luminance,
  the chosen hinge with red above blue by 0.08, the first moves bar 0.1 from the night, the corners within 0.05 of
  night, each point at least 6 px from what is drawn after it; points on screen where the description puts them); 12
  open-draw-warn-close cycles (prepare a level, 3 frames at tier 0, a memory warning, 1 frame, teardown) with
  `ProcessMemory.footprint()`, cycles 2 … 12 within 16 MB of cycle 1 when
  `TEST_RUNNER_VOXEL_ORIGAMI_MEMORY_ISOLATED=1`, readings printed otherwise; the voxel scene's `liveObjectCount` 0 after
  each close and warning and rebuilt by the next frame; an unavailable footprint fails with a named reason); `--name
  sim-27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme
  ExperiencesRound02-Package --destination sim-27.2 --action test --only-testing VoxelOrigamiExperienceTests`

## Phase 5: Story 4 — the checks run on every change (P2)

- [X] T-R02G1508-006 [P] [US4] Create `scripts/voxel_origami_regression.py` and its test in `scripts/test_scripts.py` — Verified 2026-11-24: 2026-11-24 regression exit 0 (host PASS, simulator PASS; .autonomy/migration/checks/R02-G15-08.regression.json); script test 5/5; CI step added
  (agent D: host filter `VoxelOrigamiRegression`, then the simulator classes through `xcodebuild_package.py
  --only-testing` with the isolation variable, one summary line per part with pass or fail and the first failing name,
  a non-zero exit on any failure), and add the named step "Voxel Origami regression (host)" to the `round02-host-tests`
  job of `.github/workflows/ci.yml`; `--name regression -- python3 scripts/voxel_origami_regression.py`

## Phase 6: Regression, documentation and close

- [X] T-R02G1508-007 Docs: `docs/architecture/voxel-origami.md` (regression net), — Verified 2026-11-24: 2026-11-24 round02-host-1/2/3 exit 0 (56 s, 45 s, 347 s; .autonomy/migration/checks/R02-G15-08.round02-host-*.json)
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host-1 … 3` (the three filters)
- [X] T-R02G1508-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`, — Verified 2026-11-24: 2026-11-24 rendering-27, rendering-26, experiences, host-full, app-unit exit 0 (.autonomy/migration/checks/R02-G15-08.*.json)
  `--name host-full`, `--name app-unit`
- [ ] T-R02G1508-009 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G1508-010 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G1508-011 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G1508-012 {device} After ImplementationLock-100, on D1, D2 and D3: frame time and memory of the golden levels.
  Not run before the lock.
- [ ] T-R02G1508-013 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record;
  README row and gate list updated

## Dependencies and parallel work

001 → {002 (agent A), 003 (lead) → 004 (agent B), 005 (agent C), 006 (agent D)} → 007 … 011, 013. 012 is a {device}
task outside this campaign. Agent A may start in an isolated copy before 001 (a new test file). Shared files (golden
source, release list, workflow, docs) stay with the lead. MVP: Story 1. Requirement coverage: FR-001/002 → 002;
FR-003/004 → 003, 004, 005; FR-005 → 005; FR-006 → 006; FR-007 → 002 … 006; FR-008 → 007 … 011.
