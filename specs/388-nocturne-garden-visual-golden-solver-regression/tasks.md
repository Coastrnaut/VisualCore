# Tasks: R02-G09-08 — Nocturne Garden: visual golden and solver regression

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G09-08 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G09-08 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_388;
tests stay short (< 10 s each); no wall-clock assertion.

## Phase 1: Setup

- [X] T-R02G0908-001 Baselines: `--name baseline-round02`, `--name baseline-host`, `--name baseline-timing` — Verified 2026-11-22: baseline-host, baseline-timing, baseline-round02 exit 0

## Phase 2: Story 1 — every level stays solvable as certified (P1) 🎯

- [X] T-R02G0908-002 [P] [US1] Create `Packages/ExperiencesRound02/NocturneGarden/CoreTests/NocturneGardenRegressionSolverTests.swift` (agent A: for every — Verified 2026-11-22: host (NocturneGardenRegressionSolverTests, 14 tests: all 100 levels in ten groups - generated level equals the witness, witness moves replay to a win with per-move digests and fingerprints, solve returns exactly the witness's moves with smallest equal to the bound and work within the work bound; ten alterations named on levels 1 and 41) exit 0, lead retest
  level in ten groups of 10, "the generated level equals its witness's level; the witness's moves replay to a win in
  exactly its smallest move count within the budget, with its per-move digests and fingerprints; solve returns exactly
  the witness's moves with smallest equal to the witness's and to the lower bound's, with work ≤ workBound"; ten named
  alterations of clarification Q2 (a target cell, a forbidden cell, the budget, the leak allowance, the required match;
  a solution move; a witness move, a per-move digest, a per-move fingerprint; the smallest move count) each fail naming
  the level and the part); `--name host -- swift test --package-path Packages/ExperiencesRound02 --filter
  NocturneGardenRegressionSolverTests`

## Phase 3: Story 2 — the picture does not drift (P1)

- [X] T-R02G0908-003 [US2] Create `Packages/ExperiencesRound02/NocturneGarden/Core/NocturneGardenGolden.swift` (DEBUG or VISUALCORE_AUTOMATION; "16 frames: — Verified 2026-11-22: NocturneGardenGolden (16 frames: levels 1, 21, 41, 61, 81 x tiers 0-2 after at most 2 certified moves at time 0, plus the hero frame) and golden-frames.json written with NOCTURNE_GARDEN_WRITE_GOLDEN=1 (md5 50d52ade651fd67981915a83e744c2df), stable when rerun without the switch; listed as presentation source in the invariant scan; NocturneGardenGolden added to RELEASE_FORBIDDEN
  levels 1, 21, 41, 61, 81 at tiers 0 … 2 at time 0 after the witness's first min(smallest − 1, 2) moves, plus the hero
  frame at tier 0; at 1,152 × 768 with the authored camera: every bloom head's centre (canonical order) and the
  lantern's centre, positions rounded to 1/8 px and an off-screen point null; the shadow cell count; the moves spent and
  the budget; the ground, mist, shadow, gold, coral, leak, lantern, spent and unspent colours 8-bit sRGB; JSON with
  sorted keys; SHA-256"; manifest; compare with the one-quantum fallback and the pinned-digest self-check), generate
  `Packages/ExperiencesRound02/NocturneGarden/golden-frames.json` with `NOCTURNE_GARDEN_WRITE_GOLDEN=1`, and add `NocturneGardenGolden` to
  `RELEASE_FORBIDDEN` in `scripts/release_check.py`
- [ ] T-R02G0908-004 [P] [US2] Create `Packages/ExperiencesRound02/NocturneGarden/CoreTests/NocturneGardenRegressionGoldenTests.swift` (agent B: every frame's
  recomputed description matches its pinned one; each pinned digest equals the digest of its pinned description; a
  moved position beyond a quantum, a changed colour or count, a missing frame, an unknown frame, schema ≠ 1 and a
  hand-edited description all fail naming the frame; the file is rewritten only with the switch); `--name host-2 --
  swift test --package-path Packages/ExperiencesRound02 --filter NocturneGardenRegressionGoldenTests`

## Phase 4: Stories 2 and 3 — simulator frames and memory (P1, P2)

- [ ] T-R02G0908-005 [US2] [US3] Create `Packages/ExperiencesRound02/NocturneGarden/ExperienceTests/NocturneGardenRegressionGoldenFrameTests.swift` and
  `Packages/ExperiencesRound02/NocturneGarden/ExperienceTests/NocturneGardenRegressionMemoryTests.swift` (agent C: the 16 frames rendered and checked against
  their descriptions with the feature-383 tolerances (plain shadow cells within 3 px of a pixel 0.15 darker than the
  mist reference, forbidden cells near a coral pixel, target cells near a gold brightening, the first gauge bar at least
  0.1 from the ground, the probe corners within 0.05 of the ground; bloom heads and the lantern on screen where the
  description puts them); 12 open-draw-warn-close cycles with `ProcessMemory.footprint()`, cycles 2 … 12 within 16 MB
  of cycle 1 when `TEST_RUNNER_NOCTURNE_GARDEN_MEMORY_ISOLATED=1`, readings printed otherwise; the garden scene's
  `liveObjectCount` 0 after each close and warning; an unavailable footprint fails with a named reason); `--name
  sim-27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme
  ExperiencesRound02-Package --destination sim-27.2 --action test --only-testing NocturneGardenExperienceTests`

## Phase 5: Story 4 — the checks run on every change (P2)

- [ ] T-R02G0908-006 [P] [US4] Create `scripts/nocturne_garden_regression.py` and its test in `scripts/test_scripts.py`
  (agent D: host filter `NocturneGardenRegression`, then the simulator classes through `xcodebuild_package.py
  --only-testing` with the isolation variable, one summary line per part with pass or fail and the first failing name,
  a non-zero exit on any failure), and add the named step "Nocturne Garden regression (host)" to
  `.github/workflows/ci.yml`; `--name regression -- python3 scripts/nocturne_garden_regression.py`

## Phase 6: Regression, documentation and close

- [ ] T-R02G0908-007 Docs: `docs/architecture/nocturne-garden.md` (regression net),
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host`
- [ ] T-R02G0908-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`,
  `--name host-full`, `--name app-unit`
- [ ] T-R02G0908-009 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G0908-010 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G0908-011 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G0908-012 {device} After ImplementationLock-100, on D1, D2 and D3: frame time and memory of the golden levels.
  Not run before the lock.
- [ ] T-R02G0908-013 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record

## Dependencies and parallel work

001 → {002 (agent A), 003 (lead) → 004 (agent B), 005 (agent C), 006 (agent D)} → 007 … 011, 013. 012 is a {device}
task outside this campaign. Shared files (golden source, release list, workflow, docs) stay with the lead. MVP: Story 1.
Requirement coverage: FR-001/002 → 002; FR-003/004 → 003, 004, 005; FR-005 → 005; FR-006 → 006; FR-007 → 002 … 006;
FR-008 → 007 … 011.
