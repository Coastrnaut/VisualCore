# Tasks: R02-G08-05 — Faceted Forge: progression and player teaching

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G08-05 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G08-05 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_375;
tests stay short (< 10 s each). No {owner} or {device} tasks (no device-only behaviour in this feature).

## Phase 1: Setup

- [X] T-R02G0805-001 Baselines: `--name baseline-host`, `--name baseline-timing`, `--name baseline-round02 -- swift test — Verified 2026-11-22: 2026-11-22: baseline-host, baseline-timing, baseline-round02 exit 0 (committed tree); rendering baseline = R02-G08-04 rendering-27/26 exit 0
  --package-path Packages/ExperiencesRound02`; the rendering baseline is R02-G08-04's rendering runs (exit 0)

## Phase 2: Stories 2 and 3 — hints and failure explanation (P1) 🎯

- [X] T-R02G0805-002 [P] [US2] [US3] Add `solve(_:from:cutsLeft:workBound:)` to — Verified 2026-11-22: 2026-11-22: host-2 (FacetedForgeHintsTests 7 tests/42 cases incl. all 100 levels won by hints, solver, invariant and catalog tests: 35 tests) exit 0, rerun by the lead; catalog digest and witnesses unchanged
  `Packages/ExperiencesRound02/FacetedForge/Core/FacetedForgeSolver.swift` (the same bounded depth-first search started
  at given pieces, looking for exactly `cutsLeft` more cuts; `solve(_:workBound:)` equals it from the crystal) and
  create `Packages/ExperiencesRound02/FacetedForge/Core/FacetedForgeHints.swift` (`FacetedForgePlan`, `FacetedForgeHint`
  with levels 1 … 3 and the texts of clarification Q1, `FacetedForgeHints.plan`/`hint` — the plan only when target
  pieces − current pieces ≥ 0 fits in the cuts left and `canPartition` holds; `FacetedForgeFailureExplanation` with the
  texts of clarification Q5) with `Packages/ExperiencesRound02/FacetedForge/CoreTests/FacetedForgeHintsTests.swift`
  (following exact hints from the opening wins all 100 certified levels, in parallel groups under 10 s each; 200 seeded
  reachable states (seed 2_375): every exact hint is a legal cut, from every state with a plan following hints wins, a
  state without a plan has no winning continuation by an independent exhaustive check where it is small enough; 500
  seeded failures explained with their true reason, piece, cut and share or cuts and pieces; a hint never changes the
  play); agent B; `--name host-2`

## Phase 3: Stories 1 and 4 — tutorial and progress (P1, P2)

- [X] T-R02G0805-003 [P] [US1] [US4] Create `Packages/ExperiencesRound02/FacetedForge/Core/FacetedForgeProgress.swift` — Verified 2026-11-22: 2026-11-22: host-3 (FacetedForgeProgressTests 10 + invariant tests 9) exit 0, rerun by the lead
  (`FacetedForgeTutorialStep` aim → match → finish → done with the texts of clarification Q2; `FacetedForgeProgress` "3
  when at most the certified smallest cut count, 2 when at most that + 2, else 1" by cuts made (cut records, undone ones
  included), frontier, best cuts made; `dailyLevel(year:month:day:)` "(days from 2026-01-01 × 67) mod 100 + 1, negative
  day counts wrapped", nil for an impossible date; `FacetedForgeMode` campaign, practice, daily(level)) with
  `Packages/ExperiencesRound02/FacetedForge/CoreTests/FacetedForgeProgressTests.swift` (tutorial steps on levels 1 … 3
  by scripted plays; stars and frontier over a 100-level script; every date 2026-01-01 … 2036-12-31 gives a level in 1 …
  100, stable; impossible dates nil); agent C; `--name host-3`

## Phase 4: Adapter, scenarios, presenter

- [X] T-R02G0805-004 Edit `Packages/ExperiencesRound02/FacetedForge/Core/FacetedForgeExperienceCore.swift` (controls — Verified 2026-11-22: 2026-11-22: host-4 (all FacetedForge host tests, 179) exit 0; schema 2 with migration, new controls, manifest regenerated; a redo never advances the tutorial (agent finding)
  `level.select [1 … 100]`, `mode.daily [year, month, day]`, `mode.practice`, `mode.campaign`, `tutorial.dismiss`; codes
  `r02-g08.locked`, `r02-g08.date`; practice budget 20 on a copy of the level, no stars, no unlocks; daily opens
  nothing; progress and mode in the digest, the tutorial step snapshotted but not digested; snapshot schema 2 `{level,
  records, progress, mode, tutorial}` with a migration from 1 "level 1 open plus the restored level, campaign mode,
  tutorial at its first step on tutorial levels"; `level.next` to the next open level) with tests in
  `Packages/ExperiencesRound02/FacetedForge/CoreTests/FacetedForgeExperienceCoreTests.swift` (new controls, refusals,
  schema 2 round trip, migration from a schema-1 payload, newer schema refused); regenerate
  `Packages/ExperiencesRound02/FacetedForge/Core/FacetedForgeScenarios.swift` entries where needed and
  `Packages/ExperiencesRound02/FacetedForge/scenario-manifest.json` (`UPDATE_SCENARIO_MANIFEST=1`); lead; `--name host-4
  -- swift test --package-path Packages/ExperiencesRound02 --filter FacetedForge`
- [X] T-R02G0805-005 Edit `Packages/ExperiencesRound02/FacetedForge/Experience/FacetedForgePresenter.swift` (the — Verified 2026-11-22: 2026-11-22: sim-27 (FacetedForgeExperienceTests, 46 tests incl. 7 teaching tests, iOS 27.2) exit 0; an unrecorded first run failed only the identity test's four-control list, updated to the nine controls
  tutorial instruction, the hint at its current level — "Hint" raises the level 1 → 2 → 3, any play change resets it —
  and the failure explanation as panel text; the description includes them) and
  `Packages/ExperiencesRound02/FacetedForge/Experience/FacetedForgeControls.swift` (Hint, Dismiss tutorial, level picker
  for open levels, Practice, Daily (today's local date from the presenter), Campaign); agent D writes
  `Packages/ExperiencesRound02/FacetedForge/ExperienceTests/FacetedForgeTeachingTests.swift` (the panel shows the
  tutorial, the three hint levels and the failure text; mode and level controls reach the adapter); `--name sim-27 --
  python3 scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package
  --destination sim-27.2 --action test --only-testing FacetedForgeExperienceTests`

## Phase 5: Regression, documentation and close

- [X] T-R02G0805-006 Docs: `docs/architecture/faceted-forge.md` (teaching and progression), — Verified 2026-11-22: 2026-11-22: round02-host (swift test --package-path Packages/ExperiencesRound02) exit 0; architecture, package README and testing doc updated
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host`
- [X] T-R02G0805-007 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`, — Verified 2026-11-22: 2026-11-22: rendering-27, rendering-26, experiences, host-full, app-unit exit 0
  `--name host-full`, `--name app-unit`
- [X] T-R02G0805-008 Reference regression chunk 1 (`--name reference-1`) — Verified 2026-11-22: 2026-11-22: reference-1 exit 0
- [X] T-R02G0805-009 Reference regression chunk 2 (`--name reference-2`) — Verified 2026-11-22: 2026-11-22: reference-2 exit 0
- [X] T-R02G0805-010 Script tests, run alone (`--name script-tests`) — Verified 2026-11-22: 2026-11-22: script-tests (run alone) exit 0
- [X] T-R02G0805-011 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record — Verified 2026-11-22: 2026-11-22: converge round 2 clean; sealed and recorded pass

## Dependencies and parallel work

001 → {002 (agent B), 003 (agent C)} → 004 (lead) → 005 (lead; agent D writes the teaching tests) → 006 … 011. Shared
files (adapter, scenarios, presenter, controls, docs) stay with the lead. MVP: Stories 1–3.


## Phase 6: Convergence

- [X] T-R02G0805-012 Keep a hint search off the frame per the Spec's edge case "A hint search that would run long … it — Verified 2026-11-22: 2026-11-22: sim-27-3 (47 tests incl. aHintSearchNeverBlocksAndACutDiscardsIt) exit 0; sim-27-2 failed to compile (a test used an undeclared type alias), fixed
  never stalls the frame" (partial): in `Packages/ExperiencesRound02/FacetedForge/Experience/FacetedForgePresenter.swift`
  compute `core.hint(level:)` in a detached task (the core is a value), show "Finding a hint…" in the mirror meanwhile,
  publish the result on the main actor only when the play it belongs to (level, mode, fingerprint) is still the current
  one, and cache the plan's hints per play so later levels of the same play are immediate; cover it in
  `Packages/ExperiencesRound02/FacetedForge/ExperienceTests/FacetedForgeTeachingTests.swift` (the hint arrives without
  blocking the press; a cut before it arrives discards it); `--name sim-27-2`
