# Tasks: R02-G13-08 — Acoustic Constellator: visual golden and solver regression

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/](contracts/), [quickstart.md](quickstart.md). Gate R02-G13-08 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G13-08 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_428;
tests stay short (< 10 s each); no wall-clock assertion.

## Phase 1: Setup

- [X] T-R02G1308-001 Baselines after R02-G13-07 is recorded: `--name baseline-host`, `--name baseline-timing`, `--name — Verified 2026-11-24: 2026-11-24: baseline-host, baseline-timing, baseline-round02 exit 0 on the R02-G13-07 record (.autonomy/migration/checks/R02-G13-08.baseline-*.json)
  baseline-round02 -- swift test --package-path Packages/ExperiencesRound02`

## Phase 2: Story 1 — every level stays solvable as certified (P1) 🎯

- [X] T-R02G1308-002 [P] [US1] Create `Packages/ExperiencesRound02/AcousticConstellator/CoreTests/AcousticConstellatorRegressionSolverTests.swift` (agent A: for every — Verified 2026-11-24: 2026-11-24: agent A solver regression (100 levels in ten groups: level identity, witness replay with per-action fingerprints and digests, exact re-plan with smaller sets and size, work within the bound; thirteen named alterations on levels 1, 41, 81), each test under 2.4 s; host exit 0 (.autonomy/migration/checks/R02-G13-08.host.json)
  level in ten groups of 10, "the generated level equals its witness's level (fingerprint); the witness's actions replay
  on a fresh play to a win in exactly its action count within the budget, with its per-action fingerprints and digests;
  plan returns exactly the witness's links and nudges with its smallerSets (the counterexample's sets) and size, with
  work ≤ workBound"; thirteen named alterations of clarification Q2 (a star's position, a star's rate, a star's starting
  phase, a fixed link, a symbol pair, the coupling, the threshold, the hold, the budget; a plan link or nudge; a witness
  action, a per-action fingerprint; the smaller-sets count) each fail naming the level and the part); `--name host -- swift test
  --package-path Packages/ExperiencesRound02 --filter AcousticConstellatorRegressionSolverTests`

## Phase 3: Story 2 — the picture does not drift (P1)

- [X] T-R02G1308-003 [US2] Create `Packages/ExperiencesRound02/AcousticConstellator/Core/AcousticConstellatorGolden.swift` (DEBUG or VISUALCORE_AUTOMATION; "16 frames: — Verified 2026-11-24: 2026-11-24: agent E AcousticConstellatorGolden (16 frames, code-only descriptions, SHA-256 via StableHash, one-quantum comparison, pinned-digest self-check, writer behind ACOUSTIC_CONSTELLATOR_WRITE_GOLDEN=1) and golden-frames.json (schema 1, written twice byte-identical); AcousticConstellatorGolden added to RELEASE_FORBIDDEN; the round-two package builds with tests; comparison proven by T-004
  levels 1, 21, 41, 61, 81 at tiers 0 … 2 at presentation time 0 after the witness's links and nudges and before its
  listen, plus the hero frame of `scenario-manifest.json` at tier 0; at 1,152 × 768 with the authored camera: every star
  centre and every link check point (index order), the first coherence bar, the first hold pip and the first moves bar,
  positions rounded to 1/8 px and an off-screen point null; the counts of stars, links, teal links at tick 0, guides, lit
  coherence bars, lit hold pips and lit and total moves bars; the sky, star, hand, silver, teal, guide, coherence lit and
  unlit, threshold mark, hold lit and unlit, moves lit and unlit colours 8-bit sRGB; JSON with
  sorted keys; SHA-256"; manifest; compare with the one-quantum fallback and the pinned-digest self-check), generate
  `Packages/ExperiencesRound02/AcousticConstellator/golden-frames.json` (schema 1) with `ACOUSTIC_CONSTELLATOR_WRITE_GOLDEN=1`, and
  add `AcousticConstellatorGolden` to `RELEASE_FORBIDDEN` in `scripts/release_check.py`
- [X] T-R02G1308-004 [P] [US2] Create `Packages/ExperiencesRound02/AcousticConstellator/CoreTests/AcousticConstellatorRegressionGoldenTests.swift` (agent B: every frame's — Verified 2026-11-24: 2026-11-24: agent B pinned-description tests (recompute, digest, moved/changed/missing/unknown/schema/hand-edit fail naming the frame, rewrite only with the switch); lead retest host-2 exit 0 (.autonomy/migration/checks/R02-G13-08.host-2.json)
  recomputed description matches its pinned one; each pinned digest equals the digest of its pinned description; a moved
  position beyond a quantum, a changed colour or count, a missing frame, an unknown frame, schema ≠ 1 and a hand-edited
  description all fail naming the frame; the file is rewritten only with the switch); `--name host-2 -- swift test
  --package-path Packages/ExperiencesRound02 --filter AcousticConstellatorRegressionGoldenTests`

## Phase 4: Stories 2 and 3 — simulator frames and memory (P1, P2)

- [X] T-R02G1308-005 [US2] [US3] Create `Packages/ExperiencesRound02/AcousticConstellator/ExperienceTests/AcousticConstellatorRegressionGoldenFrameTests.swift` and — Verified 2026-11-24: 2026-11-24: agent C 16 frames rendered and checked against their descriptions with the feature-423 tolerances, memory tests; lead fixed one #expect comment; sim-27 exit 0, 67 simulator tests (.autonomy/migration/checks/R02-G13-08.sim-27.json)
  `Packages/ExperiencesRound02/AcousticConstellator/ExperienceTests/AcousticConstellatorRegressionMemoryTests.swift` (agent C: the 16 frames rendered and checked
  against their descriptions with the feature-423 tolerances (star centres 0.15 from the sky in luminance with red, green
  and blue within 0.1, teal link check points 0.08 from the sky with green above red by 0.05, the first moves bar 0.1
  from the sky, the sky within 0.05, each point at least 6 px from other elements; points on screen where the description puts them);
  12 open-draw-warn-close cycles (prepare a level, 3 frames at tier 0, a memory warning, 1 frame, teardown) with
  `ProcessMemory.footprint()`, cycles 2 … 12 within 16 MB of cycle 1 when
  `TEST_RUNNER_ACOUSTIC_CONSTELLATOR_MEMORY_ISOLATED=1`, readings printed otherwise; the constellation scene's `liveObjectCount` 0
  after each close and warning and rebuilt by the next frame; an unavailable footprint fails with a named reason);
  `--name sim-27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme
  ExperiencesRound02-Package --destination sim-27.2 --action test --only-testing AcousticConstellatorExperienceTests`

## Phase 5: Story 4 — the checks run on every change (P2)

- [X] T-R02G1308-006 [P] [US4] Create `scripts/acoustic_constellator_regression.py` and its test in `scripts/test_scripts.py` — Verified 2026-11-24: 2026-11-24: agent D regression script (host filter then simulator classes, one summary line per part, non-zero on failure), 5 script tests, CI step 'Acoustic Constellator regression (host)'; regression exit 0 (.autonomy/migration/checks/R02-G13-08.regression.json)
  (agent D: host filter `AcousticConstellatorRegression`, then the simulator classes through `xcodebuild_package.py
  --only-testing` with the isolation variable, one summary line per part with pass or fail and the first failing name,
  a non-zero exit on any failure), and add the named step "Acoustic Constellator regression (host)" to the
  `round02-host-tests` job of `.github/workflows/ci.yml`; `--name regression -- python3
  scripts/acoustic_constellator_regression.py`

## Phase 6: Regression, documentation and close

- [ ] T-R02G1308-007 Docs: `docs/architecture/acoustic-constellator.md` (regression net),
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host`
- [ ] T-R02G1308-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`,
  `--name host-full`, `--name app-unit`
- [ ] T-R02G1308-009 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G1308-010 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G1308-011 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G1308-012 {device} After ImplementationLock-100, on D1, D2 and D3: frame time and memory of the golden levels.
  Not run before the lock.
- [ ] T-R02G1308-013 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record;
  README row and gate list updated

## Dependencies and parallel work

001 → {002 (agent A), 003 (lead) → 004 (agent B), 005 (agent C), 006 (agent D)} → 007 … 011, 013. 012 is a {device}
task outside this campaign. Agent A may start in an isolated copy before 001 (a new test file). Shared files (golden
source, release list, workflow, docs) stay with the lead. MVP: Story 1. Requirement coverage: FR-001/002 → 002;
FR-003/004 → 003, 004, 005; FR-005 → 005; FR-006 → 006; FR-007 → 002 … 006; FR-008 → 007 … 011.
