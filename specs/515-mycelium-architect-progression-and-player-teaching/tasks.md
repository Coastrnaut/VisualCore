# Tasks: R02-G22-05 — Mycelium Architect: progression and player teaching

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G22-05 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G22-05 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_515;
tests stay short (< 10 s each). No {owner} or {device} tasks (the spec names no device-only item; the round's device
campaign covers the game). Agents model their files on Binary Gardens' (feature 505) and draft in isolated copies.

## Phase 1: Setup

- [X] T-R02G2205-001 Baselines on the committed tree after R02-G22-04 is recorded: `--name baseline-host`, `--name — Verified 2026-11-27: 2026-11-27: baseline-host, baseline-timing, baseline-round02-1/2/3c/3e/3f exit=0 (.autonomy/migration/checks/R02-G22-05.baseline-*.json)
  baseline-timing`, `--name baseline-round02-1`, `-2`, `-3c`, `-3e`, `-3f`; the rendering baseline is R02-G22-04's
  rendering runs (exit 0)

## Phase 2: Stories 2 and 3 — hints and failure explanation (P1) 🎯

- [X] T-R02G2205-002 [P] [US2] [US3] Create `Packages/ExperiencesRound02/MyceliumArchitect/Core/MyceliumArchitectHints.swift` — Verified 2026-11-27: 2026-11-27: host-2 exit=0 (swift test --filter MyceliumArchitect: 191 Swift Testing + 33 XCTest; MyceliumArchitectHintsTests 30 pass; largest hint work 168 of 2,000)
  (`MyceliumArchitectHintPlan`, `MyceliumArchitectHintKind` nutrient/blocker/clear/seed/unseed/run/stuck/retry,
  `MyceliumArchitectHint` with levels 1 … 3 and the texts of clarification Q1 — level 1 "Place a nutrient", "Place a
  blocker", "Clear a placed nutrient or blocker", "Seed a filament from the root" or "Remove a seeded filament"; level 2
  adds the cell's quadrant ("in the upper left", "upper right", "lower left", "lower right": a column below W / 2 is
  left, a row below H / 2 upper) or the direction's side ("towards the top" for north, north-east, north-west, "towards
  the bottom" for south, south-east, south-west, "to the east", "to the west"); level 3 "Place a nutrient at" / "Place a
  blocker at" / "Clear" + the level's words for the cell, "Seed a filament to the" / "Remove the filament to the" + the
  compass name; already winning "Every terminal is reached within the limits: run the growth"; stuck "No way to win was
  found in the actions left: undo the last action or retry the level."; failed play "Undo the last action or retry the
  level."; won, loading, tutorial or paused play nil — while the arrangement lies on the way (for placed nutrients,
  placed blockers and seeds: start ∩ certified ⊆ current ⊆ start ∪ certified), the remaining actions are the certified
  witness's actions not yet done (a placement not yet placed on its cell, a clear whose cell still holds an item, a seed
  not yet seeded, an unseed still seeded), in the witness's order; when the actions left cover them and each, applied in
  order from the current arrangement, is accepted by the rules (`MyceliumArchitectPuzzle.apply`), the plan is them;
  otherwise a breadth-first search "within min(actions left, 2) actions" over `MyceliumArchitectPuzzle.moves(in:)` in its
  fixed order, one action before two, each reached arrangement judged once with `MyceliumArchitectGrowth.report` (the
  current one never again), "at most 2,000 arrangements judged", the first winning sequence found;
  `MyceliumArchitectHints.plan`/`hint` taking the certified plan's arrangement actions;
  `MyceliumArchitectFailureExplanation`: the level's `failureDescription`, first letter capitalised, then ". Undo the
  last action or retry the level.") with `Packages/ExperiencesRound02/MyceliumArchitect/CoreTests/MyceliumArchitectHintsTests.swift` (following exact hints from
  the opening, then the run, wins all 100 certified levels within the certified count, in groups under 10 s each; 200
  seeded reachable states (seed 2_515): every exact hint is accepted by the kernel; 500 seeded failures covering all four
  causes explained with their true tip or terminal, cell, pulse, weight and bound; a hint never changes the play; the
  bounded search finds a winning plan from states off the certified path when one exists within two actions; the work
  bound refuses a search when set below the space); agent B; `--name host-2 -- swift test --package-path
  Packages/ExperiencesRound02 --filter MyceliumArchitect`

## Phase 3: Stories 1 and 4 — tutorial and progress (P1, P2)

- [X] T-R02G2205-003 [P] [US1] [US4] Create `Packages/ExperiencesRound02/MyceliumArchitect/Core/MyceliumArchitectProgress.swift` — Verified 2026-11-27: 2026-11-27: host-3 exit=0 (same command with T-003 installed; MyceliumArchitectProgressTests 20 pass; daily × 11 checked independently)
  (`MyceliumArchitectTutorialStep` place → grow → recover → done with the texts of clarification Q2, advanced by an
  accepted arrangement action (place → grow), a second accepted arrangement action in this opening (grow → recover) or
  the level's end (→ done), never moved back by undo or redo — an undo passes no action, a redo that restores a won or
  failed moment ends it — and never moved by `growth.show`; `MyceliumArchitectProgress` "3 when at most the certified
  witness's action count, 2 when at most that + 2, else 1" by actions spent (every accepted nutrient, blocker, clear,
  seed and unseed record, undone ones included), frontier 1 … 100 with level 1 open, best actions spent and stars per
  level, a better result replacing a worse one and never the reverse; `dailyLevel(year:month:day:)` "(days from
  2026-01-01 × 11) mod 100 + 1, negative day counts wrapped into 0 … 99", proleptic Gregorian in integer arithmetic,
  years 1 … 9999, nil for an impossible date; `MyceliumArchitectMode` campaign, practice, daily(level)) with
  `Packages/ExperiencesRound02/MyceliumArchitect/CoreTests/MyceliumArchitectProgressTests.swift` (tutorial steps on levels 1 … 3 by scripted plays following the
  witnesses; stars and frontier over a 100-level script; every date 2026-01-01 … 2036-12-31 gives a level in 1 … 100,
  stable, and every 100 consecutive days visit each level once; impossible dates nil; Codable round trips); agent C;
  `--name host-3 -- swift test --package-path Packages/ExperiencesRound02 --filter MyceliumArchitect`

## Phase 4: Adapter, scenarios, presenter

- [X] T-R02G2205-004 Edit `Packages/ExperiencesRound02/MyceliumArchitect/Core/Presentation/MyceliumArchitectExperienceCore.swift` (controls `level.select — Verified 2026-11-27: 2026-11-27: host-4 exit=0 (swift test --filter MyceliumArchitect: 205 Swift Testing + 33 XCTest; ProgressionCore 13 tests; manifest regenerated; Q5 assertions updated in place); simulator MyceliumArchitectExperienceTests 38 passed on sim-27.2 with the updated identity and wiring tests
  [1 … 100]`, `mode.daily [year, month, day]`, `mode.practice`, `mode.campaign`, `tutorial.dismiss`; codes
  `r02-g22.locked`, `r02-g22.date`, non-whole values `r02-g22.not-whole`; practice budget 24 on a copy of the level,
  no stars, no unlocks; the daily level is playable even while still locked in the campaign, and a daily win records
  the level's best result and stars and opens nothing; `mode.campaign` returns to the current level or the frontier
  when the current one is not open; choosing a level or mode starts a fresh play (records dropped, the pulses run shown,
  tutorial at its first step on levels 1 … 3, tool, preview, inspection and orbit at their defaults); a fresh opening of
  level N (prepare, reset) has no won levels and levels 1 … N open; digest domain `"r02-g22.mycelium-architect.v2"`
  over level, play fingerprint, progress and mode, the tutorial step snapshotted but not digested, the shown pulse,
  tool, preview, orbit and inspected cell unchanged (presentation); snapshot schema 2 `{level, mode, progress, records,
  tutorial}` (sorted keys) with a migration from 1 "no won levels, levels 1 … the restored level open, campaign mode,
  the tutorial at `place` on levels 1 … 3, else `done`"; a damaged payload, a level or frontier outside 1 … 100, stars
  outside 1 … 3 or actions below 1, or a trace the kernel refuses throws the restore refusal; `level.next` to the next
  open level in campaign mode, refused with `r02-g22.locked` when none (no wrap from 100 to 1); the certified plan of
  the prepared level exposed for hints and stars; no level is ever gated by payment — locked means not yet unlocked
  (FR-R02G2205-006)) with tests in `Packages/ExperiencesRound02/MyceliumArchitect/CoreTests/MyceliumArchitectProgressionCoreTests.swift` (new controls, refusals,
  a locked daily level played without opening it, schema 2 round trip, migration from a schema-1 payload of every level
  1 … 100 (SC-R02G2205-005), damaged and newer payloads refused); update in place only the assertions clarification Q5
  names — the declared control list, schema version 2, digest domain v2 and `level.next`'s wrap — in
  `Packages/ExperiencesRound02/MyceliumArchitect/CoreTests/MyceliumArchitectExperienceCoreTests.swift`, `Packages/ExperiencesRound02/MyceliumArchitect/CoreTests/MyceliumArchitectPreviewTests.swift`,
  `Packages/ExperiencesRound02/MyceliumArchitect/CoreTests/MyceliumArchitectPanelWinTests.swift`,
  `Packages/ExperiencesRound02/MyceliumArchitect/ExperienceTests/MyceliumArchitectExperienceIdentityTests.swift` (control list) and
  `Packages/ExperiencesRound02/MyceliumArchitect/ExperienceTests/MyceliumArchitectGestureWiringTests.swift` where they assert them — the preview test's and the
  wiring test's `level.next` on a fresh opening now first win the level's certified plan and the run (an unwon level
  opens nothing, so `level.next` would be refused `r02-g22.locked`); update `Packages/ExperiencesRound02/MyceliumArchitect/Core/Presentation/MyceliumArchitectScenarios.swift` (`nextLevel` without wrap; as feature
  505, full-playthrough's campaign wins open each next level before `level.next`, rows that move past a level first
  win its certified plan and the run, a row on level 100 chooses level 1 with `level.select [1]` instead, and rejection
  also refuses the new controls' wrong value counts) and regenerate `Packages/ExperiencesRound02/MyceliumArchitect/scenario-manifest.json`
  (`UPDATE_SCENARIO_MANIFEST=1`); lead; `--name host-4 -- swift test --package-path Packages/ExperiencesRound02
  --filter MyceliumArchitect`
- [X] T-R02G2205-005 Edit `Packages/ExperiencesRound02/MyceliumArchitect/Experience/MyceliumArchitectPresenter.swift` (the tutorial step text replacing the single — Verified 2026-11-27: 2026-11-27: sim-27 exit=0 (sim-27.2, MyceliumArchitectExperienceTests: 50 tests in 6 suites; 11 teaching tests)
  tutorial sentence, the hint at its current level — "Hint" raises the level 1 → 2 → 3, any play change resets it, the
  search off the main actor with a generation counter so a stale search never owns the hint — and the failure
  explanation as panel text, with "Band b of 5", the goal "Win in at most k actions for 3 stars" ("1 action" in the
  singular; k the certified count) and "Best: s of 3 stars" or "Best: not won yet" (FR-R02G2205-004); the description
  includes them; wrapping panel text, never over the scene (FR-R02G2205-008)) and
  `Packages/ExperiencesRound02/MyceliumArchitect/Experience/MyceliumArchitectControls.swift` (Hint, Dismiss tutorial, level picker for open levels, Practice,
  Daily (today's local date from the presenter), Campaign — Buttons, never a segmented picker); agent D writes
  `Packages/ExperiencesRound02/MyceliumArchitect/ExperienceTests/MyceliumArchitectTeachingTests.swift` (the panel shows the tutorial, the three hint levels, the
  failure text, the band, goal and stars; mode and level controls reach the adapter; a refusal reads in words), given
  the presenter's exact texts; `--name sim-27 -- python3 scripts/xcodebuild_package.py --package
  Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package --destination sim-27.2 --action test --only-testing
  MyceliumArchitectExperienceTests`

## Phase 5: Regression, documentation and close

- [X] T-R02G2205-006 Docs: `docs/architecture/mycelium-architect.md` (teaching and progression), — Verified 2026-11-27: 2026-11-27: round02-host-1/2/3c/3e/3f exit=0; docs: architecture teaching section, package README, automatedtesting
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host-1`, `-2`, `-3c`, `-3e`,
  `-3f`
- [X] T-R02G2205-007 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`, — Verified 2026-11-27: 2026-11-27: rendering-27, rendering-26, experiences, host-full, app-unit exit=0
  `--name host-full`, `--name app-unit`
- [ ] T-R02G2205-008 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G2205-009 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G2205-010 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G2205-011 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record;
  README row and gate list updated

## Dependencies and parallel work

001 → {002 (agent B), 003 (agent C)} → 004 (lead) → 005 (lead; agent D writes the teaching tests) → 006 … 010, 011.
Agents may draft in isolated copies before 001 (new files only). MVP: Stories 2 and 3. Requirement coverage: FR-001 →
003, 005; FR-002 → 002, 005; FR-003 → 002, 005; FR-004 → 003, 004, 005; FR-005 → 003, 004; FR-006 → 004; FR-007 →
004, 006 … 010; FR-008 → 005; FR-009 → 002, 003, 004; FR-010 → 004, 005.
