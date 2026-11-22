# Tasks: R02-G06-08 — Chrono Constellator: visual golden and solver regression

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G06-08 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G06-08 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_358;
tests stay short (< 10 s each); no wall-clock assertion.

## Phase 1: Setup

- [X] T-R02G0608-001 Baselines: `--name baseline-round02`, `--name baseline-host`, `--name baseline-timing` — Verified 2026-11-22: baseline-host, baseline-timing, baseline-round02 exit=0 (.autonomy/migration/checks/R02-G06-08.baseline-*.json)

## Phase 2: Story 1 — every level stays solvable as certified (P1) 🎯

- [ ] T-R02G0608-002 [P] [US1] Create `Packages/ExperiencesRound02/ChronoConstellator/CoreTests/ChronoConstellatorRegressionSolverTests.swift` (agent A: for every
  level in ten groups of 10, "the generated level equals its witness's level; the witness's actions replay to a win at
  exactly its win tick with its per-tick digests and fingerprints; solve returns exactly the witness's phase changes,
  lower bound, window, windows and blocked count, with work ≤ tick limit + Σ window ticks"; twelve named alterations of
  clarification Q2 (a star's loop cell, a star's start phase, a star's target, the budget, the tick limit, the grid size;
  a solution phase; a witness action, a per-tick digest, a per-tick fingerprint; the lower bound; the window) each fail
  naming the level and the part); `--name host -- swift test --package-path Packages/ExperiencesRound02 --filter
  ChronoConstellatorRegressionSolverTests`

## Phase 3: Story 2 — the picture does not drift (P1)

- [X] T-R02G0608-003 [US2] Create `Packages/ExperiencesRound02/ChronoConstellator/Core/ChronoConstellatorGolden.swift` (DEBUG or VISUALCORE_AUTOMATION; "16 frames: — Verified 2026-11-22: ChronoConstellatorGolden compiles in the round-two baseline; golden-frames.json written with CHRONO_CONSTELLATOR_WRITE_GOLDEN=1 (16 frames) and reproduced byte for byte; RELEASE_FORBIDDEN lists ChronoConstellatorGolden
  levels 1, 21, 41, 61, 81 at tiers 0 … 2 at time 0 after the witness's phase changes and min(win tick, 6) ticks, plus
  the hero frame at tier 0; at 1,152 × 768 with the authored camera: every star node centre, every target centre and
  every distinct loop cell centre (ascending index), positions rounded to 1/8 px and an off-screen point null; the tick
  and the tick mark's length rounded to 1/1,024 cell; the field, grid, silver, star, rose and amber colours 8-bit sRGB;
  JSON with sorted keys; SHA-256"; manifest; compare with the one-quantum fallback and the pinned-digest self-check),
  generate `Packages/ExperiencesRound02/ChronoConstellator/golden-frames.json` with `CHRONO_CONSTELLATOR_WRITE_GOLDEN=1`,
  and add `ChronoConstellatorGolden` to `RELEASE_FORBIDDEN` in `scripts/release_check.py`
- [X] T-R02G0608-004 [P] [US2] Create `Packages/ExperiencesRound02/ChronoConstellator/CoreTests/ChronoConstellatorRegressionGoldenTests.swift` (agent B: every frame's — Verified 2026-11-22: host-2 exit=0 (9 tests: fixed set, contents, determinism, pinned match, digest self-check, missing/unreadable/renamed/unknown/schema, quantum moves, palette/tick/tier, hand edit)
  recomputed description matches its pinned one; each pinned digest equals the digest of its pinned description; a
  moved position beyond a quantum, a changed colour, a missing frame, an unknown frame, schema ≠ 1 and a hand-edited
  description all fail naming the frame; the file is rewritten only with the switch); `--name host-2 -- swift test
  --package-path Packages/ExperiencesRound02 --filter ChronoConstellatorRegressionGoldenTests`

## Phase 4: Stories 2 and 3 — simulator frames and memory (P1, P2)

- [ ] T-R02G0608-005 [US2] [US3] Edit `Packages/ExperiencesRound02/ChronoConstellator/Experience/ChronoConstellatorSkyScene.swift` (`liveObjectCount`: GPU objects
  held, 0 after release) and create `Packages/ExperiencesRound02/ChronoConstellator/ExperienceTests/ChronoConstellatorRegressionGoldenFrameTests.swift` and
  `Packages/ExperiencesRound02/ChronoConstellator/ExperienceTests/ChronoConstellatorRegressionMemoryTests.swift` (agent C: the 16 frames rendered and checked
  against their descriptions with the feature-353 tolerances (each star centre within 3 px of a pixel at least 0.15
  brighter than the field, each target ring at 0.42·u ± 3 px at least 0.1 from the field, the background within 0.05 of
  the field away from geometry); 12 open-draw-warn-close cycles with `ProcessMemory.footprint()`, cycles 2 … 12 within
  16 MB of cycle 1 when `TEST_RUNNER_CHRONO_CONSTELLATOR_MEMORY_ISOLATED=1`, readings printed otherwise; live GPU
  objects 0 after each close and warning; an unavailable footprint fails with a named reason); `--name sim-27 -- python3
  scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package --destination
  sim-27.2 --action test`

## Phase 5: Story 4 — the checks run on every change (P2)

- [ ] T-R02G0608-006 [P] [US4] Create `scripts/chrono_constellator_regression.py` and its test in `scripts/test_scripts.py`
  (agent D: host filter `ChronoConstellatorRegression`, then the simulator classes through
  `xcodebuild_package.py --only-testing` with the isolation variable, one summary line per part with pass or fail and
  the first failing name, a non-zero exit on any failure), and add the named step "Chrono Constellator regression
  (host)" to `.github/workflows/ci.yml`; `--name regression -- python3 scripts/chrono_constellator_regression.py`

## Phase 6: Regression, documentation and close

- [ ] T-R02G0608-007 Docs: `docs/architecture/chrono-constellator.md` (regression net),
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host`
- [ ] T-R02G0608-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`,
  `--name host-full`, `--name app-unit`
- [ ] T-R02G0608-009 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G0608-010 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G0608-011 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G0608-012 {device} After ImplementationLock-100, on D1, D2 and D3: frame time and memory of the golden levels.
  Not run before the lock.
- [ ] T-R02G0608-013 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record

## Dependencies and parallel work

001 → {002 (agent A), 003 (lead) → 004 (agent B), 005 (lead + agent C), 006 (agent D)} → 007 … 011, 013. 012 is a
{device} task outside this campaign. Shared files (golden source, scene, release list, workflow, docs) stay with the
lead. MVP: Story 1.
