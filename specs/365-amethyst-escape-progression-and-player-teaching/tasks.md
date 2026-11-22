# Tasks: R02-G07-05 — Amethyst Escape: progression and player teaching

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G07-05 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G07-05 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_365;
tests stay short (< 10 s each). No {owner} or {device} tasks (no device-only behaviour in this feature).

## Phase 1: Setup

- [X] T-R02G0705-001 Baselines: `--name baseline-host`, `--name baseline-timing`, `--name baseline-round02 -- swift test — Verified 2026-11-22: 2026-11-22: baseline-host, baseline-timing, baseline-round02 exit 0; rendering baseline = R02-G07-04 rendering-27/26 exit 0
  --package-path Packages/ExperiencesRound02`; the rendering baseline is R02-G07-04's rendering runs (exit 0)

## Phase 2: Stories 2 and 3 — hints and failure explanation (P1) 🎯

- [X] T-R02G0705-002 [P] [US2] [US3] Add `solve(_:from:maxDepth:)` to `Packages/ExperiencesRound02/AmethystEscape/Core/AmethystEscapeSolver.swift` (the same — Verified 2026-11-22: 2026-11-22: host-2 (HintsTests 19 cases: exact hints win all 100 levels in the certified count, 200 seeded states vs an independent search, 500 failures; plus Catalog/Solver/Witness/Generator unchanged with the solver's new entry point) exit 0, lead retest
  packed breadth-first search started at a given crystal; `solve(_:maxDepth:)` equals it from the opening crystal) and
  create `Packages/ExperiencesRound02/AmethystEscape/Core/AmethystEscapeHints.swift` (`AmethystEscapePlan`, `AmethystEscapeHint` with levels 1 … 3 and the texts
  of clarification Q1, `AmethystEscapeHints.plan`/`hint`, `AmethystEscapeFailureExplanation` with the texts of
  clarification Q5) with `Packages/ExperiencesRound02/AmethystEscape/CoreTests/AmethystEscapeHintsTests.swift` (following exact hints from the opening wins all
  100 certified levels; 200 seeded reachable states (seed 2_365): every exact hint is a legal action, from every state
  with a plan following hints wins, a state without a plan has no escape in the moves left by an independent search;
  500 seeded failures explained with their true reason, shell, sector and move; a hint never changes the play); agent B;
  `--name host-2`

## Phase 3: Stories 1 and 4 — tutorial and progress (P1, P2)

- [X] T-R02G0705-003 [P] [US1] [US4] Create `Packages/ExperiencesRound02/AmethystEscape/Core/AmethystEscapeProgress.swift` (`AmethystEscapeTutorialStep` turn → — Verified 2026-11-22: 2026-11-22: host-3 (ProgressTests, 9 tests: tutorial on levels 1-3, stars and frontier over 100 levels, daily for 4,018 dates, impossible dates, Codable) exit 0, lead retest
  advance → escape → done with the texts of clarification Q2; `AmethystEscapeProgress` "3 when at most the certified
  smallest move count, 2 when at most that + 2, else 1", frontier, best moves; `dailyLevel(year:month:day:)` "(days
  from 2026-01-01 × 61) mod 100 + 1, negative day counts wrapped", nil for an impossible date; `AmethystEscapeMode`
  campaign, practice, daily(level)) with `Packages/ExperiencesRound02/AmethystEscape/CoreTests/AmethystEscapeProgressTests.swift` (tutorial steps on levels
  1 … 3 by scripted plays; stars and frontier over a 100-level script; every date 2026-01-01 … 2036-12-31 gives a level
  in 1 … 100, stable; impossible dates nil); agent C; `--name host-3`

## Phase 4: Adapter, scenarios, presenter

- [X] T-R02G0705-004 Edit `Packages/ExperiencesRound02/AmethystEscape/Core/AmethystEscapeExperienceCore.swift` (controls `level.select [1 … 100]`, `mode.daily [year, — Verified 2026-11-22: 2026-11-22: host-4 (swift test --filter AmethystEscape: adapter controls, refusals, schema 2 round trip, migration from schema 1, newer schema refused, wins and stars, regenerated manifest) exit 0, lead retest
  month, day]`, `mode.practice`, `mode.campaign`, `tutorial.dismiss`; codes `r02-g07.locked`, `r02-g07.date`; practice
  budget 60, no stars, no unlocks; daily opens nothing; progress and mode in the digest, the tutorial step snapshotted
  but not digested; snapshot schema 2 `{level, records, progress, mode, tutorial}` with a migration from 1 "level 1
  open plus the restored level, campaign mode, tutorial at its first step on tutorial levels"; `level.next` to the next
  open level) with tests in `Packages/ExperiencesRound02/AmethystEscape/CoreTests/AmethystEscapeExperienceCoreTests.swift` (new controls, refusals, schema 2
  round trip, migration from a schema-1 payload, newer schema refused); regenerate
  `Packages/ExperiencesRound02/AmethystEscape/Core/AmethystEscapeScenarios.swift` entries where needed and `Packages/ExperiencesRound02/AmethystEscape/scenario-manifest.json`
  (`UPDATE_SCENARIO_MANIFEST=1`); lead; `--name host-4 -- swift test --package-path Packages/ExperiencesRound02 --filter
  AmethystEscape`
- [ ] T-R02G0705-005 Edit `Packages/ExperiencesRound02/AmethystEscape/Experience/AmethystEscapePresenter.swift` (the tutorial instruction, the hint at its current
  level — "Hint" raises the level 1 → 2 → 3, any play change resets it — and the failure explanation as panel text; the
  description includes them) and `Packages/ExperiencesRound02/AmethystEscape/Experience/AmethystEscapeControls.swift` (Hint, Dismiss tutorial, level picker for
  open levels, Practice, Daily (today's local date from the presenter), Campaign); agent D writes
  `Packages/ExperiencesRound02/AmethystEscape/ExperienceTests/AmethystEscapeTeachingTests.swift` (the panel shows the tutorial, the three hint levels and the
  failure text; mode and level controls reach the adapter); `--name sim-27 -- python3 scripts/xcodebuild_package.py
  --package Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package --destination sim-27.2 --action test
  --only-testing AmethystEscapeExperienceTests`

## Phase 5: Regression, documentation and close

- [ ] T-R02G0705-006 Docs: `docs/architecture/amethyst-escape.md` (teaching and progression),
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host`
- [ ] T-R02G0705-007 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`,
  `--name host-full`, `--name app-unit`
- [ ] T-R02G0705-008 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G0705-009 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G0705-010 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G0705-011 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record

## Dependencies and parallel work

001 → {002 (agent B), 003 (agent C)} → 004 (lead) → 005 (lead; agent D writes the teaching tests) → 006 … 011. Shared
files (adapter, scenarios, presenter, controls, docs) stay with the lead. MVP: Stories 1–3.
