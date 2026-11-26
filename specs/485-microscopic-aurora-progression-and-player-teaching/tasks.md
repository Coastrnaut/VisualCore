# Tasks: R02-G19-05 — Microscopic Aurora: progression and player teaching

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G19-05 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G19-05 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_485;
tests stay short (< 10 s each). No {owner} or {device} tasks (the spec names no device-only item; the round's device
campaign covers the game). Agents model their files on Apsides Workshop's as recorded at R02-G18-05.

## Phase 1: Setup

- [X] T-R02G1905-001 Baselines on the committed tree after R02-G19-04 is recorded: `--name baseline-host`, `--name — Verified 2026-11-26: baselines exit 0 on the committed tree after the R02-G19-04 record (host, timing, round02-1, -2, -3c, -3e, -3f); rendering baseline is R02-G19-04's rendering runs
  baseline-timing`, `--name baseline-round02-1`, `-2`, `-3c`, `-3e`, `-3f`; the rendering baseline is R02-G19-04's
  rendering runs (exit 0)

## Phase 2: Stories 2 and 3 — hints and failure explanation (P1) 🎯

- [X] T-R02G1905-002 [P] [US2] [US3] Create `Packages/ExperiencesRound02/MicroscopicAurora/Core/MicroscopicAuroraHints.swift` — Verified 2026-11-26: host-2 exit 0: exact hints win all 100 certified levels within budget (replaying the certified plan), 200 seeded reachable states get accepted hints, off-path states match an unbounded brute force, 500 seeded failures explained truly (all four kinds)
  (`MicroscopicAuroraHintPlan`, `MicroscopicAuroraHintKind` place/remove/play/stuck, `MicroscopicAuroraHint` with levels
  1 … 3 and the texts of clarification Q1 — "Use the site at row r, column c next" or "Take well n away"; "Place a
  clockwise (or counterclockwise) well at the site at row r, column c"; "Place well n at row r, column c with strength
  s, turning clockwise" (or "counterclockwise"), "Take well n away"; already winning "The trails already cover the
  stencil as one pattern: play the swim"; stuck "No way to win was found in the actions left: undo the last action or
  retry the level."; failed play "Undo the last action or retry the level."; won play nil — the plan is a shortest
  completion from the play's current wells "within min(actions left, 2) actions", one action before two, the certified
  plan's next placement first while the current wells are a subset of the certified wells, then removals by slot, then
  placements by slot, site, strength 1 … 4 and sense (clockwise first); an action places a well on a site no other well
  holds (into the first free slot, or replacing a slot's well) or takes a slot's well away; judged with
  `MicroscopicAuroraDish.report` on the set of wells; "at most 1,200 sets judged"; `MicroscopicAuroraHints.plan`/`hint`
  taking the certified wells; `MicroscopicAuroraFailureExplanation` with the texts of clarification Q5 for `exit`,
  `coherence`, `coverage` and `connectedness`, swimmers numbered from 1 and cells as "the cell at row r, column c",
  followed by "Undo the last action or retry the level.") with
  `Packages/ExperiencesRound02/MicroscopicAurora/CoreTests/MicroscopicAuroraHintsTests.swift` (following exact hints from
  the opening, then the play, wins all 100 certified levels within their budget, in groups under 10 s each; 200 seeded
  reachable states (seed 2_485): every exact hint is accepted by the kernel; 500 seeded failures explained with their
  true swimmer, tick, group, counts or cell; a hint never changes the play; the bounded search finds a winning plan from
  states off the certified path when one exists within its bound); agent B; `--name host-2`

## Phase 3: Stories 1 and 4 — tutorial and progress (P1, P2)

- [X] T-R02G1905-003 [P] [US1] [US4] Create — Verified 2026-11-26: host-3 exit 0: tutorial steps place/cover/recover/done on levels 1-3 by witness plays, stars and frontier over a 100-level script, daily x 19 over 2026-2036 and 100 consecutive days, impossible dates nil, Codable round trips (18 tests)
  `Packages/ExperiencesRound02/MicroscopicAurora/Core/MicroscopicAuroraProgress.swift` (`MicroscopicAuroraTutorialStep`
  place → cover → recover → done with the texts of clarification Q2, advanced by an accepted placement (place → cover),
  a second accepted action (cover → recover) or the level's end (→ done), never moved back by undo — an undo passes no
  action and the play's real end, a redo that restores a won or failed play ends it; `MicroscopicAuroraProgress` "3 when
  at most the certified witness's placement count, 2 when at most that + 2, else 1" by actions spent (every accepted
  placement and removal record, undone ones included), frontier with level 1 open, best actions spent per level, a better
  result replacing a worse one; `dailyLevel(year:month:day:)` "(days from 2026-01-01 × 19) mod 100 + 1, negative day
  counts wrapped", nil for an impossible date; `MicroscopicAuroraMode` campaign, practice, daily(level)) with
  `Packages/ExperiencesRound02/MicroscopicAurora/CoreTests/MicroscopicAuroraProgressTests.swift` (tutorial steps on
  levels 1 … 3 by scripted plays following the witnesses; stars and frontier over a 100-level script; every date
  2026-01-01 … 2036-12-31 gives a level in 1 … 100, stable; impossible dates nil; Codable round trips); agent C;
  `--name host-3`

## Phase 4: Adapter, scenarios, presenter

- [X] T-R02G1905-004 Edit `Packages/ExperiencesRound02/MicroscopicAurora/Core/MicroscopicAuroraExperienceCore.swift` — Verified 2026-11-26: adapter: level.select, mode.daily, mode.practice, mode.campaign, tutorial.dismiss; r02-g19.locked and r02-g19.date; practice budget 24; progress and mode digested (v2), tutorial snapshotted; schema 2 with migration from 1; level.next to the next open level; scenarios and regenerated manifest; MicroscopicAuroraProgressionCoreTests (11); host-4 exit 0 (MicroscopicAurora filter)
  (controls `level.select [1 … 100]`, `mode.daily [year, month, day]`, `mode.practice`, `mode.campaign`,
  `tutorial.dismiss`; codes `r02-g19.locked`, `r02-g19.date`; practice budget 24 on a copy of the level, no stars, no
  unlocks; the daily level is playable even while still locked in the campaign, and a daily win records the level's best
  result and stars and opens nothing; progress and mode in the digest, the tutorial step snapshotted but not digested,
  the shown tick unchanged (presentation); snapshot schema 2 `{level, mode, progress, records, tutorial}` with a
  migration from 1 "level 1 open plus the restored level, campaign mode, tutorial at its first step on tutorial levels";
  `level.next` to the next open level, refused with `r02-g19.locked` when none; the certified wells of the prepared level
  exposed for hints and stars; no level is ever gated by payment — locked means not yet unlocked (FR-R02G1905-006))
  with tests in `Packages/ExperiencesRound02/MicroscopicAurora/CoreTests/MicroscopicAuroraProgressionCoreTests.swift`
  (new controls, refusals, a locked daily level played without opening it, schema 2 round trip, migration from a
  schema-1 payload, newer schema refused); update
  `Packages/ExperiencesRound02/MicroscopicAurora/Core/MicroscopicAuroraScenarios.swift` where the new controls and the
  `level.next` rule change expectations and regenerate `Packages/ExperiencesRound02/MicroscopicAurora/scenario-manifest.json`
  (`UPDATE_SCENARIO_MANIFEST=1`); update `MicroscopicAuroraPanelWinTests`, the gesture wiring tests and other suites
  whose `level.next` expectation changes; lead; `--name host-4 -- swift test --package-path Packages/ExperiencesRound02
  --filter MicroscopicAurora`
- [X] T-R02G1905-005 Edit `Packages/ExperiencesRound02/MicroscopicAurora/Experience/MicroscopicAuroraPresenter.swift` — Verified 2026-11-26: presenter: tutorial from the core's step, hint levels 1 to 3 searched off the main actor (stale searches dropped), failure explanation, band, goal, best stars, modes, locked and date refusals in words; panel: Hint, Dismiss tutorial, level picker, Play level, Campaign, Daily, Practice; MicroscopicAuroraTeachingTests (10); sim-27 exit 0 (MicroscopicAuroraExperienceTests, 46 tests)
  (the tutorial instruction, the hint at its current level — "Hint" raises the level 1 → 2 → 3, any play change resets
  it, the search off the main actor and a stale search never owning the hint state — and the failure explanation as
  panel text, replacing the mirror's own failure words, with the level's difficulty band (of the five bands of 20), its
  goal (the stencil in words and the placement count that earns 3 stars, the certified witness's) and its best stars
  (FR-R02G1905-004); the description includes them) and
  `Packages/ExperiencesRound02/MicroscopicAurora/Experience/MicroscopicAuroraControls.swift` (Hint, Dismiss tutorial,
  level picker for open levels, Practice, Daily (today's local date from the presenter), Campaign); agent D writes
  `Packages/ExperiencesRound02/MicroscopicAurora/ExperienceTests/MicroscopicAuroraTeachingTests.swift` (the panel shows
  the tutorial, the three hint levels, the failure text, the band and the stars; mode and level controls reach the
  adapter; a refusal reads in words), given the presenter's exact texts; `--name sim-27 -- python3
  scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package --destination
  sim-27.2 --action test --only-testing MicroscopicAuroraExperienceTests`

## Phase 5: Regression, documentation and close

- [X] T-R02G1905-006 Docs: `docs/architecture/microscopic-aurora.md` (teaching and progression), — Verified 2026-11-26: docs updated (architecture teaching and progression, round-two README, automatedtesting); round02-host-1, -2, -3c, -3e, -3f exit 0
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host-1`, `-2`, `-3c`, `-3e`,
  `-3f`
- [X] T-R02G1905-007 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`, — Verified 2026-11-26: rendering-27, rendering-26, experiences, host-full, app-unit exit 0
  `--name host-full`, `--name app-unit`
- [ ] T-R02G1905-008 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G1905-009 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G1905-010 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G1905-011 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record;
  README row and gate list updated

## Dependencies and parallel work

001 → {002 (agent B), 003 (agent C)} → 004 (lead) → 005 (lead; agent D writes the teaching tests) → 006 … 010, 011.
Agents may draft in isolated copies before 001 (new files only). MVP: Stories 2 and 3. Requirement coverage: FR-001 →
003, 005; FR-002 → 002, 005; FR-003 → 002, 005; FR-004 → 003, 004, 005; FR-005 → 003, 004; FR-006 → 004; FR-007 →
004, 006 … 010.
