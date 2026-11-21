# Tasks: R02-G02-05 — Lissajous Labyrinth: progression and player teaching

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G02-05 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G02-05 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_315;
tests stay short (< 10 s each). No {owner} or {device} tasks.

## Phase 1: Setup

- [X] T-R02G0205-001 Baselines: `--name baseline-host`, `--name baseline-timing`, `--name baseline-round02 -- swift test — Verified 2026-11-21: 2026-11-21 baseline-round02, baseline-host, baseline-timing exit 0; rendering baseline R02-G02-04 rendering-27/26 exit 0
  --package-path Packages/ExperiencesRound02`; the rendering baseline is R02-G02-04's rendering runs (exit 0)

## Phase 2: Stories 2 and 3 — hints and failure explanations (P1) 🎯

- [X] T-R02G0205-002 [P] [US2] [US3] Edit `Packages/ExperiencesRound02/LissajousLabyrinth/Core/LissajousLabyrinthSolver.swift` (`solve(_:from:winning:)` — Verified 2026-11-21: 2026-11-21 host exit 0: 24 tests in 3 suites (LissajousLabyrinthHintsTests 9 tests / 27 cases: certified solutions of all 100 levels unchanged through solve(_:from:winning:); 2,000 seeded reachable states: the level-3 hint shortens the remaining shortest by one, levels 1 and 2 agree, remaining equals an independent distance map; 500 seeded failures explained exactly; successor table equals the rules on all 20,736 indices; plus SolverTests and CatalogTests unchanged)
  "the certified breadth-first search from given dials over a winning set; solve(_:) delegates, certified solutions
  unchanged") and create `Packages/ExperiencesRound02/LissajousLabyrinth/Core/LissajousLabyrinthHints.swift` (LissajousLabyrinthHint "levels 1 … 3: dial, + raise or
  lower, + exact value, from the first action of the shortest remaining solution"; "No solution fits in the actions
  left; undo or retry" when the remaining shortest exceeds the actions left; nil when not playing;
  LissajousLabyrinthFailureExplanation "The path touches obstacle n at p % of the lap" (p = ⌊100 · tick / 4,096⌋) or
  "Checkpoint n is not reached in order", each followed by "Undo the last change or retry the level.") with
  `Packages/ExperiencesRound02/LissajousLabyrinth/CoreTests/LissajousLabyrinthHintsTests.swift` (certified solutions of all 100 levels unchanged; 2,000 seeded
  reachable states over all 100 levels: following the level-3 hint shortens the remaining shortest by one; levels 1 and
  2 agree with level 3; no hint after the end; 500 seeded failures explained exactly; fixtures from the witness files);
  `--name host -- swift test --package-path Packages/ExperiencesRound02 --filter
  'LissajousLabyrinthHintsTests|LissajousLabyrinthSolverTests|LissajousLabyrinthCatalogTests'`

## Phase 3: Stories 1 and 4 — tutorial, progress, daily, practice (P1, P2)

- [X] T-R02G0205-003 [P] [US1] [US4] Create `Packages/ExperiencesRound02/LissajousLabyrinth/Core/LissajousLabyrinthProgress.swift` (LissajousLabyrinthTutorialStep — Verified 2026-11-21: 2026-11-21 host-2 exit 0: LissajousLabyrinthProgressTests 16/16 (tutorial scripts on levels 1 … 3 win, with a detour showing every instruction; campaign through 100 levels opens in order with 3 stars; star rule; better replaces worse; daily recording keeps the frontier; every date 2026 … 2036 maps to 1 … 100 and every 100-day window covers all levels; impossible dates refused; round trips)
  "turn(dial) → checkpoints (an accepted dial action) → hints (the next accepted action or a hint) → done (a win);
  dismiss → done; undo never moves it back" with the texts of clarification Q2; LissajousLabyrinthMode "campaign, practice, daily(level)";
  LissajousLabyrinthProgress "level 1 open; a campaign win opens the next; a better result replaces a worse one; stars 3 at
  shortest, 2 within shortest + 2, else 1"; dailyLevel "(days from 2026-01-01 × 41) mod 100 + 1, negative counts wrapped;
  nil for an impossible date") with `Packages/ExperiencesRound02/LissajousLabyrinth/CoreTests/LissajousLabyrinthProgressTests.swift` (tutorial scripts on levels
  1 … 3 win following each instruction; scripted progress through 100 levels; stars; every date 2026-01-01 … 2036-12-31
  maps to 1 … 100 and 100 consecutive days visit every level; impossible dates refused; all 100 levels reachable by
  progress alone, FR-R02G0205-006); `--name host-2`

## Phase 4: Adapter, scenarios and panel

- [X] T-R02G0205-004 [US1] [US2] [US3] [US4] Edit `Packages/ExperiencesRound02/LissajousLabyrinth/Core/LissajousLabyrinthExperienceCore.swift` (controls "level.select — Verified 2026-11-21: 2026-11-21 host-3 exit 0: LissajousLabyrinthExperienceCoreTests 14/14 (conformance; schema 2, digest v2, ten controls; campaign wins record stars and open the next level, locked select refused; daily records without opening, impossible date refused; practice allowance 64 records nothing; campaign returns to the frontier; undo after a failure rewinds; tutorial advances by action and hint, undo restores the digest but not the step, dismiss; schema-1 payload migrates and restores with the tutorial recomputed; practice round trip) and LissajousLabyrinthScenariosTests with the regenerated manifest (new refusals: locked, out of range, date, value counts)
  [1 … 100], mode.daily [year, month, day], mode.practice, mode.campaign, tutorial.dismiss"; practice allowance 64; daily
  wins record results without opening levels;
  choosing daily or practice drops the left level's records, mode.campaign returns to a fresh campaign play of the same
  level; the tutorial only on levels 1 … 3 in campaign mode, once per opening; progress and mode in the digest, the tutorial step in the snapshot only;
  the opened level's winning set as derived state; snapshot schema 2 `{level, records, progress, mode, tutorial}` with
  a 1 → 2 migration; codes r02-g02.locked, r02-g02.date), `Packages/ExperiencesRound02/LissajousLabyrinth/Core/LissajousLabyrinthScenarios.swift` and the regenerated
  `Packages/ExperiencesRound02/LissajousLabyrinth/scenario-manifest.json`, with `Packages/ExperiencesRound02/LissajousLabyrinth/CoreTests/LissajousLabyrinthExperienceCoreTests.swift` updates (conformance;
  actions; migration of a schema-1 payload; undo restores the digest with the tutorial advanced); `--name host-3 -- swift
  test --package-path Packages/ExperiencesRound02 --filter 'LissajousLabyrinthExperienceCoreTests|LissajousLabyrinthScenarios'`
- [X] T-R02G0205-005 [US1] [US2] [US3] [US4] Edit `Packages/ExperiencesRound02/LissajousLabyrinth/Experience/LissajousLabyrinthPresenter.swift` and — Verified 2026-11-21: 2026-11-21 sim-27 exit 0 on sim-27.2: LissajousLabyrinthTeachingTests 5/5 (three hint levels through the presenter, announced, hidden after a change, following the exact hint shortens the remaining solution; tutorial on levels 1 and 3 with dismiss; failure text equals the kernel's verdict, undo and retry; locked picker refused, a win opens the next level with 3 stars; daily 2026-01-02 is level 42 and records without opening, impossible date refused, practice allowance 64 records nothing, retry per mode); all 34 Lissajous experience tests. The tests found three presenter defects, fixed: daily Retry used today's date instead of the opening date, a win showed the stored best stars instead of this play's, and tutorial.hint was sent when the tutorial could not advance. The 313 render test now wins level 1 before level.next (progression)
  `Packages/ExperiencesRound02/LissajousLabyrinth/Experience/LissajousLabyrinthControls.swift` (instruction with Dismiss; Hint revealing the next level, reset after
  any change of the play; failure explanation with Undo and Retry; level picker of open levels with bands and stars;
  Campaign / Daily (local calendar date) / Practice) and create `Packages/ExperiencesRound02/LissajousLabyrinth/ExperienceTests/LissajousLabyrinthTeachingTests.swift`
  (agent D: hint levels through the presenter, failure text, picker refusals, daily and practice through the port, the
  tutorial on level 1); `--name sim-27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesRound02
  --scheme ExperiencesRound02-Package --destination sim-27.2 --action test`

## Phase 5: Regression, documentation and close

- [X] T-R02G0205-006 Docs: `docs/architecture/lissajous-labyrinth.md` (teaching and progression), — Verified 2026-11-21: 2026-11-21 round02-host exit 0; audits exit 0 (content audit of r02-g02.lissajous-labyrinth); docs/architecture/lissajous-labyrinth.md teaching and progression; package README; docs/automatedtesting.md (dense successor table for a hot search)
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host`; `--name audits -- python3
  scripts/verify_experiences.py --audits --only r02-g02.lissajous-labyrinth`
- [X] T-R02G0205-007 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`, — Verified 2026-11-21: 2026-11-21 rendering-27, rendering-26, experiences, host-full and app-unit exit 0
  `--name host-full`, `--name app-unit`
- [X] T-R02G0205-008 Reference regression chunk 1 (`--name reference-1`) — Verified 2026-11-21: 2026-11-21 reference-1 exit 0
- [X] T-R02G0205-009 Reference regression chunk 2 (`--name reference-2`) — Verified 2026-11-21: 2026-11-21 reference-2 exit 0: 7 of 7 with chunk 1
- [X] T-R02G0205-010 Script tests, run alone (`--name script-tests`) — Verified 2026-11-21: 2026-11-21 script-tests exit 0, run alone
- [ ] T-R02G0205-011 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record

## Dependencies and parallel work

001 → {002 (agent B), 003 (agent C)} → 004 (lead) → 005 (lead; agent D writes the simulator tests) → 006 … 011.
Shared files (adapter, scenarios, presenter, controls, docs) stay with the lead. MVP: Stories 2 and 3.
