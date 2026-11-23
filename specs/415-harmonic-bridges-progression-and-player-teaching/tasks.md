# Tasks: R02-G12-05 — Harmonic Bridges: progression and player teaching

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G12-05 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G12-05 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_415;
tests stay short (< 10 s each). No {owner} or {device} tasks. Model: feature 405's tasks.

## Phase 1: Setup

- [ ] T-R02G1205-001 Baselines on the committed tree after R02-G12-04 is recorded: `--name baseline-host`, `--name
  baseline-timing`, `--name baseline-round02 -- swift test --package-path Packages/ExperiencesRound02`; the rendering
  baseline is R02-G12-04's rendering runs (exit 0)

## Phase 2: Stories 2 and 3 — hints and failure explanation (P1) 🎯

- [ ] T-R02G1205-002 [P] [US2] [US3] Add `plan(_:pegs:workBound:)` to
  `Packages/ExperiencesRound02/HarmonicBridges/Core/HarmonicBridgesSolver.swift` (the minimal-plan search of
  `plan(_:workBound:)` run on the level with every string at the given peg, locks kept; `plan(_:workBound:)` unchanged
  and equal to `plan(_:pegs:)` at the starting pegs) and create
  `Packages/ExperiencesRound02/HarmonicBridges/Core/HarmonicBridgesHints.swift` (`HarmonicBridgesHintPlan`,
  `HarmonicBridgesHintKind` tune/test/stuck, `HarmonicBridgesHint` with levels 1 … 3 and the texts of clarification Q1 —
  "Tune a string so that more steps are bridged", "Tune string i", "Tune string i to peg p"; "Every step is bridged:
  test the crossing", "Test the crossing: tap the goal or a step pip" (levels 2 and 3); stuck "No way to win was found
  in the moves left: undo the last action or retry the level."; failed play "Undo the last action or retry the level.";
  won play nil — the plan is the test when the current pegs join the start to the goal in every step, else the minimal
  plan's tunings in string order then the test, and nil unless those actions fit the actions left (and within the work
  bound); `HarmonicBridgesHints.plan`/`hint`; `HarmonicBridgesFailureExplanation` with the texts of clarification Q5 for
  a broken test (with and without a string) and for the exhausted budget (after a tuning or a test), actions numbered
  from 1 and steps and strings from 0, followed by "Undo the last action or retry the level.") with
  `Packages/ExperiencesRound02/HarmonicBridges/CoreTests/HarmonicBridgesHintsTests.swift` (following exact hints from the
  opening wins all 100 certified levels within their budget, in parallel groups under 10 s each; 200 seeded reachable
  states (seed 2_415): every exact hint is accepted by the kernel; 500 seeded failures explained with their true action
  and counts; a hint never changes the play); agent B; `--name host-2`

## Phase 3: Stories 1 and 4 — tutorial and progress (P1, P2)

- [ ] T-R02G1205-003 [P] [US1] [US4] Create
  `Packages/ExperiencesRound02/HarmonicBridges/Core/HarmonicBridgesProgress.swift` (`HarmonicBridgesTutorialStep`
  tune → bridge → test → done with the texts of clarification Q2, advanced by an accepted tuning (tune → bridge, and on
  to test at once when that tuning already bridges every step), the pegs bridging every step (bridge → test) or the
  level's end (→ done), never moved back by undo; `HarmonicBridgesProgress` "3 when at most the certified witness's
  action count, 2 when at most that + 2, else 1" by actions spent (every accepted tuning and test record, undone ones
  included), frontier with level 1 open, best actions spent per level, a better result replacing a worse one;
  `dailyLevel(year:month:day:)` "(days from 2026-01-01 × 83) mod 100 + 1, negative day counts wrapped", nil for an
  impossible date; `HarmonicBridgesMode` campaign, practice, daily(level)) with
  `Packages/ExperiencesRound02/HarmonicBridges/CoreTests/HarmonicBridgesProgressTests.swift` (tutorial steps on levels
  1 … 3 by scripted plays; stars and frontier over a 100-level script; every date 2026-01-01 … 2036-12-31 gives a level
  in 1 … 100, stable; impossible dates nil; Codable round trips); agent C; `--name host-3`

## Phase 4: Adapter, scenarios, presenter

- [ ] T-R02G1205-004 Edit `Packages/ExperiencesRound02/HarmonicBridges/Core/HarmonicBridgesExperienceCore.swift`
  (controls `level.select [1 … 100]`, `mode.daily [year, month, day]`, `mode.practice`, `mode.campaign`,
  `tutorial.dismiss`; codes `r02-g12.locked`, `r02-g12.date`; practice budget 60 on a copy of the level, no stars, no
  unlocks; a daily win records the level's best result and stars and opens nothing; progress and mode in the digest,
  the tutorial step snapshotted but not digested; snapshot schema 2 `{level, mode, progress, records, tutorial}` with a
  migration from 1 "level 1 open plus the restored level, campaign mode, tutorial at its first step on tutorial levels";
  `level.next` to the next open level, refused with `r02-g12.locked` when none; no level is ever gated by payment —
  locked means not yet unlocked (FR-R02G1205-006)) with tests in
  `Packages/ExperiencesRound02/HarmonicBridges/CoreTests/HarmonicBridgesExperienceCoreTests.swift` (new controls,
  refusals, schema 2 round trip, migration from a schema-1 payload, newer schema refused); update
  `Packages/ExperiencesRound02/HarmonicBridges/Core/HarmonicBridgesScenarios.swift` where the new controls and the
  `level.next` rule change expectations and regenerate `Packages/ExperiencesRound02/HarmonicBridges/scenario-manifest.json`
  (`UPDATE_SCENARIO_MANIFEST=1`); update `HarmonicBridgesPanelWinTests` and other suites whose `level.next` expectation
  changes; lead; `--name host-4 -- swift test --package-path Packages/ExperiencesRound02 --filter HarmonicBridgesCoreTests`
- [ ] T-R02G1205-005 Edit `Packages/ExperiencesRound02/HarmonicBridges/Experience/HarmonicBridgesPresenter.swift` (the
  tutorial instruction, the hint at its current level — "Hint" raises the level 1 → 2 → 3, any play change resets it,
  the search off the main actor and a stale search never owning the hint state — and the failure explanation as panel
  text, with the level's difficulty band (of the five bands of 20), its goal and its best stars (FR-R02G1205-004); the
  description includes them) and `Packages/ExperiencesRound02/HarmonicBridges/Experience/HarmonicBridgesControls.swift`
  (Hint, Dismiss tutorial, level picker for open levels, Practice, Daily (today's local date from the presenter),
  Campaign); agent D writes `Packages/ExperiencesRound02/HarmonicBridges/ExperienceTests/HarmonicBridgesTeachingTests.swift`
  (the panel shows the tutorial, the three hint levels, the failure text, the band and the stars; mode and level
  controls reach the adapter; a refusal reads in words); `--name sim-27 -- python3 scripts/xcodebuild_package.py
  --package Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package --destination sim-27.2 --action test
  --only-testing HarmonicBridgesExperienceTests`

## Phase 5: Regression, documentation and close

- [ ] T-R02G1205-006 Docs: `docs/architecture/harmonic-bridges.md` (teaching and progression),
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host`
- [ ] T-R02G1205-007 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`,
  `--name host-full`, `--name app-unit`
- [ ] T-R02G1205-008 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G1205-009 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G1205-010 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G1205-011 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record;
  README row and gate list updated

## Dependencies and parallel work

001 → {002 (agent B), 003 (agent C)} → 004 (lead) → 005 (lead; agent D writes the teaching tests) → 006 … 011. Shared
files (adapter, scenarios, presenter, controls, docs) stay with the lead. Agents B and C may start in isolated copies
before 001, since their files are new or untouched by R02-G12-04 (the solver is untouched there). MVP: Stories 1–3
(tutorial, hints, failure text); Story 4 (progress, daily, practice) follows in the same gate.
