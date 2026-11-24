# Tasks: R02-G14-08 — Moonlit Mechanism: visual golden and solver regression

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/](contracts/), [quickstart.md](quickstart.md). Gate R02-G14-08 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G14-08 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_438;
tests stay short (< 10 s each); no wall-clock assertion.

## Phase 1: Setup

- [X] T-R02G1408-001 Baselines after R02-G14-07 is recorded: `--name baseline-host`, `--name baseline-timing`, `--name — Verified 2026-11-24: 2026-11-24: baseline-host, baseline-timing, baseline-round02 exit 0 on 7eaa21fe7 (.autonomy/migration/checks/R02-G14-08.baseline-*.json)
  baseline-round02 -- swift test --package-path Packages/ExperiencesRound02`

## Phase 2: Story 1 — every level stays solvable as certified (P1) 🎯

- [X] T-R02G1408-002 [P] [US1] Create `Packages/ExperiencesRound02/MoonlitMechanism/CoreTests/MoonlitMechanismRegressionSolverTests.swift` (agent A: for every — Verified 2026-11-24: 2026-11-24: agent A solver regression, 15 tests (ten groups of 10 levels, 13 named alterations); lead retest host exit 0 (.autonomy/migration/checks/R02-G14-08.host.json)
  level in ten groups of 10, "the generated level equals its witness's level (fingerprint); the witness's actions replay
  on a fresh play to a win in exactly its action count within the budget, with its per-action fingerprints and digests;
  plan returns exactly the witness's turns, lamp steps and re-seats with its smallerVectors (the sum of the
  counterexample's vector counts over norms 0 … its norm = plan size − 1) and norm, with work ≤ workBound"; thirteen named alterations of clarification Q2 (a gear's tooth count, a
  gear's centre, a gear's depth, a gear's starting phase, a slot table offset, the lamp's starting height, a key frame's
  target cell, a forbidden cell, the budget; a plan component; a witness action, a per-action fingerprint; the
  smaller-vectors count) each fail naming the level and the part); `--name host -- swift test
  --package-path Packages/ExperiencesRound02 --filter MoonlitMechanismRegressionSolverTests`

## Phase 3: Story 2 — the picture does not drift (P1)

- [X] T-R02G1408-003 [US2] Create `Packages/ExperiencesRound02/MoonlitMechanism/Core/MoonlitMechanismGolden.swift` (DEBUG or VISUALCORE_AUTOMATION; "16 frames: — Verified 2026-11-24: 2026-11-24: golden source (16 frames, pip = alignLit), golden-frames.json written with MOONLIT_MECHANISM_WRITE_GOLDEN=1 (sha256 accecae0…), MoonlitMechanismGolden in RELEASE_FORBIDDEN; host-2 exit 0 (.autonomy/migration/checks/R02-G14-08.host-2.json)
  levels 1, 21, 41, 61, 81 at tiers 0 … 2 at presentation time 0 after the witness's turns, re-seats and lamp steps and
  before its run, key frame 0 shown, plus the hero frame of `scenario-manifest.json` at tier 0; at 1,152 × 768 with the
  authored camera: every cast-cell centre, every gear centre and rim check point, every key-frame card centre (index
  order), the first alignment pip, the lamp centre and the first moves bar, positions rounded to 1/8 px and a point
  behind the eye null; the counts of gears, cast cells, target cells, missing and stray cells, forbidden cells, lit
  cards, aligned pips and lit and total moves bars; the night, paper, ink, gear, rim, blade, lamp, card lit and unlit,
  pip, moves lit and unlit and broken colours 8-bit sRGB; JSON with
  sorted keys; SHA-256"; manifest; compare with the one-quantum fallback and the pinned-digest self-check), generate
  `Packages/ExperiencesRound02/MoonlitMechanism/golden-frames.json` (schema 1) with `MOONLIT_MECHANISM_WRITE_GOLDEN=1`, and
  add `MoonlitMechanismGolden` to `RELEASE_FORBIDDEN` in `scripts/release_check.py`
- [X] T-R02G1408-004 [P] [US2] Create `Packages/ExperiencesRound02/MoonlitMechanism/CoreTests/MoonlitMechanismRegressionGoldenTests.swift` (agent B: every frame's — Verified 2026-11-24: 2026-11-24: agent B golden host tests, 10 tests; lead retest host-2 exit 0 (.autonomy/migration/checks/R02-G14-08.host-2.json)
  recomputed description matches its pinned one; each pinned digest equals the digest of its pinned description; a moved
  position beyond a quantum, a changed colour or count, a missing frame, an unknown frame, schema ≠ 1 and a hand-edited
  description all fail naming the frame; the file is rewritten only with the switch); `--name host-2 -- swift test
  --package-path Packages/ExperiencesRound02 --filter MoonlitMechanismRegressionGoldenTests`

## Phase 4: Stories 2 and 3 — simulator frames and memory (P1, P2)

- [X] T-R02G1408-005 [US2] [US3] Create `Packages/ExperiencesRound02/MoonlitMechanism/ExperienceTests/MoonlitMechanismRegressionGoldenFrameTests.swift` and — Verified 2026-11-24: 2026-11-24: agent C golden-frame and memory simulator tests; lead retest sim-27 exit 0, 64 tests (.autonomy/migration/checks/R02-G14-08.sim-27.json)
  `Packages/ExperiencesRound02/MoonlitMechanism/ExperienceTests/MoonlitMechanismRegressionMemoryTests.swift` (agent C: the 16 frames rendered and checked
  against their descriptions with the feature-433 tolerances (a cast cell's centre 0.25 darker than the paper in
  luminance, a gear rim point with red above blue by 0.08, the first moves bar 0.1 from the paper, the backdrop within
  0.05 of night, each point at least 6 px from what is drawn over it; points on screen where the description puts them);
  12 open-draw-warn-close cycles (prepare a level, 3 frames at tier 0, a memory warning, 1 frame, teardown) with
  `ProcessMemory.footprint()`, cycles 2 … 12 within 16 MB of cycle 1 when
  `TEST_RUNNER_MOONLIT_MECHANISM_MEMORY_ISOLATED=1`, readings printed otherwise; the clockwork scene's `liveObjectCount` 0
  after each close and warning and rebuilt by the next frame; an unavailable footprint fails with a named reason);
  `--name sim-27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme
  ExperiencesRound02-Package --destination sim-27.2 --action test --only-testing MoonlitMechanismExperienceTests`

## Phase 5: Story 4 — the checks run on every change (P2)

- [X] T-R02G1408-006 [P] [US4] Create `scripts/moonlit_mechanism_regression.py` and its test in `scripts/test_scripts.py` — Verified 2026-11-24: 2026-11-24: agent D regression script, 5 script tests, CI step 'Moonlit Mechanism regression (host)'; lead retest regression exit 0 (host and simulator PASS, memory 28.4 to 29.0 MB over 12 isolated cycles) (.autonomy/migration/checks/R02-G14-08.regression.json)
  (agent D: host filter `MoonlitMechanismRegression`, then the simulator classes through `xcodebuild_package.py
  --only-testing` with the isolation variable, one summary line per part with pass or fail and the first failing name,
  a non-zero exit on any failure), and add the named step "Moonlit Mechanism regression (host)" to the
  `round02-host-tests` job of `.github/workflows/ci.yml`; `--name regression -- python3
  scripts/moonlit_mechanism_regression.py`

## Phase 6: Regression, documentation and close

- [X] T-R02G1408-007 Docs: `docs/architecture/moonlit-mechanism.md` (regression net), — Verified 2026-11-24: 2026-11-24: architecture regression-net section, ExperiencesRound02 README, testing doc (smallerVectors lesson); round02-host exit 0 (.autonomy/migration/checks/R02-G14-08.round02-host.json)
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host`
- [X] T-R02G1408-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`, — Verified 2026-11-24: 2026-11-24: rendering-27, rendering-26, experiences, host-full, app-unit exit 0 (.autonomy/migration/checks/R02-G14-08.{rendering-27,rendering-26,experiences,host-full,app-unit}.json)
  `--name host-full`, `--name app-unit`
- [X] T-R02G1408-009 Reference regression chunk 1 (`--name reference-1`) — Verified 2026-11-24: 2026-11-24: reference-1 exit 0 (.autonomy/migration/checks/R02-G14-08.reference-1.json)
- [ ] T-R02G1408-010 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G1408-011 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G1408-012 {device} After ImplementationLock-100, on D1, D2 and D3: frame time and memory of the golden levels.
  Not run before the lock.
- [ ] T-R02G1408-013 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record;
  README row and gate list updated

## Dependencies and parallel work

001 → {002 (agent A), 003 (lead) → 004 (agent B), 005 (agent C), 006 (agent D)} → 007 … 011, 013. 012 is a {device}
task outside this campaign. Agent A may start in an isolated copy before 001 (a new test file). Shared files (golden
source, release list, workflow, docs) stay with the lead. MVP: Story 1. Requirement coverage: FR-001/002 → 002;
FR-003/004 → 003, 004, 005; FR-005 → 005; FR-006 → 006; FR-007 → 002 … 006; FR-008 → 007 … 011.
