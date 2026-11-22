# Tasks: R02-G07-08 — Amethyst Escape: visual golden and solver regression

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G07-08 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G07-08 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_368;
tests stay short (< 10 s each); no wall-clock assertion.

## Phase 1: Setup

- [X] T-R02G0708-001 Baselines: `--name baseline-round02`, `--name baseline-host`, `--name baseline-timing` — Verified 2026-11-22: baseline-host, baseline-timing, baseline-round02 exit=0 (.autonomy/migration/checks/R02-G07-08.baseline-*.json)

## Phase 2: Story 1 — every level stays solvable as certified (P1) 🎯

- [X] T-R02G0708-002 [P] [US1] Create `Packages/ExperiencesRound02/AmethystEscape/CoreTests/AmethystEscapeRegressionSolverTests.swift` (agent A: for every — Verified 2026-11-22: host exit=0 (14 tests: 100 levels in ten groups replay, re-solve and work bound; twelve alterations named on levels 1 and 41)
  level in ten groups of 10, "the generated level equals its witness's level; the witness's actions replay to a win in
  exactly its smallest move count within the budget, with its per-move digests and fingerprints; solve returns exactly
  the witness's actions, smallest and depths, with work ≤ stateCount(level)"; twelve named alterations of clarification
  Q2 (a shell's aperture, a shell's wall, a blocked wedge, the sector count, the start sector, the budget; a solution
  action; a witness action, a per-move digest, a per-move fingerprint; the smallest move count; the depths) each fail
  naming the level and the part); `--name host -- swift test --package-path Packages/ExperiencesRound02 --filter
  AmethystEscapeRegressionSolverTests`

## Phase 3: Story 2 — the picture does not drift (P1)

- [X] T-R02G0708-003 [US2] Create `Packages/ExperiencesRound02/AmethystEscape/Core/AmethystEscapeGolden.swift` (DEBUG or VISUALCORE_AUTOMATION; "16 frames: — Verified 2026-11-22: AmethystEscapeGolden compiles in the round-two package; golden-frames.json written with AMETHYST_ESCAPE_WRITE_GOLDEN=1 (16 frames) and reproduced byte for byte; RELEASE_FORBIDDEN lists AmethystEscapeGolden
  levels 1, 21, 41, 61, 81 at tiers 0 … 2 at time 0 after the witness's first min(smallest − 1, 3) actions, plus the
  hero frame at tier 0; at 1,152 × 768 with the authored camera: the pearl centre, the exit arrow centre and every wedge
  top centre (wedge order), positions rounded to 1/8 px and an off-screen point null; the move count and the move bar's
  length rounded to 1/1,024; the backdrop, amethyst, highlight, platinum, blocked, pearl, exit and amber colours 8-bit
  sRGB; JSON with sorted keys; SHA-256"; manifest; compare with the one-quantum fallback and the pinned-digest
  self-check), generate `Packages/ExperiencesRound02/AmethystEscape/golden-frames.json` with
  `AMETHYST_ESCAPE_WRITE_GOLDEN=1`, and add `AmethystEscapeGolden` to `RELEASE_FORBIDDEN` in `scripts/release_check.py`
- [X] T-R02G0708-004 [P] [US2] Create `Packages/ExperiencesRound02/AmethystEscape/CoreTests/AmethystEscapeRegressionGoldenTests.swift` (agent B: every frame's — Verified 2026-11-22: host-2 exit=0 (9 tests: fixed set, contents, determinism, pinned match, digest self-check, missing/unreadable/renamed/unknown/schema, quantum moves, palette/moves/tier, hand edit)
  recomputed description matches its pinned one; each pinned digest equals the digest of its pinned description; a
  moved position beyond a quantum, a changed colour, a missing frame, an unknown frame, schema ≠ 1 and a hand-edited
  description all fail naming the frame; the file is rewritten only with the switch); `--name host-2 -- swift test
  --package-path Packages/ExperiencesRound02 --filter AmethystEscapeRegressionGoldenTests`

## Phase 4: Stories 2 and 3 — simulator frames and memory (P1, P2)

- [X] T-R02G0708-005 [US2] [US3] Edit `Packages/ExperiencesRound02/AmethystEscape/Experience/AmethystEscapeCrystalScene.swift` (`liveObjectCount`: GPU — Verified 2026-11-22: sim-27 exit=0 (AmethystEscapeExperienceTests on sim-27.2, 60 tests: 16 golden frames match their descriptions with the feature-363 checks; 12 memory cycles, liveObjectCount 0 after warning and close)
  objects held, 0 after release) and create
  `Packages/ExperiencesRound02/AmethystEscape/ExperienceTests/AmethystEscapeRegressionGoldenFrameTests.swift` and
  `Packages/ExperiencesRound02/AmethystEscape/ExperienceTests/AmethystEscapeRegressionMemoryTests.swift` (agent C: the
  16 frames rendered and checked against their descriptions with the feature-363 tolerances (the pearl centre within
  3 px of a pixel 0.15 brighter than the backdrop, the exit arrow at least 0.1 and every open wedge top at least 0.05
  away from the backdrop, the probe corners within 0.05 of the backdrop); 12 open-draw-warn-close cycles with
  `ProcessMemory.footprint()`, cycles 2 … 12 within 16 MB of cycle 1 when
  `TEST_RUNNER_AMETHYST_ESCAPE_MEMORY_ISOLATED=1`, readings printed otherwise; live GPU objects 0 after each close and
  warning; an unavailable footprint fails with a named reason); `--name sim-27 -- python3 scripts/xcodebuild_package.py
  --package Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package --destination sim-27.2 --action test
  --only-testing AmethystEscapeExperienceTests`

## Phase 5: Story 4 — the checks run on every change (P2)

- [X] T-R02G0708-006 [P] [US4] Create `scripts/amethyst_escape_regression.py` and its test in `scripts/test_scripts.py` — Verified 2026-11-22: regression exit=0 (scripts/amethyst_escape_regression.py: host filter 23 tests and simulator classes pass); AmethystEscapeRegressionTests 5/5 in test_scripts.py; CI step Amethyst Escape regression (host) added
  (agent D: host filter `AmethystEscapeRegression`, then the simulator classes through `xcodebuild_package.py
  --only-testing` with the isolation variable, one summary line per part with pass or fail and the first failing name,
  a non-zero exit on any failure), and add the named step "Amethyst Escape regression (host)" to
  `.github/workflows/ci.yml`; `--name regression -- python3 scripts/amethyst_escape_regression.py`

## Phase 6: Regression, documentation and close

- [X] T-R02G0708-007 Docs: `docs/architecture/amethyst-escape.md` (regression net), — Verified 2026-11-22: round02-host exit=0; docs/architecture/amethyst-escape.md regression net, ExperiencesRound02 README feature 368, docs/automatedtesting.md entry
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host`
- [X] T-R02G0708-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`, — Verified 2026-11-22: rendering-27, rendering-26, experiences, host-full, app-unit exit=0
  `--name host-full`, `--name app-unit`
- [X] T-R02G0708-009 Reference regression chunk 1 (`--name reference-1`) — Verified 2026-11-22: reference-1 exit=0
- [ ] T-R02G0708-010 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G0708-011 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G0708-012 {device} After ImplementationLock-100, on D1, D2 and D3: frame time and memory of the golden levels.
  Not run before the lock.
- [ ] T-R02G0708-013 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record

## Dependencies and parallel work

001 → {002 (agent A), 003 (lead) → 004 (agent B), 005 (lead + agent C), 006 (agent D)} → 007 … 011, 013. 012 is a
{device} task outside this campaign. Shared files (golden source, scene, release list, workflow, docs) stay with the
lead. MVP: Story 1.
