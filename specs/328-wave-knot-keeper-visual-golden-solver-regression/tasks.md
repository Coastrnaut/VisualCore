# Tasks: R02-G03-08 — Wave Knot Keeper: visual golden and solver regression

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G03-08 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G03-08 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_328;
tests stay short (< 10 s each); no wall-clock assertion.

## Phase 1: Setup

- [X] T-R02G0308-001 Baselines: `--name baseline-round02`, `--name baseline-host`, `--name baseline-timing` — Verified 2026-11-21: 2026-11-21 baseline-round02, baseline-host, baseline-timing exit 0

## Phase 2: Story 1 — every level stays solvable as certified (P1) 🎯

- [X] T-R02G0308-002 [P] [US1] Create `Packages/ExperiencesRound02/WaveKnotKeeper/CoreTests/WaveKnotKeeperRegressionSolverTests.swift` (agent A: for every — Verified 2026-11-21: 2026-11-21 host exit 0: WaveKnotKeeperRegressionSolverTests 9/9 (five bands: generated level equals its witness, witness replays to a win with its fingerprints, solve gives the certified shortest with work <= 3,661 and equal to the certified work (largest 728); thirteen alterations of levels 44 and 87 each named)
  level in five bands of 20, "the generated level equals its witness's level; the witness replays to a win in exactly
  its recorded moves with its recorded fingerprints; solve returns exactly the certified shortest whose moves win,
  work ≤ 3,661 and equal to the certified work"; thirteen named alterations of clarification Q2 each fail naming
  the level and the part); `--name host -- swift test --package-path Packages/ExperiencesRound02 --filter
  WaveKnotKeeperRegressionSolverTests`

## Phase 3: Story 2 — the picture does not drift (P1)

- [X] T-R02G0308-003 [US2] Create `Packages/ExperiencesRound02/WaveKnotKeeper/Core/WaveKnotKeeperGolden.swift` (DEBUG or VISUALCORE_AUTOMATION; "16 frames: — Verified 2026-11-21: 2026-11-21 WaveKnotKeeperGolden builds (DEBUG or automation only); golden-frames.json generated with WAVE_KNOT_KEEPER_WRITE_GOLDEN=1 (schema 1, 16 frames, 13,790 bytes); WaveKnotKeeperGolden added to RELEASE_FORBIDDEN; proven by host-2
  levels 1, 21, 41, 61, 81 at tiers 0 … 2 at time 0, plus the hero frame; at 1,152 × 768 with the authored camera:
  every control point, every segment midpoint, every handle centre, every gate centre and every drawn crossing point,
  the night, pearl, sapphire and ember colours; positions rounded to 1/8 px; colours 8-bit sRGB; JSON with sorted
  keys; SHA-256"; manifest; compare with the one-quantum fallback and the pinned-digest self-check), generate
  `Packages/ExperiencesRound02/WaveKnotKeeper/golden-frames.json` with `WAVE_KNOT_KEEPER_WRITE_GOLDEN=1`, and add `WaveKnotKeeperGolden` to
  `RELEASE_FORBIDDEN` in `scripts/release_check.py`
- [X] T-R02G0308-004 [P] [US2] Create `Packages/ExperiencesRound02/WaveKnotKeeper/CoreTests/WaveKnotKeeperRegressionGoldenTests.swift` (agent B: every frame's — Verified 2026-11-21: 2026-11-21 host-2 exit 0: WaveKnotKeeperRegressionGoldenTests 7/7 (fixed set; deterministic; every frame matches the pinned file; pinned digests self-check; missing, unreadable, schema-2 and unknown frames named; 2-quantum move, colour and tier detail fail, one quantum passes; hand-edited description refused)
  recomputed description matches its pinned one; each pinned digest equals the digest of its pinned description; a
  moved position beyond a quantum, a changed colour, a missing frame, an unknown frame, schema ≠ 1 and a hand-edited
  description all fail naming the frame; the file is rewritten only with the switch); `--name host-2 -- swift test
  --package-path Packages/ExperiencesRound02 --filter WaveKnotKeeperRegressionGoldenTests`

## Phase 4: Stories 2 and 3 — simulator frames and memory (P1, P2)

- [X] T-R02G0308-005 [US2] [US3] Edit `Packages/ExperiencesRound02/WaveKnotKeeper/Experience/WaveKnotKeeperRopeScene.swift` (`liveObjectCount`: renderers — Verified 2026-11-21: 2026-11-21 sim-27 exit 0 on sim-27.2: WaveKnotKeeperRegressionGoldenFrameTests (16 golden frames rendered: drawn snapshot equals the golden one, described positions agree with the CPU reference, feature-323 tolerances) and WaveKnotKeeperRegressionMemoryTests (12 cycles 29.7 ... 30.4 MB; no renderers after each warning and close, rebuilt on the next frame); all Wave Knot Keeper experience tests
  held, 0 after release) and create `Packages/ExperiencesRound02/WaveKnotKeeper/ExperienceTests/WaveKnotKeeperRegressionGoldenFrameTests.swift` and
  `Packages/ExperiencesRound02/WaveKnotKeeper/ExperienceTests/WaveKnotKeeperRegressionMemoryTests.swift` (agent C: the 16 frames rendered and checked
  against their descriptions with the feature-323 tolerances (3 px, 0.15, sapphire tint, 0.05); 12 open-draw-warn-close cycles with
  `ProcessMemory.footprint()`, cycles 2 … 12 within 16 MB of cycle 1 when
  `TEST_RUNNER_WAVE_KNOT_KEEPER_MEMORY_ISOLATED=1`, readings printed otherwise; live renderers 0 after each close and
  warning; an unavailable footprint fails with a named reason); `--name sim-27 -- python3 scripts/xcodebuild_package.py
  --package Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package --destination sim-27.2 --action test`

## Phase 5: Story 4 — the checks run on every change (P2)

- [X] T-R02G0308-006 [P] [US4] Create `scripts/wave_knot_keeper_regression.py` and its test in `scripts/test_scripts.py` — Verified 2026-11-21: 2026-11-21 regression exit 0: python3 scripts/wave_knot_keeper_regression.py (host, then the simulator golden-frame and isolated memory classes) PASS; WaveKnotKeeperRegressionTests in test_scripts (5 tests); CI step Wave Knot Keeper regression (host)
  (agent D: host filter `WaveKnotKeeperRegression`, then the simulator classes through
  `xcodebuild_package.py --only-testing` with the isolation variable, one summary line per part with pass or fail and
  the first failing name, a non-zero exit on any failure), and add the named step "Wave Knot Keeper regression
  (host)" to `.github/workflows/ci.yml`; `--name regression -- python3 scripts/wave_knot_keeper_regression.py`

## Phase 6: Regression, documentation and close

- [X] T-R02G0308-007 Docs: `docs/architecture/wave-knot-keeper.md` (regression net), — Verified 2026-11-21: 2026-11-21 round02-host exit 0; audits exit 0; architecture regression net, package README (regeneration command), testing doc
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host`; `--name audits -- python3
  scripts/verify_experiences.py --audits --only r02-g03.wave-knot-keeper`
- [X] T-R02G0308-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`, — Verified 2026-11-21: 2026-11-21 rendering-27, rendering-26, experiences, host-full, app-unit exit 0
  `--name host-full`, `--name app-unit`
- [X] T-R02G0308-009 Reference regression chunk 1 (`--name reference-1`) — Verified 2026-11-21: 2026-11-21 reference-1 exit 0
- [X] T-R02G0308-010 Reference regression chunk 2 (`--name reference-2`) — Verified 2026-11-21: 2026-11-21 reference-2 exit 0: 7 of 7 with chunk 1
- [X] T-R02G0308-011 Script tests, run alone (`--name script-tests`) — Verified 2026-11-21: 2026-11-21 script-tests exit 0, run alone
- [ ] T-R02G0308-012 {device} After ImplementationLock-100, on D1, D2 and D3: frame time and memory of the golden levels.
  Not run before the lock.
- [X] T-R02G0308-013 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record — Verified 2026-11-21: 2026-11-21 converge round 1 converged (nothing appended); sealed 17 passing; recorded R02-G03-08 pass; T-R02G0308-012 {device} stays open

## Dependencies and parallel work

001 → {002 (agent A), 003 (lead) → 004 (agent B), 005 (lead + agent C), 006 (agent D)} → 007 … 011, 013. 012 is a
{device} task outside this campaign. Shared files (golden source, scene, release list, workflow, docs) stay with the
lead. MVP: Story 1.
