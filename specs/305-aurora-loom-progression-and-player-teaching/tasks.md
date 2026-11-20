# Tasks: R02-G01-05 — Aurora Loom: progression and player teaching

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G01-05 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G01-05 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_305;
tests stay short (< 10 s each). No {owner} or {device} tasks.

## Phase 1: Setup

- [X] T-R02G0105-001 Baselines: `--name baseline-host`, `--name baseline-timing`, `--name baseline-round02 -- swift test — Verified 2026-11-20: 2026-11-20 R02-G01-05.baseline-host/timing/round02 exit 0
  --package-path Packages/ExperiencesRound02`; the rendering baseline is R02-G01-04's rendering runs (exit 0)

## Phase 2: Stories 2 and 3 — hints and failure coaching (P1) 🎯

- [X] T-R02G0105-002 [P] [US2] [US3] Add `AuroraLoomSolver.solve(_:from:)` to `Packages/ExperiencesRound02/AuroraLoom/Core/AuroraLoomSolver.swift` and create — Verified 2026-11-20: 2026-11-20 R02-G01-05.host exit 0 (hints 5 tests incl. 2,000 states, solver/catalog/witness unchanged)
  `Packages/ExperiencesRound02/AuroraLoom/Core/AuroraLoomHints.swift` (AuroraLoomHint "levels 1 … 3: ribbon, + control, + step"; ties "most changes, then larger
  worst residual, then lower ribbon"; "no solution within the moves left" reported; AuroraLoomFailureExplanation from the
  kernel's failure) with `Packages/ExperiencesRound02/AuroraLoom/CoreTests/AuroraLoomHintsTests.swift` (2,000 seeded reachable states over all 100 levels: following
  the level-3 hint shortens the remaining shortest by one; levels 1 and 2 agree with level 3; no hint after the end; 500
  seeded failures explained exactly); `--name host -- swift test --package-path Packages/ExperiencesRound02 --filter
  AuroraLoomHintsTests`

## Phase 3: Stories 1 and 4 — tutorial, progress, daily, practice (P1, P2)

- [X] T-R02G0105-003 [P] [US1] [US4] Create `Packages/ExperiencesRound02/AuroraLoom/Core/AuroraLoomProgress.swift` (AuroraLoomTutorialStep "wave(r) → phase(r) → — Verified 2026-11-20: 2026-11-20 R02-G01-05.host-2 exit 0 (progress 11 tests)
  harmony → done"; AuroraLoomMode "campaign, practice, daily(level)"; AuroraLoomProgress "level 1 open; win in campaign opens
  the next; stars 3 at shortest, 2 within shortest + 2, else 1"; dailyLevel "(days from 2026-01-01 × 37) mod 100 + 1")
  with `Packages/ExperiencesRound02/AuroraLoom/CoreTests/AuroraLoomProgressTests.swift` (tutorial scripts on levels 1 … 3 win following each instruction; scripted
  progress through 100 levels; stars; every date 2026-01-01 … 2036-12-31 maps to 1 … 100; invalid dates refused; all 100 levels reachable by
  progress alone, with no purchase or other gate, FR-R02G0105-006);
  `--name host-2`

## Phase 4: Adapter, scenarios and panel

- [X] T-R02G0105-004 Edit `Packages/ExperiencesRound02/AuroraLoom/Core/AuroraLoomExperienceCore.swift` (controls "level.select [1…100], mode.daily [year, month, — Verified 2026-11-20: 2026-11-20 R02-G01-05.host-3 exit 0 (adapter 12 tests incl. conformance and migration; scenarios regenerated); catalog search 15 tests pass
  day], mode.practice, mode.campaign, tutorial.dismiss"; practice allowance 64; progress and mode in the digest (the tutorial step in the snapshot only, INV-05);
  snapshot schema 2 with a 1 → 2 migration; codes r02-g01.locked, r02-g01.date), `Packages/ExperiencesRound02/AuroraLoom/Core/AuroraLoomScenarios.swift` and the
  regenerated `Packages/ExperiencesRound02/AuroraLoom/scenario-manifest.json`, with
  `Packages/ExperiencesRound02/AuroraLoom/CoreTests/AuroraLoomExperienceCoreTests.swift` updates (conformance; actions; migration of a schema-1 payload);
  `--name host-3 -- swift test --package-path Packages/ExperiencesRound02 --filter
  'AuroraLoomExperienceCoreTests|AuroraLoomScenarios'`
- [X] T-R02G0105-005 Edit `Packages/ExperiencesRound02/AuroraLoom/Experience/AuroraLoomPresenter.swift` and `Packages/ExperiencesRound02/AuroraLoom/Experience/AuroraLoomControls.swift` (instruction line, Hint button — Verified 2026-11-20: 2026-11-20 R02-G01-05.sim-27-3 exit 0 (round-two sim suite incl. AuroraLoomTeachingTests 7 and gesture undo-digest; sim-27 compile error and sim-27-2 INV-05 failure fixed: tutorial step out of the digest, undo after failure rewinds)
  revealing the next hint level, failure explanation with undo and retry, level picker of open levels, Daily (local
  calendar date) / Practice / Campaign) and create `Packages/ExperiencesRound02/AuroraLoom/ExperienceTests/AuroraLoomTeachingTests.swift` (agent D: hint levels through the
  presenter, failure text, picker refusals, daily and practice through the port); `--name sim-27 -- python3
  scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package --destination
  sim-27.2 --action test`

## Phase 5: Regression, documentation and close

- [X] T-R02G0105-006 Docs: `docs/architecture/aurora-loom.md` (teaching and progress), `Packages/ExperiencesRound02/README.md`, — Verified 2026-11-20: 2026-11-20 R02-G01-05.round02-host exit 0, audits exit 0
  `docs/automatedtesting.md`; `--name round02-host`; `--name audits -- python3 scripts/verify_experiences.py --audits
  --only r02-g01.aurora-loom`
- [X] T-R02G0105-007 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`, — Verified 2026-11-20: 2026-11-20 rendering-27, rendering-26, experiences (sim-27.2), host-full, app-unit exit 0
  `--name host-full`, `--name app-unit`
- [X] T-R02G0105-008 Reference regression chunk 1 (`--name reference-1`) — Verified 2026-11-20: 2026-11-20 reference-1 exit 0
- [X] T-R02G0105-009 Reference regression chunk 2 (`--name reference-2`) — Verified 2026-11-20: 2026-11-20 reference-2 exit 0: 7 of 7 with chunk 1
- [X] T-R02G0105-010 Script tests, run alone (`--name script-tests`) — Verified 2026-11-20: 2026-11-20 script-tests exit 0, run alone
- [X] T-R02G0105-011 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record — Verified 2026-11-20: 2026-11-20 converge round 1 appended T-R02G0105-012 (tick in the failure text), implemented (host-4b); round 2 converged; sealed 20 passing checks, 2 failed attempts; recorded R02-G01-05 pass (.autonomy/migration/evidence/R02-G01-05.json); validators PASS

## Dependencies and parallel work

001 → {002 (agent B), 003 (agent C)} → 004 (lead) → 005 (lead; agent D writes the simulator tests) → 006 … 011.
Shared files (adapter, scenarios, presenter, controls, docs) stay with the lead. MVP: Stories 2 and 3.

## Phase 6: Convergence

- [X] T-R02G0105-012 Add the failure's tick to `AuroraLoomFailureExplanation.text` in `Packages/ExperiencesRound02/AuroraLoom/Core/AuroraLoomHints.swift` ("… at gate g, tick t: x of a turn outside the tolerance …") and its format test in `Packages/ExperiencesRound02/AuroraLoom/CoreTests/AuroraLoomHintsTests.swift`, per FR-R02G0105-003 (partial); `--name host-4 -- swift test --package-path Packages/ExperiencesRound02 --filter 'AuroraLoomHintsTests|AuroraLoomExperienceCoreTests'` — Verified 2026-11-20: 2026-11-20 R02-G01-05.host-4b exit 0 (explanation names the tick; hints and adapter tests)
