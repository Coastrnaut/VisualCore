# Tasks: Infinite Geometry — Phase 00 Foundation and VisualCore boundary audit

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/contract.md](contracts/contract.md), [quickstart.md](quickstart.md). Gate A05-P00 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A05-P00 --timeout 600 --name <check> -- <command>`. Commit after every task (no trailers). No Swift, package or project change.

## Phase 1: Setup

- [X] T-A05-001 Create `docs/apps/infinite-geometry/README.md` (what the experience is per the manual §1–§2, that it is an experience of the one app, its documents) and `docs/apps/infinite-geometry/regression-baseline.md` with the phase start `427eea32` and the reference pin `d93edd1` — Verified 2026-11-13: 2026-11-13 docs/apps/infinite-geometry/README.md and regression-baseline.md (phase start 427eea32, pin d93edd1); validate_docs PASS

## Phase 3: User Story 1 — Evidence-backed integration matrix (P1) 🎯

- [X] T-A05-002 [US1] Write `docs/apps/infinite-geometry/visualcore-contract.json` (schema 1; app `infinite-geometry`; gate `A05-P00`): `inventory` of every FR-A05-001 area with paths, the release-check step count from `python3 scripts/release_check.py --list`; `matrix` rows covering the 5 brainstorm capabilities and 6 version 0.1 features with status ∈ {available, requires adaptation, upstream gap} per clarification 4 and file/symbol/product evidence; `traceability`; `negative` rules of FR-A05-006 — Verified 2026-11-13: 2026-11-13 .autonomy/checks/A05-P00.contract.json (PASS: 22 rows, 109 citations, 6 gaps, decision go); 8 inventory areas, release_check --list 78 steps; 16 available, 5 requires adaptation, 1 upstream gap; OrbitCamera and vc/sdf.glsl gap claims re-checked by grep
- [X] T-A05-003 [US1] Run the contract checker and render the view (`python3 Tools/python/desktop_runbook.py run-check --stage A05-P00 --timeout 600 --name contract -- python3 scripts/check_app_contract.py --app infinite-geometry --render`); `docs/apps/infinite-geometry/visualcore-contract.md` is generated (FR-A05-007, SC-A05-001) — Verified 2026-11-13: 2026-11-13 .autonomy/checks/A05-P00.contract.json (PASS: 22 rows, 109 citations, 6 gaps, decision go); visualcore-contract.md rendered

## Phase 4: User Story 2 — The reference stays proven (P1)

- [X] T-A05-004 [US2] Reference chunk 1 (`python3 Tools/python/desktop_runbook.py run-check --stage A05-P00 --timeout 600 --name reference-1 -- python3 scripts/release_check.py --only reference-engine-xcframework reference-build-projectm-ios-sim reference-clean`) — Verified 2026-11-13: 2026-11-13 .autonomy/checks/A05-P00.reference-1.json (3/3)
- [X] T-A05-005 [US2] Reference chunk 2 (`python3 Tools/python/desktop_runbook.py run-check --stage A05-P00 --timeout 600 --name reference-2 -- python3 scripts/release_check.py --only reference-test-anglerendering-ios27 reference-test-anglerendering-ios26 projectm-reference-ios27 projectm-reference-ios26`); record the 7 steps, commands and results in `docs/apps/infinite-geometry/regression-baseline.md` (FR-A05-004, SC-A05-003) — Verified 2026-11-13: 2026-11-13 .autonomy/checks/A05-P00.reference-2.json (4/4); regression-baseline.md lists the 7 steps

## Phase 5: User Story 3 — The shell builds with the experience absent (P2)

- [X] T-A05-006 [US3] Build the one app for testing (`python3 Tools/python/desktop_runbook.py run-check --stage A05-P00 --timeout 600 --name app-build -- python3 scripts/release_check.py --only app-build-for-testing-ios27`) — Verified 2026-11-13: 2026-11-13 .autonomy/checks/A05-P00.app-build.json (app-build-for-testing-ios27 pass)
- [X] T-A05-007 [US3] Experience package check (`python3 Tools/python/desktop_runbook.py run-check --stage A05-P00 --timeout 600 --name experience-packages -- python3 scripts/check_experience_packages.py`: 4 experiences, none A05); `grep -c a05 Catalog/registrations.json Apps/VisualCore/App/ExperienceRegistry.swift` gives 0 (FR-A05-005, SC-A05-004) — Verified 2026-11-13: 2026-11-13 .autonomy/checks/A05-P00.experience-packages.json (PASS: 4 experiences in 1 packages); grep a05 in registrations.json and ExperienceRegistry.swift: 0

## Phase 6: User Story 4 — Stop/go decision (P2)

- [ ] T-A05-008 [US4] Complete the contract's `gaps` (every non-available row: owning VisualCore module and phase A05-P01..P06) and `decision` (verdict and reasons; "stop" if no working host or mesh path); re-run the checker (`python3 Tools/python/desktop_runbook.py run-check --stage A05-P00 --timeout 600 --name contract-final -- python3 scripts/check_app_contract.py --app infinite-geometry --render`) (FR-A05-003, 006; SC-A05-002)

## Phase 7: Polish and evidence

- [ ] T-A05-009 No-change proof (`python3 Tools/python/desktop_runbook.py run-check --stage A05-P00 --timeout 600 --name no-change -- git diff --exit-code --stat 427eea32..HEAD -- Packages External`) (FR-A05-008, SC-A05-005)
- [ ] T-A05-010 Script tests (`python3 Tools/python/desktop_runbook.py run-check --stage A05-P00 --timeout 600 --name script-tests -- python3 scripts/test_scripts.py`) and the release-check document steps (`python3 Tools/python/desktop_runbook.py run-check --stage A05-P00 --timeout 600 --name fast-checks -- python3 scripts/release_check.py --only docs app-contracts compliance dependencies`)
- [ ] T-A05-011 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record A05-P00

## Dependencies

T-A05-001 → T-A05-002 → T-A05-003 → T-A05-008; T-A05-004/005, 006/007 are independent of the contract; Polish last.

## Parallel examples

Agent: T-A05-002 (contract draft, already in progress). Lead: T-A05-001, the runs and T-A05-008 review.

## Implementation strategy

MVP is US1 (the matrix) with US2 (reference); US3 and US4 complete the gate.
