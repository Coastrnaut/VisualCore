# Tasks: R02-G21-08 — Binary Gardens: visual golden and solver regression

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/](contracts/), [quickstart.md](quickstart.md). Gate R02-G21-08 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G21-08 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_508;
tests stay short (< 10 s each); no wall-clock assertion. No agent runs host tests while a baseline or chain runs.
Prerequisites: R02-G21-04 … 07 recorded before the golden baseline is written (T-003) and before the gate is recorded;
the solver regression (T-002) reads only the unchanged levels, witnesses and solver and may be drafted earlier.

## Phase 1: Setup

- [X] T-R02G2108-001 Baselines on the committed tree after R02-G21-07 is recorded: `--name baseline-host`, `--name — Verified 2026-11-27: baseline-host, baseline-timing, baseline-round02-1, -2, -3c, -3e, -3f exit 0 (after R02-G21-07 was recorded)
  baseline-timing`, `--name baseline-round02-1`, `-2`, `-3c`, `-3e`, `-3f` (the five round-two filters, chunk 2 with
  `BinaryGardens`)

## Phase 2: Story 1 — every level stays solvable as certified (P1) 🎯

- [X] T-R02G2108-002 [P] [US1] Create — Verified 2026-11-27: host exit 0 (swift test --filter BinaryGardensRegressionSolverTests: 15 tests, 100 levels in 10 groups and 13 alterations on levels 1, 41, 81)
  `Packages/ExperiencesRound02/BinaryGardens/CoreTests/BinaryGardensRegressionSolverTests.swift` (agent B: for every
  level in ten groups of 10, "the generated level equals its witness's level (part by part and by fingerprint); the
  witness's actions replay on a fresh play to a win on exactly the final run and not before, within the budget, with
  its per-action fingerprints (after begin, after the tutorial on a tutorial level, then one per action), digests and
  report; plan at the band's plan length returns exactly the witness's actions with arrangementsByDepth[size − 1],
  nearestMiss, nearestMissArrangement and work equal to the witness's, with work ≤ 5,000"; the thirteen named
  alterations of clarification Q2 applied to levels 1, 41 and 81 (a world's comfortable band, lethal bound, bloom band,
  required window and orbit; a ring radius; a luminosity level; a star's starting ring, phase or luminosity; the lethal
  tolerance; the budget; a plan action; a witness action, a per-action fingerprint or digest; the counterexample's
  arrangements count), the altered world and star chosen from seed 2_508, each failing naming the level and the part,
  the unaltered input giving no failure); `--name host -- swift test --package-path Packages/ExperiencesRound02
  --filter BinaryGardensRegressionSolverTests`

## Phase 3: Story 2 — the picture does not drift (P1)

- [X] T-R02G2108-003 [US2] Create `Packages/ExperiencesRound02/BinaryGardens/Core/BinaryGardensGolden.swift` (DEBUG or — Verified 2026-11-27: golden-frames.json (17 frames, schema 1, 64,835 bytes) written with BINARY_GARDENS_WRITE_GOLDEN=1 after R02-G21-07 was recorded; BinaryGardensGolden in RELEASE_FORBIDDEN
  VISUALCORE_AUTOMATION; "17 frames: levels 1, 21, 41, 61, 81 at tiers 0 … 2 and level 25 at tier 0, each after all of
  the witness's actions but not the run, tick 24 shown, presentation time 0, the authored camera, no preview and no
  inspected world, plus the hero frame of `scenario-manifest.json` at tier 0 (`BinaryGardensExperienceCore.heroTick(_:)`);
  at 1,152 × 768: the barycentre, every world's centre (world order), both stars' centres, the first gauge plate's left
  margin, the first actions bar and, when the level has a tilt dial, the first tilt pip, positions rounded to 1/8 px and
  a point behind the eye null; the counts of the spec's clarification Q3; the shown tick, tilt, each star's ring, phase
  and luminosity index, each world's integral and longest comfortable window with its start; every colour of
  `BinaryGardensPalette.all` (module-internal) as 8-bit sRGB and every material code with its palette constant name;
  JSON with sorted keys; SHA-256"; manifest; compare with the one-quantum fallback and the pinned-digest self-check),
  generate `Packages/ExperiencesRound02/BinaryGardens/golden-frames.json` (schema 1) with
  `BINARY_GARDENS_WRITE_GOLDEN=1` only after R02-G21-07 is recorded, and add `BinaryGardensGolden` to
  `RELEASE_FORBIDDEN` in `scripts/release_check.py`
- [X] T-R02G2108-004 [P] [US2] Create — Verified 2026-11-27: host-2 exit 0 (swift test --filter BinaryGardensRegressionGoldenTests: 13 tests)
  `Packages/ExperiencesRound02/BinaryGardens/CoreTests/BinaryGardensRegressionGoldenTests.swift` (agent C: every
  frame's recomputed description matches its pinned one; each pinned digest equals the digest of its pinned
  description; a moved position beyond a quantum, a changed colour, material entry or count, a missing frame, an unknown
  frame, schema ≠ 1 and a hand-edited description all fail naming the frame and the first differing value; the file is
  rewritten only with the switch); `--name host-2 -- swift test --package-path Packages/ExperiencesRound02 --filter
  BinaryGardensRegressionGoldenTests`

## Phase 4: Stories 2 and 3 — simulator frames and memory (P1, P2)

- [X] T-R02G2108-005 [US2] [US3] Create — Verified 2026-11-27: sim-27 exit 0 (sim-27.2, BinaryGardensExperienceTests: 82 tests in 10 suites; 17 golden frames incl. level 25's tilt pip, 12 memory cycles)
  `Packages/ExperiencesRound02/BinaryGardens/ExperienceTests/BinaryGardensRegressionGoldenFrameTests.swift` and
  `Packages/ExperiencesRound02/BinaryGardens/ExperienceTests/BinaryGardensRegressionMemoryTests.swift` (agent C: the 17
  frames rendered and checked against their descriptions with the feature-503 tolerances, level 25's tilt dial pip
  included; points on screen where the description puts them; 12 open-draw-warn-close cycles (prepare seed 0, level 1,
  3 frames at tier 0, a memory warning, 1 frame, teardown) with `ProcessMemory.footprint()`, cycles 2 … 12 within 16 MB
  of cycle 1 when `TEST_RUNNER_BINARY_GARDENS_MEMORY_ISOLATED=1`, readings printed otherwise; the system scene's
  `liveObjectCount` 0 after each close and warning and rebuilt by the next frame; an unavailable footprint fails with a
  named reason); `--name sim-27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme
  ExperiencesRound02-Package --destination sim-27.2 --action test --only-testing BinaryGardensExperienceTests`

## Phase 5: Story 4 — the checks run on every change (P2)

- [X] T-R02G2108-006 [P] [US4] Create `scripts/binary_gardens_regression.py` (agent B: host filter — Verified 2026-11-27: regression exit 0 (scripts/binary_gardens_regression.py: host PASS, simulator PASS with the memory isolation variable); BinaryGardensRegressionTests in scripts/test_scripts.py; CI step 'Binary Gardens regression (host)' in half b
  `BinaryGardensRegression`, then the simulator classes through `xcodebuild_package.py --only-testing` on `sim-27.2` with
  the isolation variable; one summary line per part with pass or fail and the first failing name; non-zero exit on any
  failure; `--dry-run` and `--skip-simulator`; usage lines naming this script) and its test class, handed over as a
  separate file and inserted by the lead into `scripts/test_scripts.py`, and add the named step "Binary Gardens
  regression (host)" to half b of the `round02-host-tests` job in `.github/workflows/ci.yml` (no filter change);
  `--name regression -- python3 scripts/binary_gardens_regression.py`

## Phase 6: Regression, documentation and close

- [X] T-R02G2108-007 Docs: `docs/architecture/binary-gardens.md` (regression net), — Verified 2026-11-27: round02-host-1, -2, -3c, -3e, -3f exit 0; docs: architecture regression section, package README, automatedtesting
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host-1`, `-2`, `-3c`, `-3e`,
  `-3f` (the chunks of T-001)
- [ ] T-R02G2108-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`, `--name
  host-full`, `--name app-unit`
- [ ] T-R02G2108-009 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G2108-010 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G2108-011 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G2108-012 {device} After ImplementationLock-100, on D1, D2 and D3: frame time and memory of the golden
  levels (SC-R02G2108-007). Not run before the lock.
- [ ] T-R02G2108-013 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record;
  README row and gate list updated

## Dependencies and parallel work

001 → {002 (agent B), 003 (lead) → 004 (agent C), 005 (agent C), 006 (agent B)} → 007 … 011, 013. 012 is a {device}
task outside this campaign. Agent B may draft 002 in an isolated copy before 001 (a new test file reading unchanged
inputs), but runs no host tests while the lead's baselines or chain run. Shared files (golden source, release list,
workflow, script tests, docs) stay with the lead. MVP: Story 1. Requirement coverage: FR-001/002 → 002; FR-003/004 →
003, 004, 005; FR-005 → 005; FR-006 → 006; FR-007 → 002 … 006; FR-008 → 007 … 011; FR-009 → 001, 003, 013.
