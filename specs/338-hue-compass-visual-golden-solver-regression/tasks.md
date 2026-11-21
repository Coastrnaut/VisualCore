# Tasks: R02-G04-08 — Hue Compass: visual golden and solver regression

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G04-08 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G04-08 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_338;
tests stay short (< 10 s each); no wall-clock assertion.

## Phase 1: Setup

- [X] T-R02G0408-001 Baselines: `--name baseline-round02`, `--name baseline-host`, `--name baseline-timing` — Verified 2026-11-21: 2026-11-21 baseline-round02, baseline-host, baseline-timing exit 0

## Phase 2: Story 1 — every level stays solvable as certified (P1) 🎯

- [X] T-R02G0408-002 [P] [US1] Create `Packages/ExperiencesRound02/HueCompass/CoreTests/HueCompassRegressionSolverTests.swift` (agent A: for every — Verified 2026-11-21: 2026-11-21 host exit 0: HueCompassRegressionSolverTests 9/9 (100 levels in five bands: witness replay with clues and fingerprints, smallest probe set that settles, work <= 4,657 and equal to certified, largest 3,533; fourteen alterations named)
  level in five bands of 20, "the generated level equals its witness's level; the witness's actions replay to a win with
  exactly its recorded clues and fingerprints; solve returns exactly the certified smallest probe set, which settles
  the level, work ≤ 4,657 and equal to the certified work"; fourteen named alterations of clarification Q2 each fail naming
  the level and the part); `--name host -- swift test --package-path Packages/ExperiencesRound02 --filter
  HueCompassRegressionSolverTests`

## Phase 3: Story 2 — the picture does not drift (P1)

- [X] T-R02G0408-003 [US2] Create `Packages/ExperiencesRound02/HueCompass/Core/HueCompassGolden.swift` (DEBUG or VISUALCORE_AUTOMATION; "16 frames: — Verified 2026-11-21: 2026-11-21 HueCompassGolden (16 code-computed frames), golden-frames.json generated with HUE_COMPASS_WRITE_GOLDEN=1 (37,890 bytes, 16 digests), HueCompassGolden in RELEASE_FORBIDDEN; proven by host-2 exit 0
  levels 1, 21, 41, 61, 81 at tiers 0 … 2 at time 0 after the witness probes, plus the hero frame; at 1,152 × 768 with the
  authored camera: the needle tip, every band segment's colour sample point with its band colour, every probe mark
  centre, the selection mark and target ring when present, the night, pearl, ember and sapphire colours; positions rounded to 1/8 px; colours 8-bit sRGB; JSON with sorted
  keys; SHA-256"; manifest; compare with the one-quantum fallback and the pinned-digest self-check), generate
  `Packages/ExperiencesRound02/HueCompass/golden-frames.json` with `HUE_COMPASS_WRITE_GOLDEN=1`, and add `HueCompassGolden` to
  `RELEASE_FORBIDDEN` in `scripts/release_check.py`
- [X] T-R02G0408-004 [P] [US2] Create `Packages/ExperiencesRound02/HueCompass/CoreTests/HueCompassRegressionGoldenTests.swift` (agent B: every frame's — Verified 2026-11-21: 2026-11-21 host-2 exit 0: HueCompassRegressionGoldenTests 8/8 (every frame matches its pinned entry; pinned digests self-check; moved, recoloured, missing, unknown, wrong-schema, unreadable and hand-edited entries named; one-quantum move accepted; file rewritten only with the switch)
  recomputed description matches its pinned one; each pinned digest equals the digest of its pinned description; a
  moved position beyond a quantum, a changed colour, a missing frame, an unknown frame, schema ≠ 1 and a hand-edited
  description all fail naming the frame; the file is rewritten only with the switch); `--name host-2 -- swift test
  --package-path Packages/ExperiencesRound02 --filter HueCompassRegressionGoldenTests`

## Phase 4: Stories 2 and 3 — simulator frames and memory (P1, P2)

- [X] T-R02G0408-005 [US2] [US3] Edit `Packages/ExperiencesRound02/HueCompass/Experience/HueCompassCompassScene.swift` (`liveObjectCount`: renderers — Verified 2026-11-21: 2026-11-21 sim-27 exit 0 on sim-27.2: HueCompassRegressionGoldenFrameTests (16 golden frames rendered, snapshots equal to the golden ones, feature-333 frame checks) and HueCompassRegressionMemoryTests (12 cycles; liveObjectCount 0 after each warning and close) with every Hue Compass experience test
  held, 0 after release) and create `Packages/ExperiencesRound02/HueCompass/ExperienceTests/HueCompassRegressionGoldenFrameTests.swift` and
  `Packages/ExperiencesRound02/HueCompass/ExperienceTests/HueCompassRegressionMemoryTests.swift` (agent C: the 16 frames rendered and checked
  against their descriptions with the feature-333 tolerances (3 px lit by 0.15, band colours within 0.15, background within 0.05); 12 open-draw-warn-close cycles with
  `ProcessMemory.footprint()`, cycles 2 … 12 within 16 MB of cycle 1 when
  `TEST_RUNNER_HUE_COMPASS_MEMORY_ISOLATED=1`, readings printed otherwise; live renderers 0 after each close and
  warning; an unavailable footprint fails with a named reason); `--name sim-27 -- python3 scripts/xcodebuild_package.py
  --package Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package --destination sim-27.2 --action test`

## Phase 5: Story 4 — the checks run on every change (P2)

- [X] T-R02G0408-006 [P] [US4] Create `scripts/hue_compass_regression.py` and its test in `scripts/test_scripts.py` — Verified 2026-11-21: 2026-11-21 regression exit 0: scripts/hue_compass_regression.py ran the host filter (17 tests) and the isolated simulator classes (5 tests; footprint 28.75 ... 29.14 MB over 12 cycles), one summary per part; HueCompassRegressionTests 5/5 in scripts/test_scripts.py; CI step 'Hue Compass regression (host)'
  (agent D: host filter `HueCompassRegression`, then the simulator classes through
  `xcodebuild_package.py --only-testing` with the isolation variable, one summary line per part with pass or fail and
  the first failing name, a non-zero exit on any failure), and add the named step "Hue Compass regression
  (host)" to `.github/workflows/ci.yml`; `--name regression -- python3 scripts/hue_compass_regression.py`

## Phase 6: Regression, documentation and close

- [X] T-R02G0408-007 Docs: `docs/architecture/hue-compass.md` (regression net), — Verified 2026-11-21: 2026-11-21 round02-host exit 0; audits exit 0 (verify_experiences --audits --only r02-g04.hue-compass); architecture (regression net), package README and testing doc updated
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host`; `--name audits -- python3
  scripts/verify_experiences.py --audits --only r02-g04.hue-compass`
- [X] T-R02G0408-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`, — Verified 2026-11-21: 2026-11-21 rendering-27, rendering-26, experiences, host-full, app-unit exit 0
  `--name host-full`, `--name app-unit`
- [X] T-R02G0408-009 Reference regression chunk 1 (`--name reference-1`) — Verified 2026-11-21: 2026-11-21 reference-1 exit 0
- [X] T-R02G0408-010 Reference regression chunk 2 (`--name reference-2`) — Verified 2026-11-21: 2026-11-21 reference-2 exit 0: 7 of 7 with chunk 1
- [X] T-R02G0408-011 Script tests, run alone (`--name script-tests`) — Verified 2026-11-21: 2026-11-21 script-tests exit 0, run alone
- [ ] T-R02G0408-012 {device} After ImplementationLock-100, on D1, D2 and D3: frame time and memory of the golden levels.
  Not run before the lock.
- [X] T-R02G0408-013 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record — Verified 2026-11-21: 2026-11-21 converge round 1 converged (nothing appended); sealed 17 passing; recorded R02-G04-08 pass

## Dependencies and parallel work

001 → {002 (agent A), 003 (lead) → 004 (agent B), 005 (lead + agent C), 006 (agent D)} → 007 … 011, 013. 012 is a
{device} task outside this campaign. Shared files (golden source, scene, release list, workflow, docs) stay with the
lead. MVP: Story 1.
