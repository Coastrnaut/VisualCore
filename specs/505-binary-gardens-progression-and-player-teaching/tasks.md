# Tasks: R02-G21-05 — Binary Gardens: progression and player teaching

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G21-05 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G21-05 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_505;
tests stay short (< 10 s each). No {owner} or {device} tasks (the spec names no device-only item; the round's device
campaign covers the game). Agents model their files on Mushroom Weather's (feature 495) and draft in isolated copies.

## Phase 1: Setup

- [X] T-R02G2105-001 Baselines on the committed tree after R02-G21-04 is recorded: `--name baseline-host`, `--name — Verified 2026-11-27: baseline-host, baseline-timing, baseline-round02-1, -2, -3c, -3e, -3f exit 0 (on 79810762a after R02-G21-04 was recorded)
  baseline-timing`, `--name baseline-round02-1`, `-2`, `-3c`, `-3e`, `-3f`; the rendering baseline is R02-G21-04's
  rendering runs (exit 0)

## Phase 2: Stories 2 and 3 — hints and failure explanation (P1) 🎯

- [X] T-R02G2105-002 [P] [US2] [US3] Create `Packages/ExperiencesRound02/BinaryGardens/Core/BinaryGardensHints.swift` — Verified 2026-11-27: host-2 exit 0 (swift test --filter BinaryGardens: 232 tests in 22 suites; BinaryGardensHintsTests 29 pass)
  (`BinaryGardensHintPlan`, `BinaryGardensHintKind` ring/phase/luminosity/tilt/run/stuck/retry, `BinaryGardensHint`
  with levels 1 … 3 and the texts of clarification Q1 — level 1 "Move a star to another ring", "Shift a star's phase",
  "Change a star's brightness" or "Tilt the orbit plane"; level 2 "Move star n outward" ("inward"; a higher ring index
  is outward), "Shift star n's phase forward" when (target − current) mod 48 is 1 … 24, else "back", "Make star n
  brighter" ("dimmer"), "Tilt the orbit plane more" ("less"); level 3 "Move star n to ring r (ρ units)", "Shift star n
  to phase p", "Set star n's luminosity to L", "Set the tilt to t of T steps" (stars and rings numbered from 1: star + 1,
  index + 1; L the luminosity in units); already winning "Every world keeps its light: run the cycle"; stuck "No way to
  win was found in the actions left: undo the last action or retry the level."; failed play "Undo the last action or
  retry the level."; won, loading, tutorial or paused play nil — while every one of the seven controls holds its
  starting or its certified value, the remaining actions are the certified witness's actions whose control is not yet at
  its certified value, in the witness's order; when the actions left cover them and each, applied in order from the
  current arrangement, is a legal move (`BinaryGardensPuzzle.moves(in:)`, minimum separation kept), the plan is them;
  otherwise a breadth-first search "within min(actions left, 2) actions" over the puzzle's legal moves in its fixed
  order (star 1 ring, phase, luminosity, star 2 ring, phase, luminosity, tilt; values ascending), one action before two,
  each reached arrangement judged once with `BinaryGardensSky.report` (the current one never again), "at most 2,000
  arrangements judged", the first winning sequence found; `BinaryGardensHints.plan`/`hint` taking the certified plan;
  `BinaryGardensFailureExplanation` with the texts of clarification Q5 for `frozen`, `scorched` (E = 0 and singular
  wordings), `unstable` (w = 0 and singular wordings), `wilted` and `bleached`, worlds numbered from 1, ticks in the
  level's words (`BinaryGardensLevel.walkTickWords`, module-internal, so the file sits in the same target; ticks beyond 48 as "tick 50 (tick 2 of the next cycle)"), numbers
  grouped by `BinaryGardensLevel.grouped`, each followed by one space and "Undo the last action or retry the level.")
  with `Packages/ExperiencesRound02/BinaryGardens/CoreTests/BinaryGardensHintsTests.swift` (following exact hints from
  the opening, then the run, wins all 100 certified levels within the certified count, in groups under 10 s each; 200
  seeded reachable states (seed 2_505): every exact hint is accepted by the kernel; 500 seeded failures covering all
  five causes explained with their true world, tick, window and totals; a hint never changes the play; the bounded
  search finds a winning plan from states off the certified path when one exists within two actions; the work bound
  refuses a search when set below the space); agent B; `--name host-2 -- swift test --package-path
  Packages/ExperiencesRound02 --filter BinaryGardens`

## Phase 3: Stories 1 and 4 — tutorial and progress (P1, P2)

- [X] T-R02G2105-003 [P] [US1] [US4] Create `Packages/ExperiencesRound02/BinaryGardens/Core/BinaryGardensProgress.swift` — Verified 2026-11-27: host-2 exit 0 covers it (same command on the tree with T-003 installed; BinaryGardensProgressTests 19 pass)
  (`BinaryGardensTutorialStep` adjust → balance → recover → done with the texts of clarification Q2, advanced by an
  accepted arrangement action (adjust → balance), a second accepted arrangement action in this opening (balance →
  recover) or the level's end (→ done), never moved back by undo or redo — an undo passes no action, a redo that
  restores a won or failed moment ends it — and never moved by `clock.show`; `BinaryGardensProgress` "3 when at most
  the certified witness's action count, 2 when at most that + 2, else 1" by actions spent (every accepted ring, phase,
  luminosity and tilt record, undone ones included), frontier 1 … 100 with level 1 open, best actions spent and stars
  per level, a better result replacing a worse one and never the reverse; `dailyLevel(year:month:day:)` "(days from
  2026-01-01 × 13) mod 100 + 1, negative day counts wrapped into 0 … 99", proleptic Gregorian in integer arithmetic,
  years 1 … 9999, nil for an impossible date; `BinaryGardensMode` campaign, practice, daily(level)) with
  `Packages/ExperiencesRound02/BinaryGardens/CoreTests/BinaryGardensProgressTests.swift` (tutorial steps on levels 1 … 3
  by scripted plays following the witnesses; stars and frontier over a 100-level script; every date 2026-01-01 …
  2036-12-31 gives a level in 1 … 100, stable, and every 100 consecutive days visit each level once; impossible dates
  nil; Codable round trips); agent C; `--name host-3 -- swift test --package-path Packages/ExperiencesRound02 --filter
  BinaryGardens`

## Phase 4: Adapter, scenarios, presenter

- [ ] T-R02G2105-004 Edit `Packages/ExperiencesRound02/BinaryGardens/Core/BinaryGardensExperienceCore.swift`
  (controls `level.select [1 … 100]`, `mode.daily [year, month, day]`, `mode.practice`, `mode.campaign`,
  `tutorial.dismiss`; codes `r02-g21.locked`, `r02-g21.date`, non-whole values `r02-g21.not-whole`; practice budget 24
  on a copy of the level, no stars, no unlocks; the daily level is playable even while still locked in the campaign,
  and a daily win records the level's best result and stars and opens nothing; `mode.campaign` returns to the current
  level or the frontier when the current one is not open; choosing a level or mode starts a fresh play (records
  dropped, tick 48 shown, tutorial at its first step on levels 1 … 3); a fresh opening of level N (prepare, reset)
  has no won levels and levels 1 … N open, as feature 495; digest domain `"r02-g21.binary-gardens.v2"` over
  level, play fingerprint, progress and mode, the tutorial step snapshotted but not digested, the shown tick, preview,
  orbit and inspected world unchanged (presentation); snapshot schema 2 `{level, mode, progress, records, tutorial}`
  (sorted keys) with a migration from 1 "no won levels, levels 1 … the restored level open, campaign mode, the tutorial
  at `adjust` on levels 1 … 3, else `done`"; a damaged payload, a level or frontier outside 1 … 100, stars outside
  1 … 3 or actions below 1, or a trace the kernel refuses throws the restore refusal; `level.next` to the next open
  level in campaign mode, refused with `r02-g21.locked` when none (no wrap from 100 to 1); the certified plan of the
  prepared level exposed for hints and stars; no level is ever gated by payment — locked means not yet unlocked
  (FR-R02G2105-006)) with tests in
  `Packages/ExperiencesRound02/BinaryGardens/CoreTests/BinaryGardensProgressionCoreTests.swift` (new controls,
  refusals, a locked daily level played without opening it, schema 2 round trip, migration from a schema-1 payload of every level 1 … 100 (SC-R02G2105-005),
  damaged and newer payloads refused); update in place only the assertions clarification Q6 names — the declared
  control list, schema version 2, digest domain v2 and `level.next`'s wrap — in
  `Packages/ExperiencesRound02/BinaryGardens/CoreTests/BinaryGardensExperienceCoreTests.swift`,
  `Packages/ExperiencesRound02/BinaryGardens/CoreTests/BinaryGardensScenariosTests.swift` and the R02-G21-04 panel-win
  and gesture wiring tests where they assert them; update
  `Packages/ExperiencesRound02/BinaryGardens/Core/BinaryGardensScenarios.swift` (`nextLevel` without wrap; as feature
  495, full-playthrough's campaign wins open each next level before `level.next`, the integration rows 71 … 80 first win
  their level's certified plan and the run before `level.next`, a row on level 100 chooses level 1 with `level.select
  [1]` instead, and rejection also refuses the new controls' wrong value counts) and
  regenerate `Packages/ExperiencesRound02/BinaryGardens/scenario-manifest.json` (`UPDATE_SCENARIO_MANIFEST=1`); lead;
  `--name host-4 -- swift test --package-path Packages/ExperiencesRound02 --filter BinaryGardens`
- [ ] T-R02G2105-005 Edit `Packages/ExperiencesRound02/BinaryGardens/Experience/BinaryGardensPresenter.swift` (the
  tutorial step text replacing the single tutorial sentence, the hint at its current level — "Hint" raises the level
  1 → 2 → 3, any play change resets it, the search off the main actor with a generation counter so a stale search never
  owns the hint — and the failure explanation as panel text, replacing the presenter's own failure words, with "Band b
  of 5", the goal "Win in at most k actions for 3 stars" (k the certified count) and "Best: s of 3 stars" or "Best: not
  won yet" (FR-R02G2105-004); the description includes them; wrapping panel text, never over the scene (FR-R02G2105-008))
  and `Packages/ExperiencesRound02/BinaryGardens/Experience/BinaryGardensControls.swift` (Hint, Dismiss tutorial, level
  picker for open levels, Practice, Daily (today's local date from the presenter), Campaign); agent D writes
  `Packages/ExperiencesRound02/BinaryGardens/ExperienceTests/BinaryGardensTeachingTests.swift` (the panel shows the
  tutorial, the three hint levels, the failure text, the band, goal and stars; mode and level controls reach the
  adapter; a refusal reads in words), given the presenter's exact texts; `--name sim-27 -- python3
  scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package --destination
  sim-27.2 --action test --only-testing BinaryGardensExperienceTests`

## Phase 5: Regression, documentation and close

- [ ] T-R02G2105-006 Docs: `docs/architecture/binary-gardens.md` (teaching and progression),
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host-1`, `-2`, `-3c`, `-3e`,
  `-3f`
- [ ] T-R02G2105-007 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`,
  `--name host-full`, `--name app-unit`
- [ ] T-R02G2105-008 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G2105-009 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G2105-010 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G2105-011 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record;
  README row and gate list updated

## Dependencies and parallel work

001 → {002 (agent B), 003 (agent C)} → 004 (lead) → 005 (lead; agent D writes the teaching tests) → 006 … 010, 011.
Agents may draft in isolated copies before 001 (new files only). MVP: Stories 2 and 3. Requirement coverage: FR-001 →
003, 005; FR-002 → 002, 005; FR-003 → 002, 005; FR-004 → 003, 004, 005; FR-005 → 003, 004; FR-006 → 004; FR-007 →
004, 006 … 010; FR-008 → 005; FR-009 → 002, 003, 004.
