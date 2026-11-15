# Tasks: Light Maze — Phase 00 Foundation and VisualCore boundary audit

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/contract.md](contracts/contract.md), [quickstart.md](quickstart.md). Gate A13-P00 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A13-P00 --timeout 600 --name <check> -- <command>`. Commit
after every task (no trailers); read every check's exit before ticking. No Swift, package or project change.

## Phase 1: Setup

- [X] T-A13-001 Create `docs/apps/light-maze/README.md` (what the experience is per the manual §1–§2: a tactile light-reflection puzzle with clear beams and deterministic rules; that it is an experience of the one app; its documents) and `docs/apps/light-maze/regression-baseline.md` with the phase start `57a587f9` (the specify commit; constitution `d5d232b6`) and the reference pin `d93edd1` — Verified 2026-11-15: 2026-11-15: docs/apps/light-maze/README.md and regression-baseline.md (phase start 57a587f9, constitution d5d232b6, pin d93edd1)

## Phase 3: User Story 1 — Evidence-backed integration matrix (P1) 🎯

- [X] T-A13-002 [US1] Write `docs/apps/light-maze/visualcore-contract.json` (schema 1; app `light-maze`; gate `A13-P00`): `inventory` of every FR-A13-001 area with paths, the release-check step count from `python3 scripts/release_check.py --list`; `matrix` rows covering the 5 brainstorm capabilities and 6 version 0.1 features plus cross-cutting rows (beam geometry from the CPU tracer only, determinism and replay, bounded content, persistence, quality tiers and low power, accessibility with Reduce Motion and Reduce Flashing, lifecycle and context loss, sound and haptic feedback, licenses) with status ∈ {available, requires adaptation, upstream gap} per clarification 2 and file/symbol/product evidence; `traceability`; `negative` rules of FR-A13-006 (FR-A13-001, 002) — Verified 2026-11-15: 2026-11-15: docs/apps/light-maze/visualcore-contract.json (schema 1; inventory with 118 release-check steps; 20 rows: 10 available, 8 requires adaptation, 2 upstream gap; traceability of 5 capabilities and 6 features; 12 negative rules)
- [X] T-A13-003 [US1] Run the contract checker and render the view (`--name contract -- python3 scripts/check_app_contract.py --app light-maze --render`); `docs/apps/light-maze/visualcore-contract.md` is generated (FR-A13-007, SC-A13-001) — Verified 2026-11-15: 2026-11-15: .autonomy/checks/A13-P00.contract.json exit 0 (PASS 20 rows, 111 citations, 7 gaps); visualcore-contract.md rendered

## Phase 4: User Story 2 — The reference stays proven (P1)

- [X] T-A13-004 [US2] Reference chunk 1 (`--name reference-1 -- python3 scripts/release_check.py --only reference-engine-xcframework reference-build-projectm-ios-sim reference-clean`) — Verified 2026-11-15: 2026-11-15: .autonomy/checks/A13-P00.reference-1.json exit 0 (3/3 steps)
- [X] T-A13-005 [US2] Reference chunk 2 (`--name reference-2 -- python3 scripts/release_check.py --only reference-test-anglerendering-ios27 reference-test-anglerendering-ios26 projectm-reference-ios27 projectm-reference-ios26`); record the 7 steps, commands and results in `docs/apps/light-maze/regression-baseline.md` (FR-A13-004, SC-A13-003) — Verified 2026-11-15: 2026-11-15: .autonomy/checks/A13-P00.reference-2.json exit 0 (4/4 steps); 7 steps recorded in docs/apps/light-maze/regression-baseline.md

## Phase 5: User Story 3 — The shell builds with the experience absent (P2)

- [X] T-A13-006 [US3] Build the one app for testing (`--name app-build -- python3 scripts/release_check.py --only app-build-for-testing-ios27`) — Verified 2026-11-15: 2026-11-15: .autonomy/checks/A13-P00.app-build.json exit 0 (iOS 27.2 phone simulator; the attestation was committed with T-A13-004)
- [X] T-A13-007 [US3] Experience package check (`--name experience-packages -- python3 scripts/check_experience_packages.py`: 12 experiences, none A13); `grep -c a13 Catalog/registrations.json Apps/VisualCore/App/ExperienceRegistry.swift` gives 0 (FR-A13-005, SC-A13-004) — Verified 2026-11-15: 2026-11-15: .autonomy/checks/A13-P00.experience-packages.json exit 0 (12 experiences, none A13; committed with T-A13-004); grep -c a13 gives 0 in Catalog/registrations.json and ExperienceRegistry.swift

## Phase 6: User Story 4 — Stop/go decision (P2)

- [X] T-A13-008 [US4] Complete the contract's `gaps` (every non-available row: owning module, VisualCore or app-local, and phase A13-P01..P06) and `decision` (verdict and reasons; "stop" if no working host or buildable 2D drawing path; the tile board, snapped drag and rotate, 2D ray propagation with reflection, bounce cap and cycle detection, levels, progression, undo and restart, beam glow and colour cues, solvability check, success feedback and saved progress assessed per FR-A13-003 with the owners of clarification 5); re-run the checker (`--name contract-final -- python3 scripts/check_app_contract.py --app light-maze --render`) (FR-A13-003, 006; SC-A13-002) — Verified 2026-11-15: 2026-11-15: gaps G-RAYCAST2D (VisualCoreMath, P01), G-BOARD (P01), G-BEAMS and G-SNAP (P02), G-LEVELS (P03, also licenses), G-FEEDBACK (P04), G-SOLVER (P05); decision go (RenderHost, PrimitiveRenderer, EffectScene exist); .autonomy/checks/A13-P00.contract-final.json exit 0

## Phase 7: Polish and evidence

- [X] T-A13-009 No-change proof (`--name no-change -- git diff --exit-code --stat 57a587f9..HEAD -- Packages External`) (FR-A13-008, SC-A13-005) — Verified 2026-11-15: 2026-11-15: .autonomy/checks/A13-P00.no-change.json exit 0 (empty diff 57a587f9..HEAD of Packages External)
- [X] T-A13-010 Script tests (`--name script-tests -- python3 scripts/test_scripts.py`) and the release-check document steps (`--name fast-checks -- python3 scripts/release_check.py --only docs app-contracts compliance dependencies`); every run-check of this gate stays within its 600 s limit and the contract check under 10 s (SC-A13-006) — Verified 2026-11-15: 2026-11-15: .autonomy/checks/A13-P00.script-tests.json exit 0; .autonomy/checks/A13-P00.fast-checks.json exit 0 (docs, app-contracts, compliance, dependencies 4/4); every run-check within 600 s, contract check 0.04 s
- [X] T-A13-011 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record A13-P00; update README.md (status, gate count) in the record commit (rule 16) — Verified 2026-11-15: 2026-11-15: /speckit-converge round 1 appended T-A13-012 (done); round 2 appended nothing (8 FR, 6 SC, 4 stories, 12 tasks with evidence; contract 20 rows, 7 gaps, decision go)

## Dependencies

T-A13-001 → T-A13-002 → T-A13-003 → T-A13-008; T-A13-004/005 and 006/007 are independent of the contract (reference
and app build run serially: one xcodebuild at a time); Polish last.

## Parallel examples

Agent: T-A13-002 (contract draft, read-heavy). Lead: T-A13-001, the runs, T-A13-008 review, ticks and commits.

## Implementation strategy

MVP is US1 (the matrix) with US2 (reference); US3 and US4 complete the gate.

## Phase 8: Convergence

- [X] T-A13-012 Record in `specs/095-lm-p00-boundary-audit/research.md` the audit's findings beyond D4 (`VisualCoreSimulation.Collision2D` with closest point on a segment and swept circles, still no ray cast or reflection; `StateSign` and `AccessibleColors.contrastRatio` for colour-independent cues; `EffectScene` as the effect wrapper experiences use; 118 release-check steps; licenses (M20) covered by G-LEVELS and rechecked with G-SOLVER) per plan: research D4 (partial) — Verified 2026-11-15: 2026-11-15: research.md §2 As found records Collision2D (no ray cast), StateSign and contrastRatio, EffectScene and maxPasses 32, licenses under G-LEVELS and G-SOLVER, 118 release-check steps; matches docs/apps/light-maze/visualcore-contract.json (checked by .autonomy/checks/A13-P00.contract-final.json exit 0)
