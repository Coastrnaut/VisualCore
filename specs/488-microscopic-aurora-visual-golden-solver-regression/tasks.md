# Tasks: R02-G19-08 — Microscopic Aurora: visual golden and solver regression

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/](contracts/), [quickstart.md](quickstart.md). Gate R02-G19-08 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G19-08 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_488;
tests stay short (< 10 s each); no wall-clock assertion. No agent runs host tests while a baseline or chain runs.

## Phase 1: Setup

- [X] T-R02G1908-001 Baselines on the committed tree after R02-G19-07 is recorded: `--name baseline-host`, `--name — Verified 2026-11-26: 2026-11-26 baseline-host, baseline-timing, baseline-round02-1, -2, -3c, -3e, -3f exit 0 on the committed tree (.autonomy/migration/checks/R02-G19-08.baseline-*.json)
  baseline-timing`, `--name baseline-round02-1`, `-2`, `-3c`, `-3e`, `-3f` (the five round-two filters, chunk 3f with
  `MicroscopicAurora`)

## Phase 2: Story 1 — every level stays solvable as certified (P1) 🎯

- [ ] T-R02G1908-002 [P] [US1] Create
  `Packages/ExperiencesRound02/MicroscopicAurora/CoreTests/MicroscopicAuroraRegressionSolverTests.swift` (agent A: for
  every level in ten groups of 10, "the generated level equals its witness's level (fingerprint); the witness's actions
  replay on a fresh play to a win on exactly the final play and not before, within the budget, with its per-action
  fingerprints (after begin, after the tutorial on a tutorial level, then one per action) and digests; plan returns
  exactly the witness's placements with setsByDepth[size − 1] equal to the counterexample's sets and nearestMiss equal
  to its nearestMiss, with work ≤ workBound"; twelve named alterations of clarification Q2 (a swimmer's position, a
  swimmer's velocity, a stencil cell, a site, the threshold, the coverage requirement, the coherence requirement, the
  budget; a plan placement; a witness action, a per-action fingerprint or digest; the counterexample's sets count) each
  fail naming the level and the part); `--name host -- swift test --package-path Packages/ExperiencesRound02 --filter
  MicroscopicAuroraRegressionSolverTests`

## Phase 3: Story 2 — the picture does not drift (P1)

- [ ] T-R02G1908-003 [US2] Create `Packages/ExperiencesRound02/MicroscopicAurora/Core/MicroscopicAuroraGolden.swift`
  (DEBUG or VISUALCORE_AUTOMATION; "16 frames: levels 1, 21, 41, 61, 81 at tiers 0 … 2 at presentation time 0 after all
  of the witness's placements but not the play, with no preview and no freeze, shown at the tick half the ticks swum,
  plus the hero frame of `scenario-manifest.json` at tier 0; at 1,152 × 768 with the authored camera: the dish centre,
  every swimmer at the shown tick (index order), every placed well (slot order), every site (index order) and the first
  actions bar, positions rounded to 1/8 px and a point behind the eye null; the counts of stencil cells, lit and stray
  cells, sites, wells, swimmers, ribbon points, gauges, met gauges and lit and total actions bars; the 18 palette
  colours 8-bit sRGB; JSON with sorted keys; SHA-256"); manifest; compare with the one-quantum fallback and the
  pinned-digest self-check), generate `Packages/ExperiencesRound02/MicroscopicAurora/golden-frames.json` (schema 1) with
  `MICROSCOPIC_AURORA_WRITE_GOLDEN=1`, and add `MicroscopicAuroraGolden` to `RELEASE_FORBIDDEN` in
  `scripts/release_check.py`
- [ ] T-R02G1908-004 [P] [US2] Create
  `Packages/ExperiencesRound02/MicroscopicAurora/CoreTests/MicroscopicAuroraRegressionGoldenTests.swift` (agent B: every
  frame's recomputed description matches its pinned one; each pinned digest equals the digest of its pinned description;
  a moved position beyond a quantum, a changed colour or count, a missing frame, an unknown frame, schema ≠ 1 and a
  hand-edited description all fail naming the frame; the file is rewritten only with the switch); `--name host-2 --
  swift test --package-path Packages/ExperiencesRound02 --filter MicroscopicAuroraRegressionGoldenTests`

## Phase 4: Stories 2 and 3 — simulator frames and memory (P1, P2)

- [ ] T-R02G1908-005 [US2] [US3] Create
  `Packages/ExperiencesRound02/MicroscopicAurora/ExperienceTests/MicroscopicAuroraRegressionGoldenFrameTests.swift` and
  `Packages/ExperiencesRound02/MicroscopicAurora/ExperienceTests/MicroscopicAuroraRegressionMemoryTests.swift` (agent C:
  the 16 frames rendered and checked against their descriptions with the feature-483 tolerances (each swimmer's centre
  0.25 brighter than the dish field in luminance, the first lit actions bar with blue above green by 0.08, each point at
  least 6 px from what is drawn after it, backdrop patches within the feature-483 tolerance of the abyss gradient;
  points on screen where the description puts them); 12 open-draw-warn-close cycles (prepare a level, 3 frames at tier
  0, a memory warning, 1 frame, teardown) with `ProcessMemory.footprint()`, cycles 2 … 12 within 16 MB of cycle 1 when
  `TEST_RUNNER_MICROSCOPIC_AURORA_MEMORY_ISOLATED=1`, readings printed otherwise; the dish scene's `liveObjectCount` 0
  after each close and warning and rebuilt by the next frame; an unavailable footprint fails with a named reason);
  `--name sim-27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme
  ExperiencesRound02-Package --destination sim-27.2 --action test --only-testing MicroscopicAuroraExperienceTests`

## Phase 5: Story 4 — the checks run on every change (P2)

- [ ] T-R02G1908-006 [P] [US4] Create `scripts/microscopic_aurora_regression.py` and its test in
  `scripts/test_scripts.py` (agent D: host filter `MicroscopicAuroraRegression`, then the simulator classes through
  `xcodebuild_package.py --only-testing` with the isolation variable, one summary line per part with pass or fail and
  the first failing name, a non-zero exit on any failure), and add the named step "Microscopic Aurora regression (host)"
  to the `round02-host-tests` job of `.github/workflows/ci.yml`; `--name regression -- python3
  scripts/microscopic_aurora_regression.py`

## Phase 6: Regression, documentation and close

- [ ] T-R02G1908-007 Docs: `docs/architecture/microscopic-aurora.md` (regression net),
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host-1`, `-2`, `-3c`, `-3e`,
  `-3f` (the chunks of T-001)
- [ ] T-R02G1908-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`, `--name
  host-full`, `--name app-unit`
- [ ] T-R02G1908-009 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G1908-010 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G1908-011 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G1908-012 {device} After ImplementationLock-100, on D1, D2 and D3: frame time and memory of the golden
  levels. Not run before the lock.
- [ ] T-R02G1908-013 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record;
  README row and gate list updated

## Dependencies and parallel work

001 → {002 (agent A), 003 (lead) → 004 (agent B), 005 (agent C), 006 (agent D)} → 007 … 011, 013. 012 is a {device}
task outside this campaign. Agent A may start in an isolated copy before 001 (a new test file), but runs no host tests
while the lead's baselines or chain run. Shared files (golden source, release list, workflow, docs) stay with the lead.
MVP: Story 1. Requirement coverage: FR-001/002 → 002; FR-003/004 → 003, 004, 005; FR-005 → 005; FR-006 → 006;
FR-007 → 002 … 006; FR-008 → 007 … 011.
