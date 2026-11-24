# Tasks: R02-G13-05 — Acoustic Constellator: progression and player teaching

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G13-05 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G13-05 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_425;
tests stay short (< 10 s each). No {owner} or {device} tasks. Model: feature 415's tasks, with its convergence lesson
(the documentation of the tutorial's undo and redo behaviour) taken into the first pass.

## Phase 1: Setup

- [X] T-R02G1305-001 Baselines on the committed tree after R02-G13-04 is recorded: `--name baseline-host`, `--name — Verified 2026-11-23: 2026-11-23: baseline-host, baseline-timing, baseline-round02 exit 0 on ed3b90026 (.autonomy/migration/checks/R02-G13-05.baseline-*.json); rendering baseline = R02-G13-04 rendering-27/26
  baseline-timing`, `--name baseline-round02 -- swift test --package-path Packages/ExperiencesRound02`; the rendering
  baseline is R02-G13-04's rendering runs (exit 0)

## Phase 2: Stories 2 and 3 — hints and failure explanation (P1) 🎯

- [X] T-R02G1305-002 [P] [US2] [US3] Add `plan(_:links:phases:maxActions:workBound:)` to — Verified 2026-11-23: 2026-11-23: agent B solver entry plan(_:links:phases:) (catalog regenerates all 100 witnesses byte-identical), hints and failure explanation; 9 hint tests (exact hints win all 100 levels at the witness's count, 200 seeded states, 500 seeded failures, more than six links); lead retest host-2 exit 0 (.autonomy/migration/checks/R02-G13-05.host-2.json)
  `Packages/ExperiencesRound02/AcousticConstellator/Core/AcousticConstellatorSolver.swift` (the minimal-plan search of
  `plan(_:maxActions:workBound:)` from the given links and starting phases: the base is the given links plus the missing
  symbol pairs, the options the helper links the degree and link limits allow and ±1 nudges, listens run from the given
  phases; `plan(_:)` unchanged and equal to `plan(level, links: level.fixedLinks, phases: level.startingPhases)`; the
  plan's links exclude the given ones) and create
  `Packages/ExperiencesRound02/AcousticConstellator/Core/AcousticConstellatorHints.swift` (`AcousticConstellatorHintPlan`,
  `AcousticConstellatorHintKind` linkSymbol/linkHelper/nudge/listen/stuck, `AcousticConstellatorHint` with levels 1 … 3
  and the texts of clarification Q1 — "Link two stars of the symbol", "Link a helper pair so the phases pull together",
  "Nudge a star's phase", "The symbol is ready: listen"; "Work on star a and star b" / "Work on star s" / "Listen: tap
  the coherence gauge"; "Link star a to star b" / "Nudge star s by +1" (or "by −1"); stuck "No way to win was found in
  the moves left: undo the last action or retry the level."; failed play "Undo the last action or retry the level.";
  won play nil — the plan is the minimal plan's links (missing pairs first, in pair order, then helper links), its
  nudges, then the listen, and nil unless those actions fit the actions left (and within the work bound);
  `AcousticConstellatorHints.plan`/`hint`; `AcousticConstellatorFailureExplanation` with the texts of clarification Q5
  for `missing`, `disconnected`, `incoherent` and `budget` (after a link, an unlink, a nudge or the listen), actions
  numbered from 1 and ticks and stars from 0, followed by "Undo the last action or retry the level.") with
  `Packages/ExperiencesRound02/AcousticConstellator/CoreTests/AcousticConstellatorHintsTests.swift` (following exact
  hints from the opening wins all 100 certified levels within their budget, in parallel groups under 10 s each; 200
  seeded reachable states (seed 2_425): every exact hint is accepted by the kernel; 500 seeded failures explained with
  their true action and numbers; a hint never changes the play; a play with more than six links still gets a plan);
  agent B; `--name host-2`

## Phase 3: Stories 1 and 4 — tutorial and progress (P1, P2)

- [X] T-R02G1305-003 [P] [US1] [US4] Create — Verified 2026-11-23: 2026-11-23: agent C tutorial steps, progress, stars, daily (x 89), modes; 15 tests incl. levels 1-3 through the kernel, 4,018 dates, Codable shapes; lead retest host-3 exit 0 (.autonomy/migration/checks/R02-G13-05.host-3.json)
  `Packages/ExperiencesRound02/AcousticConstellator/Core/AcousticConstellatorProgress.swift`
  (`AcousticConstellatorTutorialStep` link → complete → listen → done with the texts of clarification Q2, advanced by an
  accepted link (link → complete, and on to listen at once when that link leaves no symbol pair missing), no symbol pair
  missing (complete → listen) or the level's end (→ done), never moved back by undo — documented exactly: an undo passes
  `afterLink: false` and the play's real end (an undo always lands before the end, so it never ends the tutorial), a
  redo that restores a won or failed play ends it; `AcousticConstellatorProgress` "3 when at most the certified
  witness's action count, 2 when at most that + 2, else 1" by actions spent (every accepted link, unlink, nudge and
  listen record, undone ones included), frontier with level 1 open, best actions spent per level, a better result
  replacing a worse one; `dailyLevel(year:month:day:)` "(days from 2026-01-01 × 89) mod 100 + 1, negative day counts
  wrapped", nil for an impossible date; `AcousticConstellatorMode` campaign, practice, daily(level)) with
  `Packages/ExperiencesRound02/AcousticConstellator/CoreTests/AcousticConstellatorProgressTests.swift` (tutorial steps on
  levels 1 … 3 by scripted plays; stars and frontier over a 100-level script; every date 2026-01-01 … 2036-12-31 gives a
  level in 1 … 100, stable; impossible dates nil; Codable round trips); agent C; `--name host-3`

## Phase 4: Adapter, scenarios, presenter

- [X] T-R02G1305-004 Edit `Packages/ExperiencesRound02/AcousticConstellator/Core/AcousticConstellatorExperienceCore.swift` — Verified 2026-11-23: 2026-11-23: agent F drafted, lead landed and retested: 12 controls (level.select, mode.daily, mode.practice, mode.campaign, tutorial.dismiss added; codes r02-g13.locked, r02-g13.date), practice budget 40, progress and mode in the digest (domain v2), schema 2 with migration from 1, level.next to the next open level (row 80 now shows the refusal on level 100), regenerated manifest; host-4 exit 0 (.autonomy/migration/checks/R02-G13-05.host-4.json)
  (controls `level.select [1 … 100]`, `mode.daily [year, month, day]`, `mode.practice`, `mode.campaign`,
  `tutorial.dismiss`; codes `r02-g13.locked`, `r02-g13.date`; practice budget 40 on a copy of the level, no stars, no
  unlocks; a daily win records the level's best result and stars and opens nothing; progress and mode in the digest,
  the tutorial step snapshotted but not digested; snapshot schema 2 `{level, mode, progress, records, tutorial}` with a
  migration from 1 "level 1 open plus the restored level, campaign mode, tutorial at its first step on tutorial levels";
  `level.next` to the next open level, refused with `r02-g13.locked` when none; no level is ever gated by payment —
  locked means not yet unlocked (FR-R02G1305-006)) with tests in
  `Packages/ExperiencesRound02/AcousticConstellator/CoreTests/AcousticConstellatorExperienceCoreTests.swift` (new
  controls, refusals, schema 2 round trip, migration from a schema-1 payload, newer schema refused); update
  `Packages/ExperiencesRound02/AcousticConstellator/Core/AcousticConstellatorScenarios.swift` where the new controls and
  the `level.next` rule change expectations and regenerate
  `Packages/ExperiencesRound02/AcousticConstellator/scenario-manifest.json` (`UPDATE_SCENARIO_MANIFEST=1`); update
  `AcousticConstellatorPanelWinTests`, the gesture wiring tests and other suites whose `level.next` expectation changes;
  lead; `--name host-4 -- swift test --package-path Packages/ExperiencesRound02 --filter AcousticConstellatorCoreTests`
- [ ] T-R02G1305-005 Edit `Packages/ExperiencesRound02/AcousticConstellator/Experience/AcousticConstellatorPresenter.swift`
  (the tutorial instruction, the hint at its current level — "Hint" raises the level 1 → 2 → 3, any play change resets
  it, the search off the main actor and a stale search never owning the hint state — and the failure explanation as
  panel text, with the level's difficulty band (of the five bands of 20), its goal and its best stars (FR-R02G1305-004);
  the description includes them) and
  `Packages/ExperiencesRound02/AcousticConstellator/Experience/AcousticConstellatorControls.swift` (Hint, Dismiss
  tutorial, level picker for open levels, Practice, Daily (today's local date from the presenter), Campaign); agent D
  writes `Packages/ExperiencesRound02/AcousticConstellator/ExperienceTests/AcousticConstellatorTeachingTests.swift` (the
  panel shows the tutorial, the three hint levels, the failure text, the band and the stars; mode and level controls
  reach the adapter; a refusal reads in words), given the presenter's exact texts; `--name sim-27 -- python3
  scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package --destination
  sim-27.2 --action test --only-testing AcousticConstellatorExperienceTests`

## Phase 5: Regression, documentation and close

- [ ] T-R02G1305-006 Docs: `docs/architecture/acoustic-constellator.md` (teaching and progression),
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host`
- [ ] T-R02G1305-007 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`,
  `--name host-full`, `--name app-unit`
- [ ] T-R02G1305-008 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G1305-009 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G1305-010 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G1305-011 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record;
  README row and gate list updated

## Dependencies and parallel work

001 → {002 (agent B), 003 (agent C)} → 004 (lead) → 005 (lead; agent D writes the teaching tests) → 006 … 011. Shared
files (adapter, scenarios, presenter, controls, docs) stay with the lead. Agents B and C may start in isolated copies
before 001, since their files are new or untouched by R02-G13-04 (the solver is untouched there). MVP: Stories 1–3
(tutorial, hints, failure text); Story 4 (progress, daily, practice) follows in the same gate. Requirement coverage:
FR-001 → 003, 005; FR-002, 003 → 002, 005; FR-004, 005 → 003, 004, 005; FR-006 → 004; FR-007 → 004, 006 … 011.
