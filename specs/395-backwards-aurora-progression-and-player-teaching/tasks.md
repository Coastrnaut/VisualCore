# Tasks: R02-G10-05 — Backwards Aurora: progression and player teaching

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G10-05 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G10-05 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_395;
tests stay short (< 10 s each). No {owner} or {device} tasks. Model: feature 385's tasks.

## Phase 1: Setup

- [X] T-R02G1005-001 Baselines on the committed tree: `--name baseline-host`, `--name baseline-timing`, `--name — Verified 2026-11-23: baseline-host, baseline-timing, baseline-round02 exit=0 on the committed tree; rendering baseline is R02-G10-04's rendering runs (exit 0)
  baseline-round02 -- swift test --package-path Packages/ExperiencesRound02`; the rendering baseline is R02-G10-04's
  rendering runs (exit 0)

## Phase 2: Stories 2 and 3 — hints and failure explanation (P1) 🎯

- [X] T-R02G1005-002 [P] [US2] [US3] Add `solve(_:from:reversalsLeft:workBound:)` to — Verified 2026-11-23: host-2 exit=0 (51 tests: BackwardsAuroraHintsTests — following exact hints from the opening wins all 100 levels (max work 2,042), 200 seeded states get legal hints that win where a plan exists (24 found none within the 20,000 bound and say so, per Q1), 500 seeded failures explained; solver, invariant, witness and catalog suites unchanged; agent B's files retested by the lead in a combined copy, 168 Core tests)
  `Packages/ExperiencesRound02/BackwardsAurora/Core/BackwardsAuroraSolver.swift` (the certification's iterative deepening
  over reversible sections, pruned by the seam-count bound ⌈β / 4⌉, started at the given wave and looking for the fewest
  further reversals that win within the reversals left; work bound 20,000 reversals evaluated; `solve(_:workBound:)`
  unchanged) and create `Packages/ExperiencesRound02/BackwardsAurora/Core/BackwardsAuroraHints.swift`
  (`BackwardsAuroraPlan`, `BackwardsAuroraHintKind` reverse/stuck, `BackwardsAuroraHint` with levels 1 … 3 and the texts
  of clarification Q1 — "Reverse a section of n samples", "… starting at sample i", "Reverse samples i to j"; stuck "No
  way to fold the aurora back was found in the reversals left: undo the last reversal or retry the level."; failed play
  "Undo the last reversal or retry the level."; won play nil — `BackwardsAuroraHints.plan`/`hint`,
  `BackwardsAuroraFailureExplanation` with the tear and budget texts of clarification Q5, each followed by "Undo the last
  reversal or retry the level.") with
  `Packages/ExperiencesRound02/BackwardsAurora/CoreTests/BackwardsAuroraHintsTests.swift` (following exact hints from
  the opening wins all 100 certified levels within their budgets, in parallel groups under 10 s each; 200 seeded
  reachable states (seed 2_395): every exact hint is a legal reversal, from every state with a plan following hints wins;
  500 seeded failures explained with their true reason, reversal and counts; a hint never changes the play); agent B;
  `--name host-2`

## Phase 3: Stories 1 and 4 — tutorial and progress (P1, P2)

- [X] T-R02G1005-003 [P] [US1] [US4] Create `Packages/ExperiencesRound02/BackwardsAurora/Core/BackwardsAuroraProgress.swift` — Verified 2026-11-23: host-3 exit=0 (BackwardsAuroraProgressTests 12: tutorial steps on levels 1-3 incl. a detour reaching finish, undo and redo never move the step back, stars by reversals made, a 100-level progress script, every day of 2026-2036 maps into 1-100 and is stable, negative day counts wrap, impossible dates refused, Codable round trips; agent C's files retested by the lead)
  (`BackwardsAuroraTutorialStep` mark → reverse → finish → done with the texts of clarification Q2, advanced only by an
  accepted reversal or the level's end, never moved back by undo; `BackwardsAuroraProgress` "3 when at most the certified
  smallest reversal count, 2 when at most that + 2, else 1" by reversals made (reversal records, undone ones included),
  frontier with level 1 open, best reversals made per level, a better result replacing a worse one;
  `dailyLevel(year:month:day:)` "(days from 2026-01-01 × 73) mod 100 + 1, negative day counts wrapped", nil for an
  impossible date; `BackwardsAuroraMode` campaign, practice, daily(level)) with
  `Packages/ExperiencesRound02/BackwardsAurora/CoreTests/BackwardsAuroraProgressTests.swift` (tutorial steps on levels
  1 … 3 by scripted plays; stars and frontier over a 100-level script; every date 2026-01-01 … 2036-12-31 gives a level in
  1 … 100, stable; impossible dates nil; Codable round trips); agent C; `--name host-3`

## Phase 4: Adapter, scenarios, presenter

- [X] T-R02G1005-004 Edit `Packages/ExperiencesRound02/BackwardsAurora/Core/BackwardsAuroraExperienceCore.swift` (controls — Verified 2026-11-23: host-4 exit=0 (174 Backwards Aurora host tests: adapter controls level.select, mode.daily, mode.practice, mode.campaign, tutorial.dismiss with r02-g10.locked and r02-g10.date, practice budget 40, campaign win opens the next level with stars, daily records without unlocking, schema 2 round trip and migration from schema 1, schema 3 refused, digest carries progress and mode but not the tutorial; scenario manifest regenerated)
  `level.select [1 … 100]`, `mode.daily [year, month, day]`, `mode.practice`, `mode.campaign`, `tutorial.dismiss`; codes
  `r02-g10.locked`, `r02-g10.date`; practice budget 40 on a copy of the level, no stars, no unlocks; a daily win records
  the level's best result and stars and opens nothing; progress and mode in the digest, the tutorial step snapshotted
  but not digested; snapshot schema 2 `{level, records, progress, mode, tutorial}` with a migration from 1 "level 1 open
  plus the restored level, campaign mode, tutorial at its first step on tutorial levels"; `level.next` to the next open
  level, refused with `r02-g10.locked` when none; no level is ever gated by payment — locked means not yet unlocked
  (FR-R02G1005-006)) with tests in
  `Packages/ExperiencesRound02/BackwardsAurora/CoreTests/BackwardsAuroraExperienceCoreTests.swift` (new controls,
  refusals, schema 2 round trip, migration from a schema-1 payload, newer schema refused); regenerate
  `Packages/ExperiencesRound02/BackwardsAurora/Core/BackwardsAuroraScenarios.swift` entries where needed and
  `Packages/ExperiencesRound02/BackwardsAurora/scenario-manifest.json` (`UPDATE_SCENARIO_MANIFEST=1`); lead; `--name
  host-4 -- swift test --package-path Packages/ExperiencesRound02 --filter BackwardsAurora`
- [X] T-R02G1005-005 Edit `Packages/ExperiencesRound02/BackwardsAurora/Experience/BackwardsAuroraPresenter.swift` (the — Verified 2026-11-23: sim-27 exit=0 (39 simulator tests incl. BackwardsAuroraTeachingTests 5: tutorial shown and dismissed, three hint levels equal the Core's and following them wins level 1, a budget failure explained with Undo and Retry, a campaign win records stars with band and goal and opens the next level with a locked level refused, practice, daily and campaign modes; identity test lists nine controls; the fallback test reads the failure explanation; hint search off the main actor, stale search owns nothing; agent D's tests retested by the lead)
  tutorial instruction, the hint at its current level — "Hint" raises the level 1 → 2 → 3, any play change resets it,
  the search off the main actor and a stale search never owning the hint state — and the failure explanation as panel
  text, with the level's difficulty band (of the five bands of 20), its goal and its best stars (FR-R02G1005-004); the
  description includes them) and
  `Packages/ExperiencesRound02/BackwardsAurora/Experience/BackwardsAuroraControls.swift` (Hint, Dismiss tutorial, level
  picker for open levels, Practice, Daily (today's local date from the presenter), Campaign); agent D writes
  `Packages/ExperiencesRound02/BackwardsAurora/ExperienceTests/BackwardsAuroraTeachingTests.swift` (the panel shows the
  tutorial, the three hint levels, the failure text, the band and the stars; mode and level controls reach the adapter); `--name sim-27 --
  python3 scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package
  --destination sim-27.2 --action test --only-testing BackwardsAuroraExperienceTests`

## Phase 5: Regression, documentation and close

- [X] T-R02G1005-006 Docs: `docs/architecture/backwards-aurora.md` (teaching and progression), — Verified 2026-11-23: round02-host (swift test --package-path Packages/ExperiencesRound02) exit 0; docs/architecture/backwards-aurora.md teaching and progression, ExperiencesRound02 README feature 395, docs/automatedtesting.md entry; validate_docs passes
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host`
- [X] T-R02G1005-007 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`, — Verified 2026-11-23: rendering-27, rendering-26, experiences, host-full, app-unit exit=0
  `--name host-full`, `--name app-unit`
- [X] T-R02G1005-008 Reference regression chunk 1 (`--name reference-1`) — Verified 2026-11-23: reference-1 exit=0
- [X] T-R02G1005-009 Reference regression chunk 2 (`--name reference-2`) — Verified 2026-11-23: reference-2 exit=0
- [X] T-R02G1005-010 Script tests, run alone (`--name script-tests`) — Verified 2026-11-23: script-tests exit=0 (run alone)
- [ ] T-R02G1005-011 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record;
  README row and gate list updated

## Dependencies and parallel work

001 → {002 (agent B), 003 (agent C)} → 004 (lead) → 005 (lead; agent D writes the teaching tests) → 006 … 011. Shared
files (adapter, scenarios, presenter, controls, docs) stay with the lead. MVP: Stories 1–3 (tutorial, hints, failure
text); Story 4 (progress, daily, practice) follows in the same gate.
