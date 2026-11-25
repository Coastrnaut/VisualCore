# Tasks: R02-G17-08 — Celestial Eclipse Lab: visual golden and solver regression

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/](contracts/), [quickstart.md](quickstart.md). Gate R02-G17-08 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G17-08 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_468;
tests stay short (< 10 s each); no wall-clock assertion. No agent runs host tests while a baseline or chain runs.

## Phase 1: Setup

- [X] T-R02G1708-001 Baselines on the committed tree after R02-G17-07 is recorded: `--name baseline-host`, `--name — Verified 2026-11-25: 2026-11-25 baseline-host, baseline-timing, baseline-round02-1, -2, -3c, -3e, -3f exit 0 on the committed tree (.autonomy/migration/checks/R02-G17-08.baseline-*.json)
  baseline-timing`, `--name baseline-round02-1`, `-2`, `-3c`, `-3e`, `-3f` (the five round-two filters, chunk 3c with
  `CelestialEclipseLab`)

## Phase 2: Story 1 — every level stays solvable as certified (P1) 🎯

- [X] T-R02G1708-002 [P] [US1] Create — Verified 2026-11-25: 2026-11-25 host exit 0, 14 tests (.autonomy/migration/checks/R02-G17-08.host.json): 100 witnesses replayed to a win on the final run with their fingerprints and digests, 100 re-plans equal to the witness changes and counterexample settings within the work bound, twelve alterations named
  `Packages/ExperiencesRound02/CelestialEclipseLab/CoreTests/CelestialEclipseLabRegressionSolverTests.swift` (agent A:
  for every level in ten groups of 10, "the generated level equals its witness's level (fingerprint); the witness's
  actions replay on a fresh play to a win on exactly the final run and not before, within the budget, with its
  per-action fingerprints (after begin, after the tutorial on a tutorial level, then one per action) and digests; plan
  returns exactly the witness's phase changes with settingsByDepth[size − 1] equal to the counterexample's settings at
  depth size − 1, with work ≤ workBound"; twelve named alterations of clarification Q2 (a body's orbit point, a body's
  radius, a body's fixed flag, a starting phase, a target's bodies, a target's window, the horizon, the budget; a plan
  phase change; a witness action, a per-action fingerprint or digest; the counterexample's settings count) each fail
  naming the level and the part); `--name host -- swift test --package-path Packages/ExperiencesRound02 --filter
  CelestialEclipseLabRegressionSolverTests`

## Phase 3: Story 2 — the picture does not drift (P1)

- [X] T-R02G1708-003 [US2] Create — Verified 2026-11-25: 2026-11-25 CelestialEclipseLabGolden (16 frames, 21 colours) and golden-frames.json generated with CELESTIAL_ECLIPSE_LAB_WRITE_GOLDEN=1, checked by host-2 exit 0 (.autonomy/migration/checks/R02-G17-08.host-2.json); CelestialEclipseLabGolden added to RELEASE_FORBIDDEN
  `Packages/ExperiencesRound02/CelestialEclipseLab/Core/CelestialEclipseLabGolden.swift` (DEBUG or
  VISUALCORE_AUTOMATION; "16 frames: levels 1, 21, 41, 61, 81 at tiers 0 … 2 at presentation time 0 after all of the
  witness's phase changes but not the run, with the default chosen body, shown at the first tick of the predicted
  timeline at which an eclipse is under way (tick 0 when there is none), plus the hero frame of
  `scenario-manifest.json` at tier 0; at 1,152 × 768 with the authored camera: every body centre at the shown tick
  (index order), the centre of every shadow lens, every halo, the playhead and the first actions bar, positions rounded
  to 1/8 px and a point behind the eye null; the counts of bodies, rings, shadow lenses, halos, targets, matched
  targets and lit and total actions bars; the 21 palette colours 8-bit sRGB; JSON with sorted keys; SHA-256");
  manifest; compare with the one-quantum fallback and the pinned-digest self-check), generate
  `Packages/ExperiencesRound02/CelestialEclipseLab/golden-frames.json` (schema 1) with
  `CELESTIAL_ECLIPSE_LAB_WRITE_GOLDEN=1`, and add `CelestialEclipseLabGolden` to `RELEASE_FORBIDDEN` in
  `scripts/release_check.py`
- [X] T-R02G1708-004 [P] [US2] Create — Verified 2026-11-25: 2026-11-25 host-2 exit 0, 12 golden tests (.autonomy/migration/checks/R02-G17-08.host-2.json): pinned descriptions and digests match, alterations of position, colour, count, frame set, schema and hand edits are named, writing only with the switch
  `Packages/ExperiencesRound02/CelestialEclipseLab/CoreTests/CelestialEclipseLabRegressionGoldenTests.swift` (agent B:
  every frame's recomputed description matches its pinned one; each pinned digest equals the digest of its pinned
  description; a moved position beyond a quantum, a changed colour or count, a missing frame, an unknown frame, schema
  ≠ 1 and a hand-edited description all fail naming the frame; the file is rewritten only with the switch); `--name
  host-2 -- swift test --package-path Packages/ExperiencesRound02 --filter CelestialEclipseLabRegressionGoldenTests`

## Phase 4: Stories 2 and 3 — simulator frames and memory (P1, P2)

- [X] T-R02G1708-005 [US2] [US3] Create — Verified 2026-11-25: 2026-11-25 sim-27 exit 0, 64 simulator tests incl. 3 golden-frame and 3 memory tests (.autonomy/migration/checks/R02-G17-08.sim-27.json); sim-27-memory alone with TEST_RUNNER_CELESTIAL_ECLIPSE_LAB_MEMORY_ISOLATED=1 exit 0 (.autonomy/migration/checks/R02-G17-08.sim-27-memory.json): 12 cycles from 28.47 MB within 0.5 MB, GPU objects released after each close and warning
  `Packages/ExperiencesRound02/CelestialEclipseLab/ExperienceTests/CelestialEclipseLabRegressionGoldenFrameTests.swift`
  and `Packages/ExperiencesRound02/CelestialEclipseLab/ExperienceTests/CelestialEclipseLabRegressionMemoryTests.swift`
  (agent C: the 16 frames rendered and checked against their descriptions with the feature-463 tolerances (an
  uncovered body's centre 0.25 brighter than the backdrop in luminance, the first lit actions bar with red above blue
  by 0.08, the timeline strip's centre 0.1 from the backdrop, each point at least 6 px from what is drawn after it;
  points on screen where the description puts them); 12 open-draw-warn-close cycles (prepare a level, 3 frames at tier
  0, a memory warning, 1 frame, teardown) with `ProcessMemory.footprint()`, cycles 2 … 12 within 16 MB of cycle 1 when
  `TEST_RUNNER_CELESTIAL_ECLIPSE_LAB_MEMORY_ISOLATED=1`, readings printed otherwise; the sky scene's `liveObjectCount`
  0 after each close and warning and rebuilt by the next frame; an unavailable footprint fails with a named reason);
  `--name sim-27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme
  ExperiencesRound02-Package --destination sim-27.2 --action test --only-testing CelestialEclipseLabExperienceTests`

## Phase 5: Story 4 — the checks run on every change (P2)

- [X] T-R02G1708-006 [P] [US4] Create `scripts/celestial_eclipse_lab_regression.py` and its test in — Verified 2026-11-25: 2026-11-25 regression exit 0 (.autonomy/migration/checks/R02-G17-08.regression.json): host PASS, simulator PASS, one summary; CelestialEclipseLabRegressionTests (5) in scripts/test_scripts.py pass; CI step Celestial Eclipse Lab regression (host) added
  `scripts/test_scripts.py` (agent D: host filter `CelestialEclipseLabRegression`, then the simulator classes through
  `xcodebuild_package.py --only-testing` with the isolation variable, one summary line per part with pass or fail and
  the first failing name, a non-zero exit on any failure), and add the named step "Celestial Eclipse Lab regression
  (host)" to the `round02-host-tests` job of `.github/workflows/ci.yml`; `--name regression -- python3
  scripts/celestial_eclipse_lab_regression.py`

## Phase 6: Regression, documentation and close

- [X] T-R02G1708-007 Docs: `docs/architecture/celestial-eclipse-lab.md` (regression net), — Verified 2026-11-25: 2026-11-25 round02-host-1, -2, -3c, -3e, -3f exit 0 (.autonomy/migration/checks/R02-G17-08.round02-host-*.json); architecture, package README and testing doc updated
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host-1`, `-2`, `-3c`, `-3e`,
  `-3f` (the chunks of T-001)
- [X] T-R02G1708-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`, — Verified 2026-11-25: 2026-11-25 rendering-27, rendering-26, experiences, host-full, app-unit exit 0 (.autonomy/migration/checks/R02-G17-08.*.json)
  `--name host-full`, `--name app-unit`
- [X] T-R02G1708-009 Reference regression chunk 1 (`--name reference-1`) — Verified 2026-11-25: 2026-11-25 reference-1 exit 0 (.autonomy/migration/checks/R02-G17-08.reference-1.json)
- [ ] T-R02G1708-010 Reference regression chunk 2 (`--name reference-2`)
- [X] T-R02G1708-011 Script tests, run alone (`--name script-tests`) — Verified 2026-11-25: 2026-11-25 script-tests exit 0, run alone (.autonomy/migration/checks/R02-G17-08.script-tests.json)
- [ ] T-R02G1708-012 {device} After ImplementationLock-100, on D1, D2 and D3: frame time and memory of the golden
  levels. Not run before the lock.
- [ ] T-R02G1708-013 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record;
  README row and gate list updated

## Dependencies and parallel work

001 → {002 (agent A), 003 (lead) → 004 (agent B), 005 (agent C), 006 (agent D)} → 007 … 011, 013. 012 is a {device}
task outside this campaign. Agent A may start in an isolated copy before 001 (a new test file), but runs no host tests
while the lead's baselines or chain run. Shared files (golden source, release list, workflow, docs) stay with the lead.
MVP: Story 1. Requirement coverage: FR-001/002 → 002; FR-003/004 → 003, 004, 005; FR-005 → 005; FR-006 → 006;
FR-007 → 002 … 006; FR-008 → 007 … 011.
