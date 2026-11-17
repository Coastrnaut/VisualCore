# Tasks: Ambient Clock — Phase 00 Foundation and VisualCore boundary audit

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/contract.md](contracts/contract.md), [quickstart.md](quickstart.md). Gate A18-P00 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A18-P00 --timeout 600 --name <check> -- <command>`. Commit
after every task (no trailers); read every check's exit before ticking. No Swift, package or project change.
Precedent: `specs/123-ia-p00-boundary-audit/tasks.md`.

## Phase 1: Setup

- [X] T-A18-001 Create `docs/apps/ambient-clock/README.md` (what the experience is per the manual §1–§2: a calm, readable clock over procedural shader themes, offline, with night mode and screen care; that it is an experience of the one app; its documents) and `docs/apps/ambient-clock/regression-baseline.md` with the phase start `43f3eb05` (the specify commit; constitution `84b3b311`) and the reference pin `d93edd1` — Verified 2026-11-16: 2026-11-16: docs/apps/ambient-clock/README.md and regression-baseline.md written (phase start 43f3eb05, constitution 84b3b311, reference pin d93edd1); validate_docs.py PASS

## Phase 3: User Story 1 — Evidence-backed integration matrix (P1) 🎯

- [X] T-A18-002 [US1] Write `docs/apps/ambient-clock/visualcore-contract.json` (schema 1; app `ambient-clock`; gate `A18-P00`): `inventory` of every FR-A18-001 area with paths and the release-check step count from `python3 scripts/release_check.py --list`; `matrix` rows covering the 5 brainstorm capabilities (shader backgrounds, animation, typography integration, scene transitions, configuration and presets) and the 6 version 0.1 features (research D2) plus cross-cutting rows (injected clock and time-change handling, the canvas overlay for text, contrast, Dynamic Type and VoiceOver, favourites with schema and migration, quality tiers and budgets, night mode drawn in the scene, screen care and keep-awake, lifecycle with resize and context loss, licenses, truthful claims) with status ∈ {available, requires adaptation, upstream gap} per clarification 2 and evidence files, symbols and products verified in code; `traceability`; `negative` per FR-A18-006 (FR-A18-001, 002, 006) — Verified 2026-11-16: 2026-11-16: docs/apps/ambient-clock/visualcore-contract.json written (11 inventory areas, 143 release-check steps; 28 matrix rows: 9 available, 14 requires adaptation, 5 upstream gap; 15 gaps; 15 negative entries incl. the three manual risks; decision go); written by an agent, rechecked: check_app_contract.py PASS (28 rows, 137 citations); ExperienceSession.swift:287 builds RenderHost with the default frame cap (G-FRAMERATE)
- [X] T-A18-003 [US1] Run the contract checker and render the view (`--name contract -- python3 scripts/check_app_contract.py --app ambient-clock --render`); `docs/apps/ambient-clock/visualcore-contract.md` is generated (FR-A18-007, SC-A18-001) — Verified 2026-11-16: 2026-11-16: .autonomy/checks/A18-P00.contract-2.json exit 0 (PASS: 28 rows, 137 citations, 15 gaps, decision go); visualcore-contract.md generated between its markers; correction: the first run, A18-P00.contract.json, exited 1 because the view file had no markers yet

## Phase 4: User Story 2 — The reference stays proven (P1)

- [X] T-A18-004 [US2] Reference chunk 1 (`--name reference-1 -- python3 scripts/release_check.py --only reference-engine-xcframework reference-build-projectm-ios-sim reference-clean`) — Verified 2026-11-16: 2026-11-16: .autonomy/checks/A18-P00.reference-1.json exit 0 (reference-engine-xcframework, reference-build-projectm-ios-sim, reference-clean pass)
- [X] T-A18-005 [US2] Reference chunk 2 (`--name reference-2 -- python3 scripts/release_check.py --only reference-test-anglerendering-ios27 reference-test-anglerendering-ios26 projectm-reference-ios27 projectm-reference-ios26`); record the 7 steps, commands and results in `docs/apps/ambient-clock/regression-baseline.md` (FR-A18-004, SC-A18-003) — Verified 2026-11-16: 2026-11-16: .autonomy/checks/A18-P00.reference-2.json exit 0 (the four ANGLE and ProjectM reference tests on iOS 27 and 26 pass); 7 of 7 steps recorded in docs/apps/ambient-clock/regression-baseline.md

## Phase 5: User Story 3 — The shell builds with the experience absent (P2)

- [ ] T-A18-006 [US3] Build the one app for testing (`--name app-build -- python3 scripts/release_check.py --only app-build-for-testing-ios27`)
- [ ] T-A18-007 [US3] Experience package check (`--name experience-packages -- python3 scripts/check_experience_packages.py`: 17 experiences, none A18); `grep -c a18 Catalog/registrations.json Apps/VisualCore/App/ExperienceRegistry.swift` gives 0 (FR-A18-005, SC-A18-004)

## Phase 6: User Story 4 — Stop/go decision (P2)

- [ ] T-A18-008 [US4] Complete the contract's `gaps` (every non-available row: owning module, VisualCore or app-local, and phase A18-P01..P06 per research D4, with G-CLOCK `VisualCore:VisualCoreExperience` A18-P01 and G-TRANSITION `VisualCore:VisualCoreRendering` A18-P03 assessed), the three manual risks as `negative` entries naming owner, verification method and release-blocker condition (source "manual §13 risk N"), and `decision` (keys `result`, `reasons`, `blockers`; "stop" if no working host or buildable text-over-shader path); re-run the checker (`--name contract-final -- python3 scripts/check_app_contract.py --app ambient-clock --render`) (FR-A18-003, 006; SC-A18-002)

## Phase 7: Polish and evidence

- [ ] T-A18-009 No-change proof (`--name no-change -- git diff --exit-code --stat 43f3eb05..HEAD -- Packages External`) (FR-A18-008, SC-A18-005)
- [ ] T-A18-010 Script tests (`--name script-tests -- python3 scripts/test_scripts.py`) and the release-check document steps (`--name fast-checks -- python3 scripts/release_check.py --only docs app-contracts compliance dependencies`); every run-check of this gate stays within its 600 s limit and the contract check under 10 s (SC-A18-006)
- [ ] T-A18-011 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record A18-P00; update README.md (status, gate count) in the record commit (rule 16) and `docs/automatedtesting.md` if a test tool, rule or lesson changed (rule 17)

## Dependencies

T-A18-001 → T-A18-002 → T-A18-003 → T-A18-008; T-A18-004/005 and 006/007 are independent of the contract (reference
and app build run serially: one xcodebuild at a time); Polish last.

## Parallel examples

Agent: T-A18-002 (the read-heavy contract audit). Lead: T-A18-001, the reference and build runs (004–007), the gap
completion review (008), the proofs and commits.

## Implementation strategy

MVP: the contract (002, 003, 008) with the baseline (001, 004, 005); the build proof (006, 007) and evidence close the
phase. Review checkpoint after 003 (checker passes) and at 008 (decision).
