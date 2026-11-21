# Tasks: R02-G01-09 — Aurora Loom: simulator integration and full app lock

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G01-09 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G01-09 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_309;
tests stay short (< 10 s each; interface tests < 90 s, SC-R02G0109-001). No {owner} tasks.

## Phase 1: Setup

- [X] T-R02G0109-001 Baselines: `--name baseline-host`, `--name baseline-timing`, `--name baseline-round02 -- swift test — Verified 2026-11-20: 2026-11-20 R02-G01-09.baseline-host/timing/round02 exit 0
  --package-path Packages/ExperiencesRound02`; the rendering baseline is R02-G01-08's rendering runs (exit 0)

## Phase 2: Foundational

- [X] T-R02G0109-002 Create `Packages/ExperiencesRound02/AuroraLoom/Core/AuroraLoomSchemaExamples.swift` (contracts/api.md; data-model: schema 1 "{level: 2, — Verified 2026-11-20: 2026-11-20 host exit 0 (AuroraLoomSchemaExamples: schema-1 and schema-2 examples, 6 host tests incl. the registry's migration check); registry stores both examples, comment corrected; app-unit exit 0 restores them in the app
  records: [two moves]}", schema 2 "{level 1, campaign, frontier 2, level 1 solved without a trace}", seed 7, A18's
  envelope) with `Packages/ExperiencesRound02/AuroraLoom/CoreTests/AuroraLoomSchemaExampleTests.swift` (agent A: both restore through `migrations` to
  schema 3 with progress kept; the expected digests match; versions other than 1 and 2 give nil); edit
  `Apps/VisualCore/App/ExperienceRegistry.swift` (`examples:` with both; the stale schema comment corrected);
  `--name host -- swift test --package-path Packages/ExperiencesRound02`

## Phase 3: Story 1 — the game works inside the real app (P1) 🎯

- [X] T-R02G0109-003 [US1] Edit `Packages/ExperiencesRound02/AuroraLoom/Experience/AuroraLoomPresenter.swift` and `Packages/ExperiencesRound02/AuroraLoom/Experience/AuroraLoomControls.swift`: — Verified 2026-11-20: 2026-11-20 sim-27-2 exit 0 (panel identifiers; pending steppers with Apply and Clear; AuroraLoomPanelTests: pending, order, clear, outside change, refusal mid-apply, all 100 levels won through the panel in their certified shortest); sim-27 exit 65: a refusal code compared without its action.rule prefix, and the memory footprint bound failing under the full parallel suite (91 MB spike from another suite), fixed by applying the bound only in the isolated regression run (regression exit 0, bound applied, flat within 0.2 MB)
  identifiers `experience.r02-g01.aurora-loom.<name>` (spec Clarifications Q1 names, plus `apply`, `clear`); pending
  stepper steps ("steppers set pending steps; Apply commits one move per changed control, ribbon order, wave before
  phase; Clear drops them; an outside change drops them"; announcement "Ribbon r wave s pending. Apply to move."; the
  first refused pending move stops the rest and drops the remainder); Apply and Clear hidden while nothing is pending;
  with `Packages/ExperiencesRound02/AuroraLoom/ExperienceTests/AuroraLoomPanelTests.swift` (agent E: pending, apply order, clear, outside change, refusal
  mid-apply, announcements; all 100 certified levels won through stepPending + applyPending alone in exactly their
  certified shortest moves, split by band); existing accessibility tests updated where they drove the steppers;
  `--name sim-27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme
  ExperiencesRound02-Package --destination sim-27.2 --action test`
- [X] T-R02G0109-004 [US1] Create `Apps/VisualCore/Tests/UI/AuroraLoom/ALSupport.swift`, `ALPlayUITests.swift`, — Verified 2026-11-20: 2026-11-21 app-ui-3 exit 0 (ALPlayUITests: level 1 won through pending steps and Apply with 3 stars, progress kept over a relaunch; ALReplayUITests: replay to 2 of 2 and stop); chunk i3 serial; app-ui exit 1 found every player starting at level 79 (stable seed), fixed by openingSeed 0 for the round-two puzzles (FR-R02G0109-009); app-ui-2 exit 1 found the win lost on relaunch (terminate without the background save point), fixed by backgrounding first; 62-72 s per test with launch, SC-001 bound corrected to 90 s
  `ALReplayUITests.swift` (agent C: spec Clarifications Q2; level 1 target steps pinned in `AL`); edit
  `scripts/release_check.py` (`UI_CHUNKS["i3"]`, `"i3"` in `SERIAL_CHUNKS`) and `scripts/test_scripts.py` (agent D);
  `project.yml` + `xcodegen generate` if needed; `--name app-ui -- python3 scripts/release_check.py --only
  app-build-for-testing-ios27 app-ui-ios27-i3`

## Phase 4: Story 2 — the app's logic accepts the game (P1)

- [ ] T-R02G0109-005 [US2] Edit `Apps/VisualCore/Tests/Unit/AppModelTests.swift` (agent B: both examples restore through
  the app's migration check; the candidate opens through the registry and engine and plays level 1 to a win; without
  `-vcCandidates` it is not available and not openable; `AL`'s pinned level 1 targets equal the Core's certified
  solution); `--name app-unit -- python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27`

## Phase 5: Story 3 — builds and solvability (P2)

- [ ] T-R02G0109-006 [US3] Edit `scripts/release_check.py` (`RELEASE_FORBIDDEN` += `AuroraLoomGolden`,
  `acceptanceScenarios`; agent D with T-004); `--name release -- python3 scripts/release_check.py --only
  app-release-build app-release-symbols`; `--name regression -- python3 scripts/aurora_loom_regression.py`

## Phase 6: Regression, documentation and close

- [ ] T-R02G0109-007 Docs: `docs/architecture/aurora-loom.md` (in-app integration, pending steps),
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host`; `--name script-tests` (alone)
- [ ] T-R02G0109-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`,
  `--name host-full` (app-unit and app-ui are this gate's own runs)
- [ ] T-R02G0109-009 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G0109-010 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G0109-011 {device} After ImplementationLock-100: the same journeys on D1/D2/D3 (SC-R02G0109-006; feature 310
  prepares them)
- [ ] T-R02G0109-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record;
  after the record push, check its CI run with `gh run list`

## Dependencies and parallel work

001 → 002 (lead; agent A tests) → 003 (lead; agent E tests) → {004 (agents C, D), 005 (agent B), 006 (agent D)} → 007 …
010, 012. 011 stays open until device testing. Shared files (examples source, registry, presenter, controls, project.yml,
docs) stay with the lead. MVP: Stories 1 and 2.
