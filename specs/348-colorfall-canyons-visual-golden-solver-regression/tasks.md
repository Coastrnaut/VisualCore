# Tasks: R02-G05-08 — Colorfall Canyons: visual golden and solver regression

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G05-08 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G05-08 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_348;
tests stay short (< 10 s each); no wall-clock assertion.

## Phase 1: Setup

- [ ] T-R02G0508-001 Baselines: `--name baseline-round02`, `--name baseline-host`, `--name baseline-timing`

## Phase 2: Story 1 — every level stays solvable as certified (P1) 🎯

- [ ] T-R02G0508-002 [P] [US1] Create `Packages/ExperiencesRound02/ColorfallCanyons/CoreTests/ColorfallCanyonsRegressionSolverTests.swift` (agent A: for every
  level in ten groups of 10, "the generated level equals its witness's level; the witness's actions replay to a win at
  exactly its win tick with its per-tick digests and fingerprints; solve returns exactly the witness's edit set with its
  `smaller` count"; twelve named alterations of clarification Q2 each fail naming
  the level and the part); `--name host -- swift test --package-path Packages/ExperiencesRound02 --filter
  ColorfallCanyonsRegressionSolverTests`

## Phase 3: Story 2 — the picture does not drift (P1)

- [ ] T-R02G0508-003 [US2] Create `Packages/ExperiencesRound02/ColorfallCanyons/Core/ColorfallCanyonsGolden.swift` (DEBUG or VISUALCORE_AUTOMATION; "16 frames:
  levels 1, 21, 41, 61, 81 at tiers 0 … 2 at time 0 after the witness's edits and 12 ticks, plus the hero frame; at 1,152 × 768
  with the authored camera: every cell's top centre, every spring emitter top, every basin centre and every wet cell's
  sheet top centre, the night, sandstone, rock, pearl, cyan, coral and yellow colours and each wet cell's fluid mix; positions rounded to 1/8 px; colours 8-bit sRGB; JSON with sorted
  keys; SHA-256"; manifest; compare with the one-quantum fallback and the pinned-digest self-check), generate
  `Packages/ExperiencesRound02/ColorfallCanyons/golden-frames.json` with `COLORFALL_CANYONS_WRITE_GOLDEN=1`, and add `ColorfallCanyonsGolden` to
  `RELEASE_FORBIDDEN` in `scripts/release_check.py`
- [ ] T-R02G0508-004 [P] [US2] Create `Packages/ExperiencesRound02/ColorfallCanyons/CoreTests/ColorfallCanyonsRegressionGoldenTests.swift` (agent B: every frame's
  recomputed description matches its pinned one; each pinned digest equals the digest of its pinned description; a
  moved position beyond a quantum, a changed colour, a missing frame, an unknown frame, schema ≠ 1 and a hand-edited
  description all fail naming the frame; the file is rewritten only with the switch); `--name host-2 -- swift test
  --package-path Packages/ExperiencesRound02 --filter ColorfallCanyonsRegressionGoldenTests`

## Phase 4: Stories 2 and 3 — simulator frames and memory (P1, P2)

- [ ] T-R02G0508-005 [US2] [US3] Edit `Packages/ExperiencesRound02/ColorfallCanyons/Experience/ColorfallCanyonsCanyonScene.swift` (`liveObjectCount`: renderers
  held, 0 after release) and create `Packages/ExperiencesRound02/ColorfallCanyons/ExperienceTests/ColorfallCanyonsRegressionGoldenFrameTests.swift` and
  `Packages/ExperiencesRound02/ColorfallCanyons/ExperienceTests/ColorfallCanyonsRegressionMemoryTests.swift` (agent C: the 16 frames rendered and checked
  against their descriptions with the feature-343 tolerances (flowing emitter tops lit within 3 px by 0.15, dry front-row open cells and 80 % of open cells 0.1 from night, corners within 0.05); 12 open-draw-warn-close cycles with
  `ProcessMemory.footprint()`, cycles 2 … 12 within 16 MB of cycle 1 when
  `TEST_RUNNER_COLORFALL_CANYONS_MEMORY_ISOLATED=1`, readings printed otherwise; live renderers 0 after each close and
  warning; an unavailable footprint fails with a named reason); `--name sim-27 -- python3 scripts/xcodebuild_package.py
  --package Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package --destination sim-27.2 --action test`

## Phase 5: Story 4 — the checks run on every change (P2)

- [ ] T-R02G0508-006 [P] [US4] Create `scripts/colorfall_canyons_regression.py` and its test in `scripts/test_scripts.py`
  (agent D: host filter `ColorfallCanyonsRegression`, then the simulator classes through
  `xcodebuild_package.py --only-testing` with the isolation variable, one summary line per part with pass or fail and
  the first failing name, a non-zero exit on any failure), and add the named step "Colorfall Canyons regression
  (host)" to `.github/workflows/ci.yml`; `--name regression -- python3 scripts/colorfall_canyons_regression.py`

## Phase 6: Regression, documentation and close

- [ ] T-R02G0508-007 Docs: `docs/architecture/colorfall-canyons.md` (regression net),
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host`; `--name audits -- python3
  scripts/verify_experiences.py --audits --only r02-g05.colorfall-canyons`
- [ ] T-R02G0508-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`,
  `--name host-full`, `--name app-unit`
- [ ] T-R02G0508-009 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G0508-010 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G0508-011 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G0508-012 {device} After ImplementationLock-100, on D1, D2 and D3: frame time and memory of the golden levels.
  Not run before the lock.
- [ ] T-R02G0508-013 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record

## Dependencies and parallel work

001 → {002 (agent A), 003 (lead) → 004 (agent B), 005 (lead + agent C), 006 (agent D)} → 007 … 011, 013. 012 is a
{device} task outside this campaign. Shared files (golden source, scene, release list, workflow, docs) stay with the
lead. MVP: Story 1.
