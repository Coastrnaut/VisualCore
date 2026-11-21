# Tasks: R02-G03-08 — Wave Knot Keeper: visual golden and solver regression

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G03-08 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G03-08 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_328;
tests stay short (< 10 s each); no wall-clock assertion.

## Phase 1: Setup

- [X] T-R02G0308-001 Baselines: `--name baseline-round02`, `--name baseline-host`, `--name baseline-timing` — Verified 2026-11-21: 2026-11-21 baseline-round02, baseline-host, baseline-timing exit 0

## Phase 2: Story 1 — every level stays solvable as certified (P1) 🎯

- [ ] T-R02G0308-002 [P] [US1] Create `Packages/ExperiencesRound02/WaveKnotKeeper/CoreTests/WaveKnotKeeperRegressionSolverTests.swift` (agent A: for every
  level in five bands of 20, "the generated level equals its witness's level; the witness replays to a win in exactly
  its recorded moves with its recorded fingerprints; solve returns exactly the certified shortest whose moves win,
  work ≤ 3,661 and equal to the certified work"; thirteen named alterations of clarification Q2 each fail naming
  the level and the part); `--name host -- swift test --package-path Packages/ExperiencesRound02 --filter
  WaveKnotKeeperRegressionSolverTests`

## Phase 3: Story 2 — the picture does not drift (P1)

- [ ] T-R02G0308-003 [US2] Create `Packages/ExperiencesRound02/WaveKnotKeeper/Core/WaveKnotKeeperGolden.swift` (DEBUG or VISUALCORE_AUTOMATION; "16 frames:
  levels 1, 21, 41, 61, 81 at tiers 0 … 2 at time 0, plus the hero frame; at 1,152 × 768 with the authored camera:
  every control point, every segment midpoint, every handle centre, every gate centre and every drawn crossing point,
  the night, pearl, sapphire and ember colours; positions rounded to 1/8 px; colours 8-bit sRGB; JSON with sorted
  keys; SHA-256"; manifest; compare with the one-quantum fallback and the pinned-digest self-check), generate
  `Packages/ExperiencesRound02/WaveKnotKeeper/golden-frames.json` with `WAVE_KNOT_KEEPER_WRITE_GOLDEN=1`, and add `WaveKnotKeeperGolden` to
  `RELEASE_FORBIDDEN` in `scripts/release_check.py`
- [ ] T-R02G0308-004 [P] [US2] Create `Packages/ExperiencesRound02/WaveKnotKeeper/CoreTests/WaveKnotKeeperRegressionGoldenTests.swift` (agent B: every frame's
  recomputed description matches its pinned one; each pinned digest equals the digest of its pinned description; a
  moved position beyond a quantum, a changed colour, a missing frame, an unknown frame, schema ≠ 1 and a hand-edited
  description all fail naming the frame; the file is rewritten only with the switch); `--name host-2 -- swift test
  --package-path Packages/ExperiencesRound02 --filter WaveKnotKeeperRegressionGoldenTests`

## Phase 4: Stories 2 and 3 — simulator frames and memory (P1, P2)

- [ ] T-R02G0308-005 [US2] [US3] Edit `Packages/ExperiencesRound02/WaveKnotKeeper/Experience/WaveKnotKeeperRopeScene.swift` (`liveObjectCount`: renderers
  held, 0 after release) and create `Packages/ExperiencesRound02/WaveKnotKeeper/ExperienceTests/WaveKnotKeeperRegressionGoldenFrameTests.swift` and
  `Packages/ExperiencesRound02/WaveKnotKeeper/ExperienceTests/WaveKnotKeeperRegressionMemoryTests.swift` (agent C: the 16 frames rendered and checked
  against their descriptions with the feature-323 tolerances (3 px, 0.15, sapphire tint, 0.05); 12 open-draw-warn-close cycles with
  `ProcessMemory.footprint()`, cycles 2 … 12 within 16 MB of cycle 1 when
  `TEST_RUNNER_WAVE_KNOT_KEEPER_MEMORY_ISOLATED=1`, readings printed otherwise; live renderers 0 after each close and
  warning; an unavailable footprint fails with a named reason); `--name sim-27 -- python3 scripts/xcodebuild_package.py
  --package Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package --destination sim-27.2 --action test`

## Phase 5: Story 4 — the checks run on every change (P2)

- [ ] T-R02G0308-006 [P] [US4] Create `scripts/wave_knot_keeper_regression.py` and its test in `scripts/test_scripts.py`
  (agent D: host filter `WaveKnotKeeperRegression`, then the simulator classes through
  `xcodebuild_package.py --only-testing` with the isolation variable, one summary line per part with pass or fail and
  the first failing name, a non-zero exit on any failure), and add the named step "Wave Knot Keeper regression
  (host)" to `.github/workflows/ci.yml`; `--name regression -- python3 scripts/wave_knot_keeper_regression.py`

## Phase 6: Regression, documentation and close

- [ ] T-R02G0308-007 Docs: `docs/architecture/wave-knot-keeper.md` (regression net),
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host`; `--name audits -- python3
  scripts/verify_experiences.py --audits --only r02-g03.wave-knot-keeper`
- [ ] T-R02G0308-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`,
  `--name host-full`, `--name app-unit`
- [ ] T-R02G0308-009 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G0308-010 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G0308-011 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G0308-012 {device} After ImplementationLock-100, on D1, D2 and D3: frame time and memory of the golden levels.
  Not run before the lock.
- [ ] T-R02G0308-013 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record

## Dependencies and parallel work

001 → {002 (agent A), 003 (lead) → 004 (agent B), 005 (lead + agent C), 006 (agent D)} → 007 … 011, 013. 012 is a
{device} task outside this campaign. Shared files (golden source, scene, release list, workflow, docs) stay with the
lead. MVP: Story 1.
