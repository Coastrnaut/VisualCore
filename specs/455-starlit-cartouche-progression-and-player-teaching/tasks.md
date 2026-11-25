# Tasks: R02-G16-05 — Starlit Cartouche: progression and player teaching

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G16-05 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G16-05 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_455;
tests stay short (< 10 s each). No {owner} tasks. Lessons taken into the first pass: refusal codes may carry the
engine's `action.rule.` prefix; the teaching-test agent gets the presenter's exact texts; round02-host is split in three
by filter.

## Phase 1: Setup

- [X] T-R02G1605-001 Baselines on the committed tree after R02-G16-04 is recorded: `--name baseline-host`, `--name — Verified 2026-11-24: baseline-host, baseline-timing, baseline-round02-1..3 exit 0 (.autonomy/migration/checks/R02-G16-05.baseline-*.json)
  baseline-timing`, `--name baseline-round02-1 … 3` (the three round-two filters of feature 446); the rendering
  baseline is R02-G16-04's rendering runs (exit 0)

## Phase 2: Stories 2 and 3 — hints and failure explanation (P1) 🎯

- [X] T-R02G1605-002 [P] [US2] [US3] Add `plan(_:from:beat:drawn:maxLegs:workBound:)` to — Verified 2026-11-24: host-2 exit 0 (.autonomy/migration/checks/R02-G16-05.host-2.json); solver entry from a state (plan(_:) unchanged), hints at three levels, six failure explanations; exact hints win all 100 levels, 200 seeded states, 500 seeded failures
  `Packages/ExperiencesRound02/StarlitCartouche/Core/StarlitCartoucheSolver.swift` (the breadth-first search of
  `plan(_:maxLegs:workBound:)` from the given star, beat and drawn strokes — corridors by index from the ship's star,
  waits 0 … 8, legs the chart refuses or fails skipped; `plan(_:)` unchanged and equal to `plan(level, from:
  level.start, beat: 0, drawn: [])`; nil for an unknown star or a state that already wins) and create
  `Packages/ExperiencesRound02/StarlitCartouche/Core/StarlitCartoucheHints.swift` (`StarlitCartoucheHintPlan`,
  `StarlitCartoucheHintKind` leg/stuck, `StarlitCartoucheHint` with levels 1 … 3 and the texts of clarification Q1 —
  "The next leg flies corridor c, between star a and star b", "Fly to star j", "Fly to star j after waiting w beats"
  (1 beat singular); stuck "No way to win was found in the actions left: undo the last action or retry the level.";
  failed play "Undo the last action or retry the level."; won play nil — the plan is the minimal plan from the play's
  current star, beat and drawn strokes, and nil unless its legs fit the actions left (and within the work bound);
  `StarlitCartoucheHints.plan`/`hint`; `StarlitCartoucheFailureExplanation` with the texts of clarification Q5 for
  `departure`, `hazard`, `arrival`, `deadline`, `stroke` and `budget`, actions numbered from 1, stars, corridors and
  hazards by index, followed by "Undo the last action or retry the level.") with
  `Packages/ExperiencesRound02/StarlitCartouche/CoreTests/StarlitCartoucheHintsTests.swift` (following exact hints from
  the opening wins all 100 certified levels within their budget, in groups under 10 s each; 200 seeded reachable states
  (seed 2_455): every exact hint is accepted by the kernel; 500 seeded failures explained with their true action and
  values; a hint never changes the play; `plan(_:)` equals the new entry at the start on all 100 levels); agent B;
  `--name host-2`

## Phase 3: Stories 1 and 4 — tutorial and progress (P1, P2)

- [X] T-R02G1605-003 [P] [US1] [US4] Create — Verified 2026-11-24: host-3 exit 0 (.autonomy/migration/checks/R02-G16-05.host-3.json); tutorial steps, progress and stars, daily × 37 over 2026–2036, modes, Codable; 16 tests
  `Packages/ExperiencesRound02/StarlitCartouche/Core/StarlitCartoucheProgress.swift` (`StarlitCartoucheTutorialStep`
  fly → symbol → recover → done with the texts of clarification Q2, advanced by an accepted leg (fly → symbol, symbol
  → recover) or the level's end (→ done), never moved back by undo — an undo passes `afterLeg: false` and the play's
  real end, a redo that restores a won or failed play ends it; `StarlitCartoucheProgress` "3 when at most the certified
  witness's leg count, 2 when at most that + 2, else 1" by actions spent (every accepted leg record, undone ones
  included), frontier with level 1 open, best actions spent per level, a better result replacing a worse one;
  `dailyLevel(year:month:day:)` "(days from 2026-01-01 × 37) mod 100 + 1, negative day counts wrapped", nil for an
  impossible date; `StarlitCartoucheMode` campaign, practice, daily(level)) with
  `Packages/ExperiencesRound02/StarlitCartouche/CoreTests/StarlitCartoucheProgressTests.swift` (tutorial steps on
  levels 1 … 3 by scripted plays following the witnesses; stars and frontier over a 100-level script; every date
  2026-01-01 … 2036-12-31 gives a level in 1 … 100, stable; impossible dates nil; Codable round trips); agent C;
  `--name host-3`

## Phase 4: Adapter, scenarios, presenter

- [X] T-R02G1605-004 Edit `Packages/ExperiencesRound02/StarlitCartouche/Core/StarlitCartoucheExperienceCore.swift` — Verified 2026-11-24: host-4 exit 0 (.autonomy/migration/checks/R02-G16-05.host-4.json); adapter controls level.select, mode.daily, mode.practice, mode.campaign, tutorial.dismiss, codes locked/date, schema 2 with migration from 1, v2 digest with progress and mode; scenarios (integration rows win before level.next) and manifest regenerated; identity test and registry comment follow
  (controls `level.select [1 … 100]`, `mode.daily [year, month, day]`, `mode.practice`, `mode.campaign`,
  `tutorial.dismiss`; codes `r02-g16.locked`, `r02-g16.date`; practice budget 24 on a copy of the level, no stars, no
  unlocks; the daily level is playable even while still locked in the campaign, and a daily win records the level's best
  result and stars and opens nothing; progress and mode in the digest, the tutorial step snapshotted but not digested,
  the chosen destination and wait unchanged (presentation); snapshot schema 2 `{level, mode, progress, records,
  tutorial}` with a migration from 1 "level 1 open plus the restored level, campaign mode, tutorial at its first step on
  tutorial levels"; `level.next` to the next open level, refused with `r02-g16.locked` when none; no level is ever gated
  by payment — locked means not yet unlocked (FR-R02G1605-006)) with tests in
  `Packages/ExperiencesRound02/StarlitCartouche/CoreTests/StarlitCartoucheExperienceCoreTests.swift` (new controls,
  refusals, a locked daily level played without opening it, schema 2 round trip, migration from a schema-1 payload,
  newer schema refused); update `Packages/ExperiencesRound02/StarlitCartouche/Core/StarlitCartoucheScenarios.swift`
  where the new controls and the `level.next` rule change expectations and regenerate
  `Packages/ExperiencesRound02/StarlitCartouche/scenario-manifest.json` (`UPDATE_SCENARIO_MANIFEST=1`); update
  `StarlitCartouchePanelWinTests`, the gesture wiring tests and other suites whose `level.next` expectation changes;
  lead; `--name host-4 -- swift test --package-path Packages/ExperiencesRound02 --filter StarlitCartouche`
- [X] T-R02G1605-005 Edit `Packages/ExperiencesRound02/StarlitCartouche/Experience/StarlitCartouchePresenter.swift` (the — Verified 2026-11-24: sim-27 exit 0, 41 simulator tests incl. 6 teaching tests (.autonomy/migration/checks/R02-G16-05.sim-27.json; sim-27a exit 0 before them); presenter tutorial, hints off the main actor, failure explanation, goal, stars, modes, retry and daily from the local date; panel rows
  tutorial instruction, the hint at its current level — "Hint" raises the level 1 → 2 → 3, any play change resets it,
  the search off the main actor and a stale search never owning the hint state — and the failure explanation as panel
  text, with the level's difficulty band (of the five bands of 20), its goal and its best stars (FR-R02G1605-004); the
  description includes them) and
  `Packages/ExperiencesRound02/StarlitCartouche/Experience/StarlitCartoucheControls.swift` (Hint, Dismiss tutorial,
  level picker for open levels, Practice, Daily (today's local date from the presenter), Campaign); agent D writes
  `Packages/ExperiencesRound02/StarlitCartouche/ExperienceTests/StarlitCartoucheTeachingTests.swift` (the panel shows
  the tutorial, the three hint levels, the failure text, the band and the stars; mode and level controls reach the
  adapter; a refusal reads in words), given the presenter's exact texts; `--name sim-27 -- python3
  scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package --destination
  sim-27.2 --action test --only-testing StarlitCartoucheExperienceTests`

## Phase 5: Regression, documentation and close

- [X] T-R02G1605-006 Docs: `docs/architecture/starlit-cartouche.md` (teaching and progression), — Verified 2026-11-24: round02-host-1..3 exit 0 (.autonomy/migration/checks/R02-G16-05.round02-host-*.json; chunk 3 330.628 s); architecture, package README and testing doc updated
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host-1 … 3`
- [X] T-R02G1605-007 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`, — Verified 2026-11-24: rendering-27, rendering-26, experiences, host-full, app-unit exit 0 (.autonomy/migration/checks/R02-G16-05.*.json)
  `--name host-full`, `--name app-unit`
- [ ] T-R02G1605-008 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G1605-009 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G1605-010 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G1605-011 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record;
  README row and gate list updated

## Dependencies and parallel work

001 → {002 (agent B), 003 (agent C)} → 004 (lead) → 005 (lead; agent D writes the teaching tests) → 006 … 010, 011.
Agents may draft in isolated copies before 001 (new files only). Requirement coverage: FR-001 → 003, 005; FR-002 → 002,
005; FR-003 → 002, 005; FR-004 → 003, 004, 005; FR-005 → 003, 004; FR-006 → 004; FR-007 → 004, 006 … 010.
