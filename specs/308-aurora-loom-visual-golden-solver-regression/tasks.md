# Tasks: R02-G01-08 — Aurora Loom: visual golden and solver regression

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G01-08 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G01-08 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_308
(no new randomness); tests stay short (< 10 s each). No {owner} tasks.

## Phase 1: Setup

- [ ] T-R02G0108-001 Baselines: `--name baseline-host`, `--name baseline-timing`, `--name baseline-round02 -- swift test
  --package-path Packages/ExperiencesRound02`; the rendering baseline is R02-G03-01's rendering runs (exit 0)

## Phase 2: Foundational

- [ ] T-R02G0108-002 Create `Packages/ExperiencesRound02/AuroraLoom/Core/AuroraLoomGolden.swift` (contracts/api.md: "16 frames: levels 1, 21, 41, 61, 81 at
  tiers 0, 1, 2, time 0, plus the hero frame"; description JSON with sorted keys at 768 × 512, positions in 1/8 pixel,
  colours 0 … 255; SHA-256 digests; `manifest()` "{schema 1, frames: name → {description, digest}}"; `compare` "equal
  digest, or positions within one 1/8-pixel quantum and equal colours") and edit
  `Packages/ExperiencesRound02/AuroraLoom/Experience/AuroraLoomRibbonScene.swift` (`liveObjectCount`: programs and buffers held, 0 after `release()`);
  `--name host -- swift test --package-path Packages/ExperiencesRound02`

## Phase 3: Story 1 — every level stays solvable (P1) 🎯

- [ ] T-R02G0108-003 [P] [US1] Create `Packages/ExperiencesRound02/AuroraLoom/CoreTests/AuroraLoomRegressionSolverTests.swift` (agent A: per band, 20 levels each:
  generated level equals its witness's level, witness replays to a win in exactly its moves, `solve` returns exactly
  the certified shortest with winning moves and "work ≤ 3,840"; the twelve alterations of clarification Q2 each detected
  and named); `--name host-2 -- swift test --package-path Packages/ExperiencesRound02 --filter AuroraLoomRegressionSolverTests`

## Phase 4: Story 2 — the picture does not drift (P1)

- [ ] T-R02G0108-004 [P] [US2] Create `Packages/ExperiencesRound02/AuroraLoom/CoreTests/AuroraLoomRegressionGoldenTests.swift` (agent B: 16 frames; descriptions
  deterministic; each equals its pinned entry in `Packages/ExperiencesRound02/AuroraLoom/golden-frames.json` (equal digest, or positions within one 1/8-pixel quantum and equal colours; a position moved by two quanta fails naming the frame); the file rewritten only with `AURORA_LOOM_WRITE_GOLDEN=1`; a
  missing, unreadable or incomplete manifest fails naming the file and frame; a moved camera, a changed palette colour
  and a changed tier each change the affected digests); the lead generates and commits `Packages/ExperiencesRound02/AuroraLoom/golden-frames.json`;
  `--name host-3 -- swift test --package-path Packages/ExperiencesRound02 --filter AuroraLoomRegressionGoldenTests`
- [ ] T-R02G0108-005 [P] [US2] Create `Packages/ExperiencesRound02/AuroraLoom/ExperienceTests/AuroraLoomRegressionGoldenFrameTests.swift` (agent C: each of the 16
  frames rendered off-screen at 768 × 512 through the session host and checked against its description: positions within
  2 px, colours within 0.12 per channel, background within 0.05 of night); `--name sim-27 -- python3
  scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package --destination
  sim-27.2 --action test`

## Phase 5: Story 3 — memory stays bounded (P2)

- [ ] T-R02G0108-006 [US3] Create `Packages/ExperiencesRound02/AuroraLoom/ExperienceTests/AuroraLoomRegressionMemoryTests.swift` (agent C: 12 cycles of open, 3
  frames, memory warning, 1 frame, close; `ProcessMemory.footprint()` after each; "every reading of cycles 2 … 12 within
  16 MB of cycle 1"; `liveObjectCount` 0 after each close and warning and > 0 after the next frame; an unavailable
  footprint fails named); runs in `--name sim-27`

## Phase 6: Story 4 — the checks run on every change (P2)

- [ ] T-R02G0108-007 [P] [US4] Create `scripts/aurora_loom_regression.py` (agent D: host filter `AuroraLoomRegression`,
  then `xcodebuild_package.py --only-testing` of the two simulator classes with `--max-seconds`; one summary line per
  part; non-zero exit on any failure; `--dry-run` prints the commands) with its tests in `scripts/test_scripts.py`;
  the lead adds the named step "Aurora Loom regression (host)" to `.github/workflows/ci.yml`; `--name script-tests`
  (alone) and `--name regression -- python3 scripts/aurora_loom_regression.py`

## Phase 7: Regression, documentation and close

- [ ] T-R02G0108-008 Docs: `docs/architecture/aurora-loom.md` (regression), `Packages/ExperiencesRound02/README.md`,
  `docs/automatedtesting.md`; `--name round02-host`
- [ ] T-R02G0108-009 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`,
  `--name host-full`, `--name app-unit`
- [ ] T-R02G0108-010 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G0108-011 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G0108-012 {device} After ImplementationLock-100: frame time and memory per tier on D1/D2/D3 (SC-R02G0108-007)
- [ ] T-R02G0108-013 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record;
  after the record push, check its CI run with `gh run list` and fix any failure before the next gate (SC-R02G0108-005)

## Dependencies and parallel work

001 → 002 (lead) → {003 (agent A), 004 (agent B), 005 and 006 (agent C), 007 (agent D)} → 008 … 011, 013. 012 stays
open until device testing. Shared files (golden source, scene, golden-frames.json, ci.yml, docs) stay with the lead.
MVP: Stories 1 and 2.
