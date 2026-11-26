# Tasks: R02-G18-05 — Apsides Workshop: progression and player teaching

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G18-05 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G18-05 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_475;
tests stay short (< 10 s each). No {owner} or {device} tasks (the spec names no device-only item; the round's device
campaign covers the game).

## Phase 1: Setup

- [X] T-R02G1805-001 Baselines on the committed tree after R02-G18-04 is recorded: `--name baseline-host`, `--name — Verified 2026-11-25: 2026-11-25 baseline-host, baseline-timing, baseline-round02-1, -2, -3c, -3e, -3f exit 0 on the committed R02-G18-04 record; rendering baseline is R02-G18-04's rendering runs
  baseline-timing`, `--name baseline-round02-1`, `-2`, `-3c`, `-3e`, `-3f`; the rendering baseline is R02-G18-04's
  rendering runs (exit 0)

## Phase 2: Stories 2 and 3 — hints and failure explanation (P1) 🎯

- [X] T-R02G1805-002 [P] [US2] [US3] Add `plan(_:from:maxTunings:workBound:)` to — Verified 2026-11-25: 2026-11-25 ApsidesWorkshopSolver.plan(_:from:maxTunings:workBound:) (plan(_:) equal to it at the opening on all 100 levels, witnesses unchanged), ApsidesWorkshopHints (three levels, play, failed and stuck texts) and ApsidesWorkshopFailureExplanation (five failure kinds in the level's words); ApsidesWorkshopHintsTests (exact hints win all 100, 200 seeded states accepted, 500 seeded failures explained); host-2 exit 0 (ApsidesWorkshopCoreTests)
  `Packages/ExperiencesRound02/ApsidesWorkshop/Core/ApsidesWorkshopSolver.swift` (the search of `plan(_:workBound:)`
  from the given orbit — the valid orbits differing in one lever, then in both, in the existing order; `plan(_:)`
  unchanged in result, proof and work and equal to `plan(level, from: level.orbit)`; a plan of no tunings when the given
  orbit already wins; nil for an invalid orbit or when the work bound is exceeded) and create
  `Packages/ExperiencesRound02/ApsidesWorkshop/Core/ApsidesWorkshopHints.swift` (`ApsidesWorkshopHintPlan`,
  `ApsidesWorkshopHintKind` tune/play/stuck, `ApsidesWorkshopHint` with levels 1 … 3 and the texts of clarification Q1 —
  "Turn the periapsis knob next" or "Change the size next"; "Raise the eccentricity by n steps and turn the periapsis m
  steps counterclockwise" (or "Lower", "clockwise"; 1 step singular; the shorter turn, counterclockwise on a tie;
  unchanged parts left out) or "Grow the orbit by n units" (or "Shrink"; 1 unit singular); "Set the periapsis to
  eccentricity k, direction d°" or "Set the size to a"; already winning "Every target reads in its band: play the
  revolution"; stuck "No way to win was found in the actions left: undo the last action or retry the level."; failed
  play "Undo the last action or retry the level."; won play nil — the plan is the minimal plan from the play's current
  orbit within min(actions left, 2) tunings and the work bound; `ApsidesWorkshopHints.plan`/`hint`;
  `ApsidesWorkshopFailureExplanation` with the texts of clarification Q5 for `contact`, `order`, `share`, `apsisSector`
  and `apsisDistance`, targets numbered from 1, planets, sectors, shares and distances in the level's words, followed by
  "Undo the last action or retry the level.") with
  `Packages/ExperiencesRound02/ApsidesWorkshop/CoreTests/ApsidesWorkshopHintsTests.swift` (following exact hints from
  the opening, then the play, wins all 100 certified levels within their budget, in groups under 10 s each; 200 seeded
  reachable states (seed 2_475): every exact hint is accepted by the kernel; 500 seeded failures explained with their
  true planet or target, tick and reading; a hint never changes the play; `plan(_:)` equals the new entry at the opening
  on all 100 levels); agent B; `--name host-2`

## Phase 3: Stories 1 and 4 — tutorial and progress (P1, P2)

- [X] T-R02G1805-003 [P] [US1] [US4] Create — Verified 2026-11-25: 2026-11-25 ApsidesWorkshopProgress (tutorial steps knob/order/recover/done with the Q2 texts, stars 3/2/1, frontier, daily x 23, modes, practice budget 24, Codable) and ApsidesWorkshopProgressTests (17 tests: 100-level script, tutorial walks, daily over 2026 ... 2036 and 100 consecutive days, impossible dates); host-3 exit 0
  `Packages/ExperiencesRound02/ApsidesWorkshop/Core/ApsidesWorkshopProgress.swift` (`ApsidesWorkshopTutorialStep` knob →
  order → recover → done with the texts of clarification Q2, advanced by an accepted tuning (knob → order, order →
  recover) or the level's end (→ done), never moved back by undo — an undo passes `afterTuning: false` and the play's
  real end, a redo that restores a won or failed play ends it; `ApsidesWorkshopProgress` "3 when at most the certified
  witness's tuning count, 2 when at most that + 2, else 1" by actions spent (every accepted tuning record, undone ones
  included), frontier with level 1 open, best actions spent per level, a better result replacing a worse one;
  `dailyLevel(year:month:day:)` "(days from 2026-01-01 × 23) mod 100 + 1, negative day counts wrapped", nil for an
  impossible date; `ApsidesWorkshopMode` campaign, practice, daily(level)) with
  `Packages/ExperiencesRound02/ApsidesWorkshop/CoreTests/ApsidesWorkshopProgressTests.swift` (tutorial steps on levels 1
  … 3 by scripted plays following the witnesses; stars and frontier over a 100-level script; every date 2026-01-01 …
  2036-12-31 gives a level in 1 … 100, stable; impossible dates nil; Codable round trips); agent C; `--name host-3`

## Phase 4: Adapter, scenarios, presenter

- [X] T-R02G1805-004 Edit `Packages/ExperiencesRound02/ApsidesWorkshop/Core/ApsidesWorkshopExperienceCore.swift` — Verified 2026-11-25: 2026-11-25 adapter: level.select, mode.daily, mode.practice, mode.campaign, tutorial.dismiss; r02-g18.locked and r02-g18.date; practice budget 24; progress and mode digested (r02-g18.apsides-workshop.v2), tutorial snapshotted; schema 2 with migration from 1; level.next to the next open level; scenarios and regenerated manifest; ApsidesWorkshopProgressionCoreTests (10); host-4 exit 0 (ApsidesWorkshop filter, 194 tests)
  (controls `level.select [1 … 100]`, `mode.daily [year, month, day]`, `mode.practice`, `mode.campaign`,
  `tutorial.dismiss`; codes `r02-g18.locked`, `r02-g18.date`; practice budget 24 on a copy of the level, no stars, no
  unlocks; the daily level is playable even while still locked in the campaign, and a daily win records the level's best
  result and stars and opens nothing; progress and mode in the digest, the tutorial step snapshotted but not digested,
  the shown tick unchanged (presentation); snapshot schema 2 `{level, mode, progress, records, tutorial}` with a
  migration from 1 "level 1 open plus the restored level, campaign mode, tutorial at its first step on tutorial levels";
  `level.next` to the next open level, refused with `r02-g18.locked` when none; no level is ever gated by payment —
  locked means not yet unlocked (FR-R02G1805-006)) with tests in
  `Packages/ExperiencesRound02/ApsidesWorkshop/CoreTests/ApsidesWorkshopExperienceCoreTests.swift` (new controls,
  refusals, a locked daily level played without opening it, schema 2 round trip, migration from a schema-1 payload,
  newer schema refused); update `Packages/ExperiencesRound02/ApsidesWorkshop/Core/ApsidesWorkshopScenarios.swift` where
  the new controls and the `level.next` rule change expectations and regenerate
  `Packages/ExperiencesRound02/ApsidesWorkshop/scenario-manifest.json` (`UPDATE_SCENARIO_MANIFEST=1`); update
  `ApsidesWorkshopPanelWinTests`, the gesture wiring tests and other suites whose `level.next` expectation changes;
  lead; `--name host-4 -- swift test --package-path Packages/ExperiencesRound02 --filter ApsidesWorkshop`
- [X] T-R02G1805-005 Edit `Packages/ExperiencesRound02/ApsidesWorkshop/Experience/ApsidesWorkshopPresenter.swift` (the — Verified 2026-11-25: 2026-11-25 presenter: tutorial from the core's step, hint levels 1 to 3 searched off the main actor (stale searches dropped), failure explanation, band, goal (targets and 3-star tuning count), best stars, modes, locked and date refusals in words; panel: Hint, Dismiss tutorial, level picker, Play level, Campaign, Daily, Practice; ApsidesWorkshopTeachingTests (10); registry comment schema 2; sim-27 exit 0 (ApsidesWorkshopExperienceTests, 47 tests)
  tutorial instruction, the hint at its current level — "Hint" raises the level 1 → 2 → 3, any play change resets it,
  the search off the main actor and a stale search never owning the hint state — and the failure explanation as panel
  text, replacing the mirror's own failure words, with the level's difficulty band (of the five bands of 20), its goal
  (the targets in words and the tuning count that earns 3 stars, the certified witness's) and its best stars
  (FR-R02G1805-004); the description includes them) and
  `Packages/ExperiencesRound02/ApsidesWorkshop/Experience/ApsidesWorkshopControls.swift` (Hint, Dismiss tutorial, level
  picker for open levels, Practice, Daily (today's local date from the presenter), Campaign); agent D writes
  `Packages/ExperiencesRound02/ApsidesWorkshop/ExperienceTests/ApsidesWorkshopTeachingTests.swift` (the panel shows the
  tutorial, the three hint levels, the failure text, the band and the stars; mode and level controls reach the adapter;
  a refusal reads in words), given the presenter's exact texts; `--name sim-27 -- python3 scripts/xcodebuild_package.py
  --package Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package --destination sim-27.2 --action test
  --only-testing ApsidesWorkshopExperienceTests`

## Phase 5: Regression, documentation and close

- [X] T-R02G1805-006 Docs: `docs/architecture/apsides-workshop.md` (teaching and progression), — Verified 2026-11-25: 2026-11-25 docs/architecture/apsides-workshop.md (teaching and progression), round-two README, docs/automatedtesting.md; round02-host-1, -2, -3c, -3e, -3f exit 0
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host-1`, `-2`, `-3c`, `-3e`,
  `-3f`
- [X] T-R02G1805-007 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`, — Verified 2026-11-25: 2026-11-25 rendering-27, rendering-26, experiences, host-full, app-unit exit 0
  `--name host-full`, `--name app-unit`
- [X] T-R02G1805-008 Reference regression chunk 1 (`--name reference-1`) — Verified 2026-11-25: 2026-11-25 reference-1 exit 0
- [X] T-R02G1805-009 Reference regression chunk 2 (`--name reference-2`) — Verified 2026-11-25: 2026-11-25 reference-2 exit 0 (7 of 7 with chunk 1)
- [X] T-R02G1805-010 Script tests, run alone (`--name script-tests`) — Verified 2026-11-25: 2026-11-25 script-tests exit 0, run alone
- [ ] T-R02G1805-011 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record;
  README row and gate list updated

## Dependencies and parallel work

001 → {002 (agent B), 003 (agent C)} → 004 (lead) → 005 (lead; agent D writes the teaching tests) → 006 … 010, 011.
Agents may draft in isolated copies before 001 (new files only). MVP: Stories 2 and 3. Requirement coverage: FR-001 →
003, 005; FR-002 → 002, 005; FR-003 → 002, 005; FR-004 → 003, 004, 005; FR-005 → 003, 004; FR-006 → 004; FR-007 →
004, 006 … 010.
