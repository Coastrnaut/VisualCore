# Tasks: Neon Arcade — Phase 00 Foundation and VisualCore boundary audit

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/contract.md](contracts/contract.md), [quickstart.md](quickstart.md). Gate A10-P00 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A10-P00 --timeout 600 --name <check> -- <command>`. Commit after every task (no trailers). No Swift, package or project change.

## Phase 1: Setup

- [ ] T-A10-001 Create `docs/apps/neon-arcade/README.md` (what the experience is per the manual §1–§2: Neon Dodge, one complete game, that it is an experience of the one app, its documents) and `docs/apps/neon-arcade/regression-baseline.md` with the phase start `8e4fcdbe` (the specify commit; constitution `1d922dd7`) and the reference pin `d93edd1`

## Phase 3: User Story 1 — Evidence-backed integration matrix (P1) 🎯

- [ ] T-A10-002 [US1] Write `docs/apps/neon-arcade/visualcore-contract.json` (schema 1; app `neon-arcade`; gate `A10-P00`): `inventory` of every FR-A10-001 area with paths, the release-check step count from `python3 scripts/release_check.py --list`; `matrix` rows covering the 6 brainstorm capabilities and 6 version 0.1 features plus cross-cutting rows (persistence, quality tiers and low power, accessibility and Reduce Motion, lifecycle, licenses) with status ∈ {available, requires adaptation, upstream gap} per clarification 2 and file/symbol/product evidence; `traceability`; `negative` rules of FR-A10-006 (FR-A10-001, 002)
- [ ] T-A10-003 [US1] Run the contract checker and render the view (`python3 Tools/python/desktop_runbook.py run-check --stage A10-P00 --timeout 600 --name contract -- python3 scripts/check_app_contract.py --app neon-arcade --render`); `docs/apps/neon-arcade/visualcore-contract.md` is generated (FR-A10-007, SC-A10-001)

## Phase 4: User Story 2 — The reference stays proven (P1)

- [ ] T-A10-004 [US2] Reference chunk 1 (`python3 Tools/python/desktop_runbook.py run-check --stage A10-P00 --timeout 600 --name reference-1 -- python3 scripts/release_check.py --only reference-engine-xcframework reference-build-projectm-ios-sim reference-clean`)
- [ ] T-A10-005 [US2] Reference chunk 2 (`python3 Tools/python/desktop_runbook.py run-check --stage A10-P00 --timeout 600 --name reference-2 -- python3 scripts/release_check.py --only reference-test-anglerendering-ios27 reference-test-anglerendering-ios26 projectm-reference-ios27 projectm-reference-ios26`); record the 7 steps, commands and results in `docs/apps/neon-arcade/regression-baseline.md` (FR-A10-004, SC-A10-003)

## Phase 5: User Story 3 — The shell builds with the experience absent (P2)

- [ ] T-A10-006 [US3] Build the one app for testing (`python3 Tools/python/desktop_runbook.py run-check --stage A10-P00 --timeout 600 --name app-build -- python3 scripts/release_check.py --only app-build-for-testing-ios27`)
- [ ] T-A10-007 [US3] Experience package check (`python3 Tools/python/desktop_runbook.py run-check --stage A10-P00 --timeout 600 --name experience-packages -- python3 scripts/check_experience_packages.py`: 9 experiences, none A10); `grep -c a10 Catalog/registrations.json Apps/VisualCore/App/ExperienceRegistry.swift` gives 0 (FR-A10-005, SC-A10-004)

## Phase 6: User Story 4 — Stop/go decision (P2)

- [ ] T-A10-008 [US4] Complete the contract's `gaps` (every non-available row: owning module, VisualCore or app-local, and phase A10-P01..P06) and `decision` (verdict and reasons; "stop" if no working host or buildable drawing path; the fixed-step game loop, authoritative collision (overlap and swept tests), start/pause/restart/game-over flows with local scores, touch steering with configurable sensitivity, glow and particle feedback constrained by readability, and sound and haptic toggles with reduced-flash controls assessed per FR-A10-003 with the owners of clarification 5); re-run the checker (`python3 Tools/python/desktop_runbook.py run-check --stage A10-P00 --timeout 600 --name contract-final -- python3 scripts/check_app_contract.py --app neon-arcade --render`) (FR-A10-003, 006; SC-A10-002)

## Phase 7: Polish and evidence

- [ ] T-A10-009 No-change proof (`python3 Tools/python/desktop_runbook.py run-check --stage A10-P00 --timeout 600 --name no-change -- git diff --exit-code --stat 8e4fcdbe..HEAD -- Packages External`) (FR-A10-008, SC-A10-005)
- [ ] T-A10-010 Script tests (`python3 Tools/python/desktop_runbook.py run-check --stage A10-P00 --timeout 600 --name script-tests -- python3 scripts/test_scripts.py`) and the release-check document steps (`python3 Tools/python/desktop_runbook.py run-check --stage A10-P00 --timeout 600 --name fast-checks -- python3 scripts/release_check.py --only docs app-contracts compliance dependencies`); every run-check of this gate stays within its 600 s limit and the contract check under 10 s (SC-A10-006)
- [ ] T-A10-011 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record A10-P00

## Dependencies

T-A10-001 → T-A10-002 → T-A10-003 → T-A10-008; T-A10-004/005, 006/007 are independent of the contract; Polish last.

## Parallel examples

Agent: T-A10-002 (contract draft). Lead: T-A10-001, the runs and T-A10-008 review.

## Implementation strategy

MVP is US1 (the matrix) with US2 (reference); US3 and US4 complete the gate.
