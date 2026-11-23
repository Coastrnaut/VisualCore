# Tasks: R02-G12-08 — Harmonic Bridges: visual golden and solver regression

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/](contracts/), [quickstart.md](quickstart.md). Gate R02-G12-08 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G12-08 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_418;
tests stay short (< 10 s each); no wall-clock assertion.

## Phase 1: Setup

- [X] T-R02G1208-001 Baselines after R02-G12-07 is recorded: `--name baseline-host`, `--name baseline-timing`, `--name — Verified 2026-11-23: baseline-host, baseline-timing, baseline-round02 exit 0 on the committed tree
  baseline-round02 -- swift test --package-path Packages/ExperiencesRound02`

## Phase 2: Story 1 — every level stays solvable as certified (P1) 🎯

- [X] T-R02G1208-002 [P] [US1] Create `Packages/ExperiencesRound02/HarmonicBridges/CoreTests/HarmonicBridgesRegressionSolverTests.swift` (agent A: for every — Verified 2026-11-23: host (HarmonicBridgesRegressionSolverTests 15 tests: 100 levels in ten groups equal their witnesses, replay to a win in exactly the action count within the budget with bridge digests and fingerprints, plan equals the witness's tunings and smallerChoices with work within workBound; eleven named alterations each fail naming the level and part; a refused level copy named) exit 0, lead retest
  level in ten groups of 10, "the generated level equals its witness's level (fingerprint); the witness's actions replay
  on a fresh play to a win in exactly its action count within the budget, with its per-action fingerprints and per-step
  bridge digests; plan returns exactly the witness's tunings with its smallerChoices (the counterexample's choices) and
  size, with work ≤ workBound"; eleven named alterations of clarification Q2 (an island's position, a string's length, a
  string's starting peg, a string's lock, a step's tone, the threshold, the budget; a plan tuning; a witness action, a
  per-action fingerprint; the smaller-choices count) each fail naming the level and the part); `--name host -- swift test
  --package-path Packages/ExperiencesRound02 --filter HarmonicBridgesRegressionSolverTests`

## Phase 3: Story 2 — the picture does not drift (P1)

- [X] T-R02G1208-003 [US2] Create `Packages/ExperiencesRound02/HarmonicBridges/Core/HarmonicBridgesGolden.swift` (DEBUG or VISUALCORE_AUTOMATION; "16 frames: — Verified 2026-11-23: HarmonicBridgesGolden (DEBUG or VISUALCORE_AUTOMATION): 16 frames (levels 1, 21, 41, 61, 81 x tiers 0-2 after the witness's tunings plus the hero), descriptions with positions to 1/8 px, counts, 13 colours, sorted-key JSON and SHA-256, manifest and compare; golden-frames.json schema 1 with 16 frames generated with HARMONIC_BRIDGES_WRITE_GOLDEN=1; invariant, purity, shader and scenario tests pass (33); HarmonicBridgesGolden in RELEASE_FORBIDDEN (release-symbols, 34 release script tests) exit 0
  levels 1, 21, 41, 61, 81 at tiers 0 … 2 at presentation time 0 after the witness's tunings and before its test, plus
  the hero frame of `scenario-manifest.json` at tier 0; at 1,152 × 768 with the authored camera: every island top, every
  string midpoint, every membrane check point of the shown step's bridges, every step pip (index order) and the first
  gauge bar, positions rounded to 1/8 px and an off-screen point null; the counts of islands, strings, bridges in the
  shown step, filled and hollow marks, pips and lit and total gauge bars; the ground, island face, island edge, string,
  membrane, filled mark, hollow mark, start, goal, pip, unlit pip, lit gauge and unlit gauge colours 8-bit sRGB; JSON with
  sorted keys; SHA-256"; manifest; compare with the one-quantum fallback and the pinned-digest self-check), generate
  `Packages/ExperiencesRound02/HarmonicBridges/golden-frames.json` (schema 1) with `HARMONIC_BRIDGES_WRITE_GOLDEN=1`, and
  add `HarmonicBridgesGolden` to `RELEASE_FORBIDDEN` in `scripts/release_check.py`
- [X] T-R02G1208-004 [P] [US2] Create `Packages/ExperiencesRound02/HarmonicBridges/CoreTests/HarmonicBridgesRegressionGoldenTests.swift` (agent B: every frame's — Verified 2026-11-23: host-2 (HarmonicBridgesRegressionGoldenTests 9 tests: the fixed set, every frame shows islands, strings, bridges and filled marks and is not won, deterministic descriptions with distinct tier digests, every frame matches the pinned file, pinned digests self-consistent, missing, unreadable, renamed, extra, unknown frames and schema 2 named, positions beyond one quantum, colours, counts and tier detail caught, a hand-edited description refused) exit 0, lead retest; pinned file unchanged by the run
  recomputed description matches its pinned one; each pinned digest equals the digest of its pinned description; a moved
  position beyond a quantum, a changed colour or count, a missing frame, an unknown frame, schema ≠ 1 and a hand-edited
  description all fail naming the frame; the file is rewritten only with the switch); `--name host-2 -- swift test
  --package-path Packages/ExperiencesRound02 --filter HarmonicBridgesRegressionGoldenTests`

## Phase 4: Stories 2 and 3 — simulator frames and memory (P1, P2)

- [X] T-R02G1208-005 [US2] [US3] Create `Packages/ExperiencesRound02/HarmonicBridges/ExperienceTests/HarmonicBridgesRegressionGoldenFrameTests.swift` and — Verified 2026-11-23: sim-27 (63 Harmonic Bridges simulator tests incl. HarmonicBridgesRegressionGoldenFrameTests: the 16 frames rendered at 1,152 x 768 match their descriptions within one quantum and the feature-413 tolerances, the hero frame too; HarmonicBridgesRegressionMemoryTests: 12 open-draw-warn-close cycles with liveObjectCount 0 after each warning and close, footprint read each cycle, shed caches and reopen rebuild) exit 0, lead retest
  `Packages/ExperiencesRound02/HarmonicBridges/ExperienceTests/HarmonicBridgesRegressionMemoryTests.swift` (agent C: the 16 frames rendered and checked
  against their descriptions with the feature-413 tolerances (island tops 0.1 from the ground in luminance with red above
  blue, membrane check points 0.08 from the ground with blue above red, the first gauge bar 0.1 from the ground, the
  ground within 0.05, each point at least 6 px from other elements; points on screen where the description puts them);
  12 open-draw-warn-close cycles (prepare a level, 3 frames at tier 0, a memory warning, 1 frame, teardown) with
  `ProcessMemory.footprint()`, cycles 2 … 12 within 16 MB of cycle 1 when
  `TEST_RUNNER_HARMONIC_BRIDGES_MEMORY_ISOLATED=1`, readings printed otherwise; the bridge scene's `liveObjectCount` 0
  after each close and warning and rebuilt by the next frame; an unavailable footprint fails with a named reason);
  `--name sim-27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme
  ExperiencesRound02-Package --destination sim-27.2 --action test --only-testing HarmonicBridgesExperienceTests`

## Phase 5: Story 4 — the checks run on every change (P2)

- [X] T-R02G1208-006 [P] [US4] Create `scripts/harmonic_bridges_regression.py` and its test in `scripts/test_scripts.py` — Verified 2026-11-23: regression (scripts/harmonic_bridges_regression.py: host PASS, simulator PASS with TEST_RUNNER_HARMONIC_BRIDGES_MEMORY_ISOLATED=1, footprint 28.31 -> 28.86 MB over 12 cycles, 0.55 MB growth within 16 MB) exit 0; HarmonicBridgesRegressionTests 5 script tests pass; CI step 'Harmonic Bridges regression (host)' in round02-host-tests
  (agent D: host filter `HarmonicBridgesRegression`, then the simulator classes through `xcodebuild_package.py
  --only-testing` with the isolation variable, one summary line per part with pass or fail and the first failing name,
  a non-zero exit on any failure), and add the named step "Harmonic Bridges regression (host)" to the
  `round02-host-tests` job of `.github/workflows/ci.yml`; `--name regression -- python3
  scripts/harmonic_bridges_regression.py`

## Phase 6: Regression, documentation and close

- [X] T-R02G1208-007 Docs: `docs/architecture/harmonic-bridges.md` (regression net), — Verified 2026-11-23: round02-host (swift test --package-path Packages/ExperiencesRound02, 335 s) exit 0; architecture doc regression net, ExperiencesRound02 README feature 418, testing doc entry (baselines before new files); validate_docs passes
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host`
- [X] T-R02G1208-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`, — Verified 2026-11-23: rendering-27, rendering-26, experiences, host-full, app-unit exit 0
  `--name host-full`, `--name app-unit`
- [ ] T-R02G1208-009 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G1208-010 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G1208-011 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G1208-012 {device} After ImplementationLock-100, on D1, D2 and D3: frame time and memory of the golden levels.
  Not run before the lock.
- [ ] T-R02G1208-013 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record;
  README row and gate list updated

## Dependencies and parallel work

001 → {002 (agent A), 003 (lead) → 004 (agent B), 005 (agent C), 006 (agent D)} → 007 … 011, 013. 012 is a {device}
task outside this campaign. Agent A may start in an isolated copy before 001 (a new test file). Shared files (golden
source, release list, workflow, docs) stay with the lead. MVP: Story 1. Requirement coverage: FR-001/002 → 002;
FR-003/004 → 003, 004, 005; FR-005 → 005; FR-006 → 006; FR-007 → 002 … 006; FR-008 → 007 … 011.
