# Tasks: R02-G05-08 — Colorfall Canyons: visual golden and solver regression

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G05-08 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G05-08 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_348;
tests stay short (< 10 s each); no wall-clock assertion.

## Phase 1: Setup

- [X] T-R02G0508-001 Baselines: `--name baseline-round02`, `--name baseline-host`, `--name baseline-timing` — Verified 2026-11-21: 2026-11-21 baseline-host, baseline-timing, baseline-round02 exit 0 (.autonomy/migration/checks/R02-G05-08.baseline-*.json)

## Phase 2: Story 1 — every level stays solvable as certified (P1) 🎯

- [X] T-R02G0508-002 [P] [US1] Create `Packages/ExperiencesRound02/ColorfallCanyons/CoreTests/ColorfallCanyonsRegressionSolverTests.swift` (agent A: for every — Verified 2026-11-21: 2026-11-21 host exit 0: 24 solver regression tests (100 levels in 20 groups of 5: witness level, replay with per-tick digests and fingerprints, exact certified edit set, smaller, work and win tick at the generator's depth; 12 alterations named) (.autonomy/migration/checks/R02-G05-08.host.json); lead retest
  level in ten groups of 10, "the generated level equals its witness's level; the witness's actions replay to a win at
  exactly its win tick with its per-tick digests and fingerprints; solve returns exactly the witness's edit set with its
  `smaller` count"; twelve named alterations of clarification Q2 each fail naming
  the level and the part); `--name host -- swift test --package-path Packages/ExperiencesRound02 --filter
  ColorfallCanyonsRegressionSolverTests`

## Phase 3: Story 2 — the picture does not drift (P1)

- [X] T-R02G0508-003 [US2] Create `Packages/ExperiencesRound02/ColorfallCanyons/Core/ColorfallCanyonsGolden.swift` (DEBUG or VISUALCORE_AUTOMATION; "16 frames: — Verified 2026-11-21: 2026-11-21 ColorfallCanyonsGolden (16 frames: levels 1/21/41/61/81 x tiers 0-2 after certified edits and 12 ticks, plus hero; positions to 1/8 px, 8-bit colours, SHA-256) and golden-frames.json generated with COLORFALL_CANYONS_WRITE_GOLDEN=1; ColorfallCanyonsGolden added to RELEASE_FORBIDDEN; host-2 exit 0 (.autonomy/migration/checks/R02-G05-08.host-2.json)
  levels 1, 21, 41, 61, 81 at tiers 0 … 2 at time 0 after the witness's edits and 12 ticks, plus the hero frame; at 1,152 × 768
  with the authored camera: every cell's top centre, every spring emitter top, every basin centre and every wet cell's
  sheet top centre, the night, sandstone, rock, pearl, cyan, coral and yellow colours and each wet cell's fluid mix; positions rounded to 1/8 px; colours 8-bit sRGB; JSON with sorted
  keys; SHA-256"; manifest; compare with the one-quantum fallback and the pinned-digest self-check), generate
  `Packages/ExperiencesRound02/ColorfallCanyons/golden-frames.json` with `COLORFALL_CANYONS_WRITE_GOLDEN=1`, and add `ColorfallCanyonsGolden` to
  `RELEASE_FORBIDDEN` in `scripts/release_check.py`
- [X] T-R02G0508-004 [P] [US2] Create `Packages/ExperiencesRound02/ColorfallCanyons/CoreTests/ColorfallCanyonsRegressionGoldenTests.swift` (agent B: every frame's — Verified 2026-11-21: 2026-11-21 host-2 exit 0: 8 golden tests (recomputed descriptions match pinned; digests self-check; moved positions beyond a quantum, changed colours, missing/unknown frame, schema 2, hand-edited description all fail naming the frame; rewrite only with the switch) (.autonomy/migration/checks/R02-G05-08.host-2.json); lead retest
  recomputed description matches its pinned one; each pinned digest equals the digest of its pinned description; a
  moved position beyond a quantum, a changed colour, a missing frame, an unknown frame, schema ≠ 1 and a hand-edited
  description all fail naming the frame; the file is rewritten only with the switch); `--name host-2 -- swift test
  --package-path Packages/ExperiencesRound02 --filter ColorfallCanyonsRegressionGoldenTests`

## Phase 4: Stories 2 and 3 — simulator frames and memory (P1, P2)

- [X] T-R02G0508-005 [US2] [US3] Edit `Packages/ExperiencesRound02/ColorfallCanyons/Experience/ColorfallCanyonsCanyonScene.swift` (`liveObjectCount`: renderers — Verified 2026-11-21: 2026-11-21 sim-27 exit 0: ColorfallCanyonsExperienceTests 53 tests in 10 suites on sim-27.2 incl. golden-frame tests (16 frames rendered, snapshots equal the golden snapshots, positions within a quantum, feature-343 frame checks) and memory tests (12 cycles, live renderers 0 after close and warning) (.autonomy/migration/checks/R02-G05-08.sim-27.json); liveObjectCount added to the scene; lead run
  held, 0 after release) and create `Packages/ExperiencesRound02/ColorfallCanyons/ExperienceTests/ColorfallCanyonsRegressionGoldenFrameTests.swift` and
  `Packages/ExperiencesRound02/ColorfallCanyons/ExperienceTests/ColorfallCanyonsRegressionMemoryTests.swift` (agent C: the 16 frames rendered and checked
  against their descriptions with the feature-343 tolerances (flowing emitter tops lit within 3 px by 0.15, dry front-row open cells and 80 % of open cells 0.1 from night, corners within 0.05); 12 open-draw-warn-close cycles with
  `ProcessMemory.footprint()`, cycles 2 … 12 within 16 MB of cycle 1 when
  `TEST_RUNNER_COLORFALL_CANYONS_MEMORY_ISOLATED=1`, readings printed otherwise; live renderers 0 after each close and
  warning; an unavailable footprint fails with a named reason); `--name sim-27 -- python3 scripts/xcodebuild_package.py
  --package Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package --destination sim-27.2 --action test`

## Phase 5: Story 4 — the checks run on every change (P2)

- [X] T-R02G0508-006 [P] [US4] Create `scripts/colorfall_canyons_regression.py` and its test in `scripts/test_scripts.py` — Verified 2026-11-21: 2026-11-21 regression exit 0: scripts/colorfall_canyons_regression.py host PASS and simulator (golden frames, memory isolated) PASS (.autonomy/migration/checks/R02-G05-08.regression.json); 5 script tests; CI step 'Colorfall Canyons regression (host)' added
  (agent D: host filter `ColorfallCanyonsRegression`, then the simulator classes through
  `xcodebuild_package.py --only-testing` with the isolation variable, one summary line per part with pass or fail and
  the first failing name, a non-zero exit on any failure), and add the named step "Colorfall Canyons regression
  (host)" to `.github/workflows/ci.yml`; `--name regression -- python3 scripts/colorfall_canyons_regression.py`

## Phase 6: Regression, documentation and close

- [X] T-R02G0508-007 Docs: `docs/architecture/colorfall-canyons.md` (regression net), — Verified 2026-11-21: 2026-11-21 docs updated (architecture regression net, package README, testing doc); round02-host exit 0; audits exit 0 (verify_experiences --audits --only r02-g05.colorfall-canyons) (.autonomy/migration/checks/R02-G05-08.round02-host.json, .autonomy/migration/checks/R02-G05-08.audits.json)
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host`; `--name audits -- python3
  scripts/verify_experiences.py --audits --only r02-g05.colorfall-canyons`
- [X] T-R02G0508-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`, — Verified 2026-11-21: 2026-11-21 rendering-27, rendering-26, experiences, host-full, app-unit exit 0 (.autonomy/migration/checks/R02-G05-08.*.json)
  `--name host-full`, `--name app-unit`
- [X] T-R02G0508-009 Reference regression chunk 1 (`--name reference-1`) — Verified 2026-11-21: 2026-11-21 reference-1 exit 0 (.autonomy/migration/checks/R02-G05-08.reference-1.json)
- [X] T-R02G0508-010 Reference regression chunk 2 (`--name reference-2`) — Verified 2026-11-21: 2026-11-21 reference-2 exit 0 (.autonomy/migration/checks/R02-G05-08.reference-2.json)
- [ ] T-R02G0508-011 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G0508-012 {device} After ImplementationLock-100, on D1, D2 and D3: frame time and memory of the golden levels.
  Not run before the lock.
- [ ] T-R02G0508-013 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record

## Dependencies and parallel work

001 → {002 (agent A), 003 (lead) → 004 (agent B), 005 (lead + agent C), 006 (agent D)} → 007 … 011, 013. 012 is a
{device} task outside this campaign. Shared files (golden source, scene, release list, workflow, docs) stay with the
lead. MVP: Story 1.
