# Tasks: R02-G10-08 — Backwards Aurora: visual golden and solver regression

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G10-08 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G10-08 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_398;
tests stay short (< 10 s each); no wall-clock assertion.

## Phase 1: Setup

- [X] T-R02G1008-001 Baselines: `--name baseline-round02`, `--name baseline-host`, `--name baseline-timing` — Verified 2026-11-23: baseline-round02, baseline-host, baseline-timing exit=0 on the committed tree

## Phase 2: Story 1 — every level stays solvable as certified (P1) 🎯

- [X] T-R02G1008-002 [P] [US1] Create `Packages/ExperiencesRound02/BackwardsAurora/CoreTests/BackwardsAuroraRegressionSolverTests.swift` (agent A: for every — Verified 2026-11-23: host exit=0 (BackwardsAuroraRegressionSolverTests 14 tests, 112 cases: 100 levels in ten groups equal their witnesses, replay their reversals with the per-reversal digests and fingerprints to a win in exactly the smallest count within the budget, and re-solve to exactly the witness's reversals with smallest equal to the lower bound's and work at most 20,000 (max 2,042, level 91); the ten alterations of Q2 each fail naming the level and the part; agent A's file retested by the lead)
  level in ten groups of 10, "the generated level equals its witness's level; the witness's reversals replay to a win
  in exactly its smallest reversal count within the budget, with its per-reversal digests and fingerprints; solve returns
  exactly the witness's reversals with smallest equal to the witness's and to the lower bound's, with work ≤ workBound"; ten named
  alterations of clarification Q2 (a target sample, a checkpoint, the budget, the bend limit, the breaking limit; a
  solution reversal; a witness reversal, a per-reversal digest, a per-reversal fingerprint; the smallest reversal count) each fail naming
  the level and the part); `--name host -- swift test --package-path Packages/ExperiencesRound02 --filter
  BackwardsAuroraRegressionSolverTests`

## Phase 3: Story 2 — the picture does not drift (P1)

- [X] T-R02G1008-003 [US2] Create `Packages/ExperiencesRound02/BackwardsAurora/Core/BackwardsAuroraGolden.swift` (DEBUG or VISUALCORE_AUTOMATION; "16 frames: — Verified 2026-11-23: golden exit=0 (BackwardsAuroraGolden: 16 frames, levels 1, 21, 41, 61, 81 at tiers 0-2 after min(smallest - 1, 2) certified reversals plus the hero frame, described at 1,152 x 768 with ribbon sample points and ring centres in 1/8 px, kinks, tear, spent, budget, tier detail and ten palette colours, SHA-256; golden-frames.json generated with BACKWARDS_AURORA_WRITE_GOLDEN=1; the invariant scan lists the golden source as presentation; BackwardsAuroraGolden added to RELEASE_FORBIDDEN in scripts/release_check.py)
  levels 1, 21, 41, 61, 81 at tiers 0 … 2 at time 0 after the witness's first min(smallest − 1, 2) reversals, plus the
  hero frame at tier 0; at 1,152 × 768 with the authored camera: every ribbon sample point (wave order) and checkpoint
  ring centre (checkpoint order), positions rounded to 1/8 px and an off-screen point null; the kink count; the tear
  seam or null; the reversals spent and the budget; the ground, band, ribbon, ghost, ring, matched, kink, tear, spent and
  unspent colours 8-bit sRGB; JSON with
  sorted keys; SHA-256"; manifest; compare with the one-quantum fallback and the pinned-digest self-check), generate
  `Packages/ExperiencesRound02/BackwardsAurora/golden-frames.json` with `BACKWARDS_AURORA_WRITE_GOLDEN=1`, and add `BackwardsAuroraGolden` to
  `RELEASE_FORBIDDEN` in `scripts/release_check.py`
- [ ] T-R02G1008-004 [P] [US2] Create `Packages/ExperiencesRound02/BackwardsAurora/CoreTests/BackwardsAuroraRegressionGoldenTests.swift` (agent B: every frame's
  recomputed description matches its pinned one; each pinned digest equals the digest of its pinned description; a
  moved position beyond a quantum, a changed colour or count, a missing frame, an unknown frame, schema ≠ 1 and a
  hand-edited description all fail naming the frame; the file is rewritten only with the switch); `--name host-2 --
  swift test --package-path Packages/ExperiencesRound02 --filter BackwardsAuroraRegressionGoldenTests`

## Phase 4: Stories 2 and 3 — simulator frames and memory (P1, P2)

- [ ] T-R02G1008-005 [US2] [US3] Create `Packages/ExperiencesRound02/BackwardsAurora/ExperienceTests/BackwardsAuroraRegressionGoldenFrameTests.swift` and
  `Packages/ExperiencesRound02/BackwardsAurora/ExperienceTests/BackwardsAuroraRegressionMemoryTests.swift` (agent C: the 16 frames rendered and checked against
  their descriptions with the feature-393 tolerances (sample points away from the markers within 3 px of a ribbon pixel
  0.15 cooler and 0.15 from the ground, ghost points near a lilac pixel 0.1 from the ground, the first gauge bar at least
  0.1 from the ground, the probe corners within 0.05 of the ground; sample points and ring centres on screen where the
  description puts them); 12 open-draw-warn-close cycles with `ProcessMemory.footprint()`, cycles 2 … 12 within 16 MB
  of cycle 1 when `TEST_RUNNER_BACKWARDS_AURORA_MEMORY_ISOLATED=1`, readings printed otherwise; the aurora scene's
  `liveObjectCount` 0 after each close and warning; an unavailable footprint fails with a named reason); `--name
  sim-27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme
  ExperiencesRound02-Package --destination sim-27.2 --action test --only-testing BackwardsAuroraExperienceTests`

## Phase 5: Story 4 — the checks run on every change (P2)

- [ ] T-R02G1008-006 [P] [US4] Create `scripts/backwards_aurora_regression.py` and its test in `scripts/test_scripts.py`
  (agent D: host filter `BackwardsAuroraRegression`, then the simulator classes through `xcodebuild_package.py
  --only-testing` with the isolation variable, one summary line per part with pass or fail and the first failing name,
  a non-zero exit on any failure), and add the named step "Backwards Aurora regression (host)" to
  `.github/workflows/ci.yml`; `--name regression -- python3 scripts/backwards_aurora_regression.py`

## Phase 6: Regression, documentation and close

- [ ] T-R02G1008-007 Docs: `docs/architecture/backwards-aurora.md` (regression net),
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host`
- [ ] T-R02G1008-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`,
  `--name host-full`, `--name app-unit`
- [ ] T-R02G1008-009 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G1008-010 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G1008-011 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G1008-012 {device} After ImplementationLock-100, on D1, D2 and D3: frame time and memory of the golden levels.
  Not run before the lock.
- [ ] T-R02G1008-013 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record

## Dependencies and parallel work

001 → {002 (agent A), 003 (lead) → 004 (agent B), 005 (agent C), 006 (agent D)} → 007 … 011, 013. 012 is a {device}
task outside this campaign. Shared files (golden source, release list, workflow, docs) stay with the lead. MVP: Story 1.
Requirement coverage: FR-001/002 → 002; FR-003/004 → 003, 004, 005; FR-005 → 005; FR-006 → 006; FR-007 → 002 … 006;
FR-008 → 007 … 011.
