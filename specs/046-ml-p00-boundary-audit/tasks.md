# Tasks: VisualCore Music Lab — Phase 00 Foundation and VisualCore boundary audit

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/contract.md](contracts/contract.md), [quickstart.md](quickstart.md). Gate A06-P00 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A06-P00 --timeout 600 --name <check> -- <command>`. Commit after every task (no trailers). No Swift, package or project change.

## Phase 1: Setup

- [ ] T-A06-001 Create `docs/apps/visualcore-music-lab/README.md` (what the experience is per the manual §1–§2, that it is an experience of the one app, its documents) and `docs/apps/visualcore-music-lab/regression-baseline.md` with the phase start `4c27bfaf` (specify commit; constitution commit `c37f95fe`) and the reference pin `d93edd1`

## Phase 3: User Story 1 — Evidence-backed integration matrix (P1) 🎯

- [ ] T-A06-002 [US1] Write `docs/apps/visualcore-music-lab/visualcore-contract.json` (schema 1; app `visualcore-music-lab`; gate `A06-P00`): `inventory` of every FR-A06-001 area with paths, the release-check step count from `python3 scripts/release_check.py --list`; `matrix` rows covering the 5 brainstorm capabilities and 6 version 0.1 features with status ∈ {available, requires adaptation, upstream gap} per clarification 4 and file/symbol/product evidence; `traceability`; `negative` rules of FR-A06-006
- [ ] T-A06-003 [US1] Run the contract checker and render the view (`python3 Tools/python/desktop_runbook.py run-check --stage A06-P00 --timeout 600 --name contract -- python3 scripts/check_app_contract.py --app visualcore-music-lab --render`); `docs/apps/visualcore-music-lab/visualcore-contract.md` is generated (FR-A06-007, SC-A06-001)

## Phase 4: User Story 2 — The reference stays proven (P1)

- [ ] T-A06-004 [US2] Reference chunk 1 (`python3 Tools/python/desktop_runbook.py run-check --stage A06-P00 --timeout 600 --name reference-1 -- python3 scripts/release_check.py --only reference-engine-xcframework reference-build-projectm-ios-sim reference-clean`)
- [ ] T-A06-005 [US2] Reference chunk 2 (`python3 Tools/python/desktop_runbook.py run-check --stage A06-P00 --timeout 600 --name reference-2 -- python3 scripts/release_check.py --only reference-test-anglerendering-ios27 reference-test-anglerendering-ios26 projectm-reference-ios27 projectm-reference-ios26`); record the 7 steps, commands and results in `docs/apps/visualcore-music-lab/regression-baseline.md` (FR-A06-004, SC-A06-003)

## Phase 5: User Story 3 — The shell builds with the experience absent (P2)

- [ ] T-A06-006 [US3] Build the one app for testing (`python3 Tools/python/desktop_runbook.py run-check --stage A06-P00 --timeout 600 --name app-build -- python3 scripts/release_check.py --only app-build-for-testing-ios27`)
- [ ] T-A06-007 [US3] Experience package check (`python3 Tools/python/desktop_runbook.py run-check --stage A06-P00 --timeout 600 --name experience-packages -- python3 scripts/check_experience_packages.py`: 4 experiences, none A05); `grep -c a05 Catalog/registrations.json Apps/VisualCore/App/ExperienceRegistry.swift` gives 0 (FR-A06-005, SC-A06-004)

## Phase 6: User Story 4 — Stop/go decision (P2)

- [ ] T-A06-008 [US4] Complete the contract's `gaps` (every non-available row: owning VisualCore module and phase A06-P01..P06) and `decision` (verdict and reasons; "stop" if no working host or buildable audio path); re-run the checker (`python3 Tools/python/desktop_runbook.py run-check --stage A06-P00 --timeout 600 --name contract-final -- python3 scripts/check_app_contract.py --app visualcore-music-lab --render`) (FR-A06-003, 006; SC-A06-002)

## Phase 7: Polish and evidence

- [ ] T-A06-009 No-change proof (`python3 Tools/python/desktop_runbook.py run-check --stage A06-P00 --timeout 600 --name no-change -- git diff --exit-code --stat 4c27bfaf..HEAD -- Packages External`) (FR-A06-008, SC-A06-005)
- [ ] T-A06-010 Script tests (`python3 Tools/python/desktop_runbook.py run-check --stage A06-P00 --timeout 600 --name script-tests -- python3 scripts/test_scripts.py`) and the release-check document steps (`python3 Tools/python/desktop_runbook.py run-check --stage A06-P00 --timeout 600 --name fast-checks -- python3 scripts/release_check.py --only docs app-contracts compliance dependencies`)
- [ ] T-A06-011 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record A06-P00

## Dependencies

T-A06-001 → T-A06-002 → T-A06-003 → T-A06-008; T-A06-004/005, 006/007 are independent of the contract; Polish last.

## Parallel examples

Agent: T-A06-002 (contract draft, already in progress). Lead: T-A06-001, the runs and T-A06-008 review.

## Implementation strategy

MVP is US1 (the matrix) with US2 (reference); US3 and US4 complete the gate.
