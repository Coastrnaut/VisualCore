# Tasks: R02-G18-08 — Apsides Workshop: visual golden and solver regression

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/](contracts/), [quickstart.md](quickstart.md). Gate R02-G18-08 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G18-08 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_478;
tests stay short (< 10 s each); no wall-clock assertion. No agent runs host tests while a baseline or chain runs.

## Phase 1: Setup

- [ ] T-R02G1808-001 Baselines on the committed tree after R02-G18-07 is recorded: `--name baseline-host`, `--name
  baseline-timing`, `--name baseline-round02-1`, `-2`, `-3c`, `-3e`, `-3f` (the five round-two filters, chunk 3f with
  `ApsidesWorkshop`)

## Phase 2: Story 1 — every level stays solvable as certified (P1) 🎯

- [ ] T-R02G1808-002 [P] [US1] Create
  `Packages/ExperiencesRound02/ApsidesWorkshop/CoreTests/ApsidesWorkshopRegressionSolverTests.swift` (agent A: for every
  level in ten groups of 10, "the generated level equals its witness's level (fingerprint); the witness's actions replay
  on a fresh play to a win on exactly the final play and not before, within the budget, with its per-action fingerprints
  (after begin, after the tutorial on a tutorial level, then one per action) and digests; plan returns exactly the
  witness's tunings with orbitsByDepth[size − 1] equal to the counterexample's orbits at depth size − 1, with work ≤
  workBound"; twelve named alterations of clarification Q2 (a planet's centre, a planet's radius, a target's kind, a
  target's sector, a target's band, the starting orbit, the period, the budget; a plan tuning; a witness action, a
  per-action fingerprint or digest; the counterexample's orbits count) each fail naming the level and the part); `--name
  host -- swift test --package-path Packages/ExperiencesRound02 --filter ApsidesWorkshopRegressionSolverTests`

## Phase 3: Story 2 — the picture does not drift (P1)

- [ ] T-R02G1808-003 [US2] Create `Packages/ExperiencesRound02/ApsidesWorkshop/Core/ApsidesWorkshopGolden.swift` (DEBUG
  or VISUALCORE_AUTOMATION; "16 frames: levels 1, 21, 41, 61, 81 at tiers 0 … 2 at presentation time 0 after all of the
  witness's tunings but not the play, with no preview, shown at tick T / 2, plus the hero frame of
  `scenario-manifest.json` at tier 0; at 1,152 × 768 with the authored camera: the star, the orbiter at the shown tick,
  the periapsis marker (the position of tick 0) and the apoapsis marker (tick T / 2), every planet centre (index order)
  and the first actions bar, positions rounded to 1/8 px and a point behind the eye null; the counts of sectors,
  swept-area wedges, orbit-loop points, planets, gauges, met gauges and lit and total actions bars; the 18 palette
  colours 8-bit sRGB; JSON with sorted keys; SHA-256"); manifest; compare with the one-quantum fallback and the
  pinned-digest self-check), generate `Packages/ExperiencesRound02/ApsidesWorkshop/golden-frames.json` (schema 1) with
  `APSIDES_WORKSHOP_WRITE_GOLDEN=1`, and add `ApsidesWorkshopGolden` to `RELEASE_FORBIDDEN` in
  `scripts/release_check.py`
- [ ] T-R02G1808-004 [P] [US2] Create
  `Packages/ExperiencesRound02/ApsidesWorkshop/CoreTests/ApsidesWorkshopRegressionGoldenTests.swift` (agent B: every
  frame's recomputed description matches its pinned one; each pinned digest equals the digest of its pinned description;
  a moved position beyond a quantum, a changed colour or count, a missing frame, an unknown frame, schema ≠ 1 and a
  hand-edited description all fail naming the frame; the file is rewritten only with the switch); `--name host-2 --
  swift test --package-path Packages/ExperiencesRound02 --filter ApsidesWorkshopRegressionGoldenTests`

## Phase 4: Stories 2 and 3 — simulator frames and memory (P1, P2)

- [ ] T-R02G1808-005 [US2] [US3] Create
  `Packages/ExperiencesRound02/ApsidesWorkshop/ExperienceTests/ApsidesWorkshopRegressionGoldenFrameTests.swift` and
  `Packages/ExperiencesRound02/ApsidesWorkshop/ExperienceTests/ApsidesWorkshopRegressionMemoryTests.swift` (agent C: the
  16 frames rendered and checked against their descriptions with the feature-473 tolerances (the star's and the
  orbiter's centres 0.25 brighter than the backdrop in luminance, the first lit actions bar with red above blue by 0.08,
  the first gauge track's centre 0.1 from the backdrop, each point at least 6 px from what is drawn after it, backdrop
  patches within 0.06 of the gradient; points on screen where the description puts them); 12 open-draw-warn-close cycles
  (prepare a level, 3 frames at tier 0, a memory warning, 1 frame, teardown) with `ProcessMemory.footprint()`, cycles 2
  … 12 within 16 MB of cycle 1 when `TEST_RUNNER_APSIDES_WORKSHOP_MEMORY_ISOLATED=1`, readings printed otherwise; the
  compass scene's `liveObjectCount` 0 after each close and warning and rebuilt by the next frame; an unavailable
  footprint fails with a named reason); `--name sim-27 -- python3 scripts/xcodebuild_package.py --package
  Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package --destination sim-27.2 --action test --only-testing
  ApsidesWorkshopExperienceTests`

## Phase 5: Story 4 — the checks run on every change (P2)

- [ ] T-R02G1808-006 [P] [US4] Create `scripts/apsides_workshop_regression.py` and its test in `scripts/test_scripts.py`
  (agent D: host filter `ApsidesWorkshopRegression`, then the simulator classes through `xcodebuild_package.py
  --only-testing` with the isolation variable, one summary line per part with pass or fail and the first failing name, a
  non-zero exit on any failure), and add the named step "Apsides Workshop regression (host)" to the `round02-host-tests`
  job of `.github/workflows/ci.yml`; `--name regression -- python3 scripts/apsides_workshop_regression.py`

## Phase 6: Regression, documentation and close

- [ ] T-R02G1808-007 Docs: `docs/architecture/apsides-workshop.md` (regression net),
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host-1`, `-2`, `-3c`, `-3e`,
  `-3f` (the chunks of T-001)
- [ ] T-R02G1808-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`, `--name
  host-full`, `--name app-unit`
- [ ] T-R02G1808-009 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G1808-010 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G1808-011 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G1808-012 {device} After ImplementationLock-100, on D1, D2 and D3: frame time and memory of the golden
  levels. Not run before the lock.
- [ ] T-R02G1808-013 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record;
  README row and gate list updated

## Dependencies and parallel work

001 → {002 (agent A), 003 (lead) → 004 (agent B), 005 (agent C), 006 (agent D)} → 007 … 011, 013. 012 is a {device}
task outside this campaign. Agent A may start in an isolated copy before 001 (a new test file), but runs no host tests
while the lead's baselines or chain run. Shared files (golden source, release list, workflow, docs) stay with the lead.
MVP: Story 1. Requirement coverage: FR-001/002 → 002; FR-003/004 → 003, 004, 005; FR-005 → 005; FR-006 → 006;
FR-007 → 002 … 006; FR-008 → 007 … 011.
