# Tasks: Physics Playground — Phase 00 Foundation and VisualCore boundary audit

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/contract.md](contracts/contract.md), [quickstart.md](quickstart.md). Gate A11-P00 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A11-P00 --timeout 600 --name <check> -- <command>`. Commit
after every task (no trailers); read every check's exit before ticking. No Swift, package or project change.

## Phase 1: Setup

- [X] T-A11-001 Create `docs/apps/physics-playground/README.md` (what the experience is per the manual §1–§2: a deterministic 2D sandbox for gravity, collisions, springs and forces, educational approximation; that it is an experience of the one app; its documents) and `docs/apps/physics-playground/regression-baseline.md` with the phase start `d3797d7c` (the specify commit; constitution `35c24d86`) and the reference pin `d93edd1` — Verified 2026-11-15: 2026-11-15: docs/apps/physics-playground/README.md and regression-baseline.md (phase start d3797d7c, constitution 35c24d86, pin d93edd1; reference 7/7 recorded); committed with the contract they link to

## Phase 3: User Story 1 — Evidence-backed integration matrix (P1) 🎯

- [X] T-A11-002 [US1] Write `docs/apps/physics-playground/visualcore-contract.json` (schema 1; app `physics-playground`; gate `A11-P00`): `inventory` of every FR-A11-001 area with paths, the release-check step count from `python3 scripts/release_check.py --list`; `matrix` rows covering the 5 brainstorm capabilities and 6 version 0.1 features plus cross-cutting rows (fixed step and step policy, stability and body budget, persistence, quality tiers and low power, accessibility and Reduce Motion, lifecycle, licenses) with status ∈ {available, requires adaptation, upstream gap} per clarification 2 and file/symbol/product evidence; `traceability`; `negative` rules of FR-A11-006 (FR-A11-001, 002) — Verified 2026-11-15: 2026-11-15: visualcore-contract.json, 18 rows (9 available, 6 adaptation, 3 upstream), 8 gaps, 108 release steps, 10 registered experiences, decision go
- [X] T-A11-003 [US1] Run the contract checker and render the view (`--name contract -- python3 scripts/check_app_contract.py --app physics-playground --render`); `docs/apps/physics-playground/visualcore-contract.md` is generated (FR-A11-007, SC-A11-001) — Verified 2026-11-15: 2026-11-15: .autonomy/checks/A11-P00.contract.json exit 0 (PASS 18 rows, 104 citations, 8 gaps); visualcore-contract.md rendered

## Phase 4: User Story 2 — The reference stays proven (P1)

- [X] T-A11-004 [US2] Reference chunk 1 (`--name reference-1 -- python3 scripts/release_check.py --only reference-engine-xcframework reference-build-projectm-ios-sim reference-clean`) — Verified 2026-11-15: 2026-11-15: .autonomy/checks/A11-P00.reference-1.json exit 0
- [X] T-A11-005 [US2] Reference chunk 2 (`--name reference-2 -- python3 scripts/release_check.py --only reference-test-anglerendering-ios27 reference-test-anglerendering-ios26 projectm-reference-ios27 projectm-reference-ios26`); record the 7 steps, commands and results in `docs/apps/physics-playground/regression-baseline.md` (FR-A11-004, SC-A11-003) — Verified 2026-11-15: 2026-11-15: .autonomy/checks/A11-P00.reference-2.json exit 0; regression-baseline.md records 7/7 pass

## Phase 5: User Story 3 — The shell builds with the experience absent (P2)

- [X] T-A11-006 [US3] Build the one app for testing (`--name app-build -- python3 scripts/release_check.py --only app-build-for-testing-ios27`) — Verified 2026-11-15: 2026-11-15: .autonomy/checks/A11-P00.app-build.json exit 0 (iOS 27.2 phone simulator)
- [X] T-A11-007 [US3] Experience package check (`--name experience-packages -- python3 scripts/check_experience_packages.py`: 10 experiences, none A11); `grep -c a11 Catalog/registrations.json Apps/VisualCore/App/ExperienceRegistry.swift` gives 0 (FR-A11-005, SC-A11-004) — Verified 2026-11-15: 2026-11-15: .autonomy/checks/A11-P00.experience-packages.json exit 0 (10 experiences, none A11); grep a11 in registrations.json and ExperienceRegistry.swift gives 0

## Phase 6: User Story 4 — Stop/go decision (P2)

- [X] T-A11-008 [US4] Complete the contract's `gaps` (every non-available row: owning module, VisualCore or app-local, and phase A11-P01..P06) and `decision` (verdict and reasons; "stop" if no working host or buildable drawing path; circles and boxes with rigid-body collision including static bodies, gravity, springs and drag, spawn/grab/pin/delete gestures, pause, single step, time scale and reset, presets, vector overlays and the state panel, saved experiments, and stability and body-count caps assessed per FR-A11-003 with the owners of clarification 5); re-run the checker (`--name contract-final -- python3 scripts/check_app_contract.py --app physics-playground --render`) (FR-A11-003, 006; SC-A11-002) — Verified 2026-11-15: 2026-11-15: .autonomy/checks/A11-P00.contract-final.json exit 0; 8 gaps with owners and phases (G-RIGIDBODY, G-CONTENTLICENSES app-local P01; G-CONTACTS, G-SPRINGS VisualCoreSimulation P02; G-EDITOR, G-OVERLAYS P03; G-EXPERIMENTS P04; G-STABILITY P05); decision go

## Phase 7: Polish and evidence

- [X] T-A11-009 No-change proof (`--name no-change -- git diff --exit-code --stat d3797d7c..HEAD -- Packages External`) (FR-A11-008, SC-A11-005) — Verified 2026-11-15: 2026-11-15: .autonomy/checks/A11-P00.no-change.json exit 0 (empty diff d3797d7c..HEAD of Packages External)
- [X] T-A11-010 Script tests (`--name script-tests -- python3 scripts/test_scripts.py`) and the release-check document steps (`--name fast-checks -- python3 scripts/release_check.py --only docs app-contracts compliance dependencies`); every run-check of this gate stays within its 600 s limit and the contract check under 10 s (SC-A11-006) — Verified 2026-11-15: 2026-11-15: .autonomy/checks/A11-P00.{script-tests,fast-checks}.json exit 0; every run under 600 s, contract check under 10 s
- [X] T-A11-011 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record A11-P00; update README.md (status, gate count) in the record commit (rule 16) — Verified 2026-11-15: 2026-11-15: /speckit-converge appended nothing (8 FR, 6 SC, 4 stories, 10 tasks with evidence; contract 18 rows, 8 gaps, decision go)

## Dependencies

T-A11-001 → T-A11-002 → T-A11-003 → T-A11-008; T-A11-004/005 and 006/007 are independent of the contract (reference
and app build run serially: one xcodebuild at a time); Polish last.

## Parallel examples

Agent: T-A11-002 (contract draft, read-heavy). Lead: T-A11-001, the runs, T-A11-008 review, ticks and commits.

## Implementation strategy

MVP is US1 (the matrix) with US2 (reference); US3 and US4 complete the gate.
