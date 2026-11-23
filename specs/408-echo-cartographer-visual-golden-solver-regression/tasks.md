# Tasks: R02-G11-08 — Echo Cartographer: visual golden and solver regression

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G11-08 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G11-08 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_408;
tests stay short (< 10 s each); no wall-clock assertion.

## Phase 1: Setup

- [X] T-R02G1108-001 Baselines after R02-G11-07 is recorded: `--name baseline-host`, `--name baseline-timing`, `--name — Verified 2026-11-23: baseline-host, baseline-timing, baseline-round02 exit 0 on the committed tree
  baseline-round02 -- swift test --package-path Packages/ExperiencesRound02`

## Phase 2: Story 1 — every level stays solvable as certified (P1) 🎯

- [X] T-R02G1108-002 [P] [US1] Create `Packages/ExperiencesRound02/EchoCartographer/CoreTests/EchoCartographerRegressionSolverTests.swift` (agent A: for every — Verified 2026-11-23: host (EchoCartographerRegressionSolverTests 15 tests, 114 cases: 100 levels in ten groups equal their witnesses, replay to a win in exactly the action count within the energy with echo digests and fingerprints, plan equals the witness's pulses, placements and counterexample with work within workBound; ten named alterations each fail naming the level and part; a refused level copy named) exit 0, lead retest
  level in ten groups of 10, "the generated level equals its witness's level; the witness's actions replay to a win in
  exactly its action count within the energy, with its per-pulse echo digests and per-action fingerprints; plan returns
  exactly the witness's pulses with its placements and placements before the last pulse, with work ≤ workBound"; ten
  named alterations of clarification Q2 (a beacon cell, a chamber wall, the energy, the tolerance, the miss cost; a plan
  pulse; a witness action, a per-pulse echo digest, a per-action fingerprint; the placements count) each fail naming the
  level and the part); `--name host -- swift test --package-path Packages/ExperiencesRound02 --filter
  EchoCartographerRegressionSolverTests`

## Phase 3: Story 2 — the picture does not drift (P1)

- [X] T-R02G1108-003 [US2] Create `Packages/ExperiencesRound02/EchoCartographer/Core/EchoCartographerGolden.swift` (DEBUG or VISUALCORE_AUTOMATION; "16 frames: — Verified 2026-11-23: EchoCartographerGolden (DEBUG or VISUALCORE_AUTOMATION): 16 frames (levels 1, 21, 41, 61, 81 x tiers 0-2 plus the hero), descriptions with positions to 1/8 px, counts, colours, sorted-key JSON and SHA-256, manifest and compare; golden-frames.json schema 1 with 16 frames generated with ECHO_CARTOGRAPHER_WRITE_GOLDEN=1; invariant presentation source listed (24 tests pass); EchoCartographerGolden in RELEASE_FORBIDDEN (36 release script tests pass)
  levels 1, 21, 41, 61, 81 at tiers 0 … 2 at time 0 after the witness's first min(pulses − 1, 2) pulses (at least one)
  and one marker on the first known-open cell that is not the entry, plus the hero frame at tier 0; at 1,152 × 768 with
  the authored camera: every known floor tile centre, known wall top centre, marker ring centre and located pillar top
  (cell order), the entry and the first gauge bar, positions rounded to 1/8 px and an off-screen point null; the counts of
  open cells, walls, markers, located beacons, rays and lit and total gauge bars; the ground, floor, entry, marker, wall
  face, wall edge, pillar, ray, gauge lit and gauge unlit colours 8-bit sRGB; JSON with sorted keys; SHA-256"; manifest;
  compare with the one-quantum fallback and the pinned-digest self-check), generate `Packages/ExperiencesRound02/EchoCartographer/golden-frames.json` with
  `ECHO_CARTOGRAPHER_WRITE_GOLDEN=1`, and add `EchoCartographerGolden` to `RELEASE_FORBIDDEN` in
  `scripts/release_check.py`
- [X] T-R02G1108-004 [P] [US2] Create `Packages/ExperiencesRound02/EchoCartographer/CoreTests/EchoCartographerRegressionGoldenTests.swift` (agent B: every frame's — Verified 2026-11-23: host-2 (EchoCartographerRegressionGoldenTests 9 tests: the fixed set, every frame shows floors, walls and a marker and is not won, deterministic descriptions with distinct tier digests, every frame matches the pinned file, pinned digests self-consistent, missing, unreadable, renamed, extra, unknown frames and schema 2 named, a position beyond one quantum, a colour, count or tier change caught, a hand-edited description with its old digest refused; the file rewritten only with the switch) exit 0, lead retest; pinned file unchanged by the run
  recomputed description matches its pinned one; each pinned digest equals the digest of its pinned description; a moved
  position beyond a quantum, a changed colour or count, a missing frame, an unknown frame, schema ≠ 1 and a hand-edited
  description all fail naming the frame; the file is rewritten only with the switch); `--name host-2 -- swift test
  --package-path Packages/ExperiencesRound02 --filter EchoCartographerRegressionGoldenTests`

## Phase 4: Stories 2 and 3 — simulator frames and memory (P1, P2)

- [X] T-R02G1108-005 [US2] [US3] Create `Packages/ExperiencesRound02/EchoCartographer/ExperienceTests/EchoCartographerRegressionGoldenFrameTests.swift` and — Verified 2026-11-23: sim-27 (58 Echo Cartographer simulator tests incl. EchoCartographerRegressionGoldenFrameTests: the 16 frames rendered at 1,152 x 768 match their descriptions within one quantum and the feature-403 tolerances, the hero frame too; EchoCartographerRegressionMemoryTests: 12 open-draw-warn-close cycles with liveObjectCount 0 after each warning and close, footprint read each cycle, shed caches and reopen rebuild) exit 0, lead retest
  `Packages/ExperiencesRound02/EchoCartographer/ExperienceTests/EchoCartographerRegressionMemoryTests.swift` (agent C: the 16 frames rendered and checked against
  their descriptions with the feature-403 tolerances (known floor tile centres 0.1 from the ground in luminance, known wall
  tops 0.08 from the ground with green above red by 0.05, the first gauge bar 0.1 from the ground, the probe corners
  within 0.05 of the ground, each point at least 6 px from other elements; points on screen where the description puts
  them); 12 open-draw-warn-close cycles with `ProcessMemory.footprint()`, cycles 2 … 12 within 16 MB of cycle 1 when
  `TEST_RUNNER_ECHO_CARTOGRAPHER_MEMORY_ISOLATED=1`, readings printed otherwise; the chamber scene's `liveObjectCount`
  0 after each close and warning; an unavailable footprint fails with a named reason); `--name sim-27 -- python3
  scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package --destination
  sim-27.2 --action test --only-testing EchoCartographerExperienceTests`

## Phase 5: Story 4 — the checks run on every change (P2)

- [X] T-R02G1108-006 [P] [US4] Create `scripts/echo_cartographer_regression.py` and its test in `scripts/test_scripts.py` — Verified 2026-11-23: regression (scripts/echo_cartographer_regression.py: host PASS, simulator PASS with TEST_RUNNER_ECHO_CARTOGRAPHER_MEMORY_ISOLATED=1, footprint 28.13 -> 28.97 MB over 12 cycles, 0.86 MB growth within 16 MB) exit 0; EchoCartographerRegressionTests 5 script tests pass; CI step 'Echo Cartographer regression (host)' in round02-host-tests
  (agent D: host filter `EchoCartographerRegression`, then the simulator classes through `xcodebuild_package.py
  --only-testing` with the isolation variable, one summary line per part with pass or fail and the first failing name,
  a non-zero exit on any failure), and add the named step "Echo Cartographer regression (host)" to the
  `round02-host-tests` job of `.github/workflows/ci.yml`; `--name regression -- python3
  scripts/echo_cartographer_regression.py`

## Phase 6: Regression, documentation and close

- [X] T-R02G1108-007 Docs: `docs/architecture/echo-cartographer.md` (regression net), — Verified 2026-11-23: round02-host (swift test --package-path Packages/ExperiencesRound02) exit 0; architecture doc regression net, ExperiencesRound02 README feature 408, testing doc entry (cached host builds); validate_docs passes
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host`
- [X] T-R02G1108-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`, — Verified 2026-11-23: rendering-27, rendering-26, experiences, host-full, app-unit exit 0
  `--name host-full`, `--name app-unit`
- [X] T-R02G1108-009 Reference regression chunk 1 (`--name reference-1`) — Verified 2026-11-23: reference-1 exit 0
- [X] T-R02G1108-010 Reference regression chunk 2 (`--name reference-2`) — Verified 2026-11-23: reference-2 exit 0
- [X] T-R02G1108-011 Script tests, run alone (`--name script-tests`) — Verified 2026-11-23: script-tests exit 0
- [ ] T-R02G1108-012 {device} After ImplementationLock-100, on D1, D2 and D3: frame time and memory of the golden levels.
  Not run before the lock.
- [X] T-R02G1108-013 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record; — Verified 2026-11-23: converge appended nothing; README row and gate list updated
  README row and gate list updated

## Dependencies and parallel work

001 → {002 (agent A), 003 (lead) → 004 (agent B), 005 (agent C), 006 (agent D)} → 007 … 011, 013. 012 is a {device}
task outside this campaign. Agent A may start in an isolated copy before 001 (a new test file). Shared files (golden
source, release list, workflow, docs) stay with the lead. MVP: Story 1. Requirement coverage: FR-001/002 → 002;
FR-003/004 → 003, 004, 005; FR-005 → 005; FR-006 → 006; FR-007 → 002 … 006; FR-008 → 007 … 011.
