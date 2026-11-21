# Tasks: R02-G03-05 — Wave Knot Keeper: progression and player teaching

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G03-05 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G03-05 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_325;
tests stay short (< 10 s each). No {owner} or {device} tasks.

## Phase 1: Setup

- [X] T-R02G0305-001 Baselines: `--name baseline-host`, `--name baseline-timing`, `--name baseline-round02 -- swift test — Verified 2026-11-21: 2026-11-21 baseline-round02, baseline-host, baseline-timing exit 0
  --package-path Packages/ExperiencesRound02`; the rendering baseline is R02-G03-04's runs (exit 0)

## Phase 2: Stories 2 and 3 — hints and failure explanations (P1) 🎯

- [X] T-R02G0305-002 [P] [US2] [US3] Edit `Packages/ExperiencesRound02/WaveKnotKeeper/Core/WaveKnotKeeperSolver.swift` (`solve(_:from:depth:)` "the certified — Verified 2026-11-21: 2026-11-21 host exit 0 (hints, solver, catalog)
  breadth-first search from a given rope, depth ≤ 3; solve(_:depth:) delegates, certified solutions unchanged") and
  create `Packages/ExperiencesRound02/WaveKnotKeeper/Core/WaveKnotKeeperHints.swift` (WaveKnotKeeperHint "levels 1 … 3: point, + axis, + exact direction, from
  the first move of the shortest remaining solution"; "No short solution from here; undo or retry" when none within
  depth 3 or the moves left; nil when not playing; WaveKnotKeeperFailureExplanation "The rope has c crossings and writhe
  w; the target is C and W." or "Two strands overlap in the view, so the crossings cannot be counted.", each followed by
  "Undo the last move or retry the level.") with `Packages/ExperiencesRound02/WaveKnotKeeper/CoreTests/WaveKnotKeeperHintsTests.swift` (agent B: certified
  solutions of all 100 levels unchanged; 2,000 seeded reachable states over all 100 levels: following the level-3 hint
  shortens the remaining shortest by one; levels 1 and 2 agree with level 3; no hint after the end; 500 seeded failures
  explained exactly); `--name host -- swift test --package-path Packages/ExperiencesRound02 --filter
  'WaveKnotKeeperHintsTests|WaveKnotKeeperSolverTests|WaveKnotKeeperCatalogTests'`

## Phase 3: Stories 1 and 4 — tutorial, progress, daily, practice (P1, P2)

- [X] T-R02G0305-003 [P] [US1] [US4] Create `Packages/ExperiencesRound02/WaveKnotKeeper/Core/WaveKnotKeeperProgress.swift` (WaveKnotKeeperTutorialStep "move(point) — Verified 2026-11-21: 2026-11-21 host-2 exit 0 (17 progress tests)
  → signature (an accepted move) → hints (the next accepted move or a hint) → done (a win); dismiss → done; undo never
  moves it back" with the texts of clarification Q2; WaveKnotKeeperMode "campaign, practice, daily(level)";
  WaveKnotKeeperProgress "level 1 open; a campaign win opens the next; a better result replaces a worse one; stars 3 at
  shortest, 2 within shortest + 2, else 1"; dailyLevel "(days from 2026-01-01 × 43) mod 100 + 1, negative counts
  wrapped; nil for an impossible date") with `Packages/ExperiencesRound02/WaveKnotKeeper/CoreTests/WaveKnotKeeperProgressTests.swift` (agent C: tutorial scripts
  on levels 1 … 3; scripted progress through 100 levels; stars; every date 2026-01-01 … 2036-12-31 maps to 1 … 100 and
  100 consecutive days visit every level; impossible dates refused; all 100 levels reachable by progress alone,
  FR-R02G0305-006); `--name host-2`

## Phase 4: Adapter, scenarios and panel

- [X] T-R02G0305-004 [US1] [US2] [US3] [US4] Edit `Packages/ExperiencesRound02/WaveKnotKeeper/Core/WaveKnotKeeperExperienceCore.swift` (controls "level.select — Verified 2026-11-21: 2026-11-21 host-3 exit 0 (adapter, scenarios, purity, panel win)
  [1 … 100], mode.daily [year, month, day], mode.practice, mode.campaign, tutorial.dismiss, tutorial.hint"; practice
  allowance 64; daily wins record results without opening levels; choosing daily or practice drops the left level's
  records, mode.campaign returns to a fresh campaign play of the same level; the tutorial only on levels 1 … 3 in
  campaign mode, once per opening; progress and mode in the digest, the tutorial step in the snapshot only; snapshot
  schema 2 `{level, records, progress, mode, tutorial}` with a 1 → 2 migration; codes r02-g03.locked, r02-g03.date),
  `Packages/ExperiencesRound02/WaveKnotKeeper/Core/WaveKnotKeeperScenarios.swift` and the regenerated `Packages/ExperiencesRound02/WaveKnotKeeper/scenario-manifest.json`, with
  `Packages/ExperiencesRound02/WaveKnotKeeper/CoreTests/WaveKnotKeeperExperienceCoreTests.swift` updates (conformance; actions; migration of a schema-1 payload;
  undo restores the digest with the tutorial advanced); `--name host-3 -- swift test --package-path
  Packages/ExperiencesRound02 --filter 'WaveKnotKeeperExperienceCoreTests|WaveKnotKeeperScenarios|WaveKnotKeeperRendererPurity|WaveKnotKeeperPanelWin'`
- [X] T-R02G0305-005 [US1] [US2] [US3] [US4] Edit `Packages/ExperiencesRound02/WaveKnotKeeper/Experience/WaveKnotKeeperPresenter.swift` and — Verified 2026-11-21: 2026-11-21 sim-27 exit 0 (iOS 27.2, teaching tests 6/6)
  `Packages/ExperiencesRound02/WaveKnotKeeper/Experience/WaveKnotKeeperControls.swift` (instruction with Dismiss; Hint revealing the next level, reset after any
  change of the play; failure explanation with Undo and Retry; level picker of open levels with bands and stars;
  Campaign / Daily (local calendar date) / Practice; the panel body split into small sections) and create
  `Packages/ExperiencesRound02/WaveKnotKeeper/ExperienceTests/WaveKnotKeeperTeachingTests.swift` (agent D: hint levels through the presenter, failure text, picker
  refusals, daily and practice through the port, the tutorial on level 1); `--name sim-27 -- python3
  scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package --destination
  sim-27.2 --action test`

## Phase 5: Regression, documentation and close

- [ ] T-R02G0305-006 Docs: `docs/architecture/wave-knot-keeper.md` (teaching and progression),
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host`; `--name audits -- python3
  scripts/verify_experiences.py --audits --only r02-g03.wave-knot-keeper`
- [ ] T-R02G0305-007 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`,
  `--name host-full`, `--name app-unit`
- [ ] T-R02G0305-008 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G0305-009 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G0305-010 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G0305-011 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record

## Dependencies and parallel work

001 → {002 (agent B), 003 (agent C)} → 004 (lead) → 005 (lead; agent D) → 006 … 011. Shared files (adapter, scenarios,
presenter, controls, docs) stay with the lead. MVP: Stories 1–3.
