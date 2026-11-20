# Tasks: R02-G01-05 — Aurora Loom: progression and player teaching

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G01-05 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G01-05 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_305;
tests stay short (< 10 s each). No {owner} or {device} tasks.

## Phase 1: Setup

- [ ] T-R02G0105-001 Baselines: `--name baseline-host`, `--name baseline-timing`, `--name baseline-round02 -- swift test
  --package-path Packages/ExperiencesRound02`; the rendering baseline is R02-G01-04's rendering runs (exit 0)

## Phase 2: Stories 2 and 3 — hints and failure coaching (P1) 🎯

- [ ] T-R02G0105-002 [P] [US2] [US3] Add `AuroraLoomSolver.solve(_:from:)` to `Packages/ExperiencesRound02/AuroraLoom/Core/AuroraLoomSolver.swift` and create
  `Packages/ExperiencesRound02/AuroraLoom/Core/AuroraLoomHints.swift` (AuroraLoomHint "levels 1 … 3: ribbon, + control, + step"; ties "most changes, then larger
  worst residual, then lower ribbon"; "no solution within the moves left" reported; AuroraLoomFailureExplanation from the
  kernel's failure) with `Packages/ExperiencesRound02/AuroraLoom/CoreTests/AuroraLoomHintsTests.swift` (2,000 seeded reachable states over all 100 levels: following
  the level-3 hint shortens the remaining shortest by one; levels 1 and 2 agree with level 3; no hint after the end; 500
  seeded failures explained exactly); `--name host -- swift test --package-path Packages/ExperiencesRound02 --filter
  AuroraLoomHintsTests`

## Phase 3: Stories 1 and 4 — tutorial, progress, daily, practice (P1, P2)

- [ ] T-R02G0105-003 [P] [US1] [US4] Create `Packages/ExperiencesRound02/AuroraLoom/Core/AuroraLoomProgress.swift` (AuroraLoomTutorialStep "wave(r) → phase(r) →
  harmony → done"; AuroraLoomMode "campaign, practice, daily(level)"; AuroraLoomProgress "level 1 open; win in campaign opens
  the next; stars 3 at shortest, 2 within shortest + 2, else 1"; dailyLevel "(days from 2026-01-01 × 37) mod 100 + 1")
  with `Packages/ExperiencesRound02/AuroraLoom/CoreTests/AuroraLoomProgressTests.swift` (tutorial scripts on levels 1 … 3 win following each instruction; scripted
  progress through 100 levels; stars; every date 2026-01-01 … 2036-12-31 maps to 1 … 100; invalid dates refused; all 100 levels reachable by
  progress alone, with no purchase or other gate, FR-R02G0105-006);
  `--name host-2`

## Phase 4: Adapter, scenarios and panel

- [ ] T-R02G0105-004 Edit `Packages/ExperiencesRound02/AuroraLoom/Core/AuroraLoomExperienceCore.swift` (controls "level.select [1…100], mode.daily [year, month,
  day], mode.practice, mode.campaign, tutorial.dismiss"; practice allowance 64; progress, mode and tutorial in the digest;
  snapshot schema 2 with a 1 → 2 migration; codes r02-g01.locked, r02-g01.date), `Packages/ExperiencesRound02/AuroraLoom/Core/AuroraLoomScenarios.swift` and the
  regenerated `Packages/ExperiencesRound02/AuroraLoom/scenario-manifest.json`, with
  `Packages/ExperiencesRound02/AuroraLoom/CoreTests/AuroraLoomExperienceCoreTests.swift` updates (conformance; actions; migration of a schema-1 payload);
  `--name host-3 -- swift test --package-path Packages/ExperiencesRound02 --filter
  'AuroraLoomExperienceCoreTests|AuroraLoomScenarios'`
- [ ] T-R02G0105-005 Edit `Packages/ExperiencesRound02/AuroraLoom/Experience/AuroraLoomPresenter.swift` and `Packages/ExperiencesRound02/AuroraLoom/Experience/AuroraLoomControls.swift` (instruction line, Hint button
  revealing the next hint level, failure explanation with undo and retry, level picker of open levels, Daily (local
  calendar date) / Practice / Campaign) and create `Packages/ExperiencesRound02/AuroraLoom/ExperienceTests/AuroraLoomTeachingTests.swift` (agent D: hint levels through the
  presenter, failure text, picker refusals, daily and practice through the port); `--name sim-27 -- python3
  scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package --destination
  sim-27.2 --action test`

## Phase 5: Regression, documentation and close

- [ ] T-R02G0105-006 Docs: `docs/architecture/aurora-loom.md` (teaching and progress), `Packages/ExperiencesRound02/README.md`,
  `docs/automatedtesting.md`; `--name round02-host`; `--name audits -- python3 scripts/verify_experiences.py --audits
  --only r02-g01.aurora-loom`
- [ ] T-R02G0105-007 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`,
  `--name host-full`, `--name app-unit`
- [ ] T-R02G0105-008 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G0105-009 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G0105-010 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G0105-011 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record

## Dependencies and parallel work

001 → {002 (agent B), 003 (agent C)} → 004 (lead) → 005 (lead; agent D writes the simulator tests) → 006 … 011.
Shared files (adapter, scenarios, presenter, controls, docs) stay with the lead. MVP: Stories 2 and 3.
