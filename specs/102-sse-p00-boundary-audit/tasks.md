# Tasks: Solar System Explorer — Phase 00 Foundation and VisualCore boundary audit

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/contract.md](contracts/contract.md), [quickstart.md](quickstart.md). Gate A14-P00 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A14-P00 --timeout 600 --name <check> -- <command>`. Commit
after every task (no trailers); read every check's exit before ticking. No Swift, package or project change.

## Phase 1: Setup

- [ ] T-A14-001 Create `docs/apps/solar-system-explorer/README.md` (what the experience is per the manual §1–§2: an educational solar system viewer that keeps astronomical scale, simulated time and visibility-enhanced displays apart; that it is an experience of the one app; its documents) and `docs/apps/solar-system-explorer/regression-baseline.md` with the phase start `9335c07c` (the specify commit; constitution `462c0a1f`) and the reference pin `d93edd1`

## Phase 3: User Story 1 — Evidence-backed integration matrix (P1) 🎯

- [ ] T-A14-002 [US1] Write `docs/apps/solar-system-explorer/visualcore-contract.json` (schema 1; app `solar-system-explorer`; gate `A14-P00`): `inventory` of every FR-A14-001 area with paths, the release-check step count from `python3 scripts/release_check.py --list`; `matrix` rows covering the 5 brainstorm capabilities and 6 version 0.1 features plus cross-cutting rows (double precision and camera-relative positions, determinism and replay, bounded content and date range, persistence, quality tiers and low power, accessibility with Reduce Motion, lifecycle and context loss, data provenance and licenses, truthful scale labelling, labelled simulated date, time zone and model scope) with status ∈ {available, requires adaptation, upstream gap} per clarification 2 and file/symbol/product evidence; `traceability`; `negative` rules of FR-A14-006 (FR-A14-001, 002)
- [ ] T-A14-003 [US1] Run the contract checker and render the view (`--name contract -- python3 scripts/check_app_contract.py --app solar-system-explorer --render`); `docs/apps/solar-system-explorer/visualcore-contract.md` is generated (FR-A14-007, SC-A14-001)

## Phase 4: User Story 2 — The reference stays proven (P1)

- [ ] T-A14-004 [US2] Reference chunk 1 (`--name reference-1 -- python3 scripts/release_check.py --only reference-engine-xcframework reference-build-projectm-ios-sim reference-clean`)
- [ ] T-A14-005 [US2] Reference chunk 2 (`--name reference-2 -- python3 scripts/release_check.py --only reference-test-anglerendering-ios27 reference-test-anglerendering-ios26 projectm-reference-ios27 projectm-reference-ios26`); record the 7 steps, commands and results in `docs/apps/solar-system-explorer/regression-baseline.md` (FR-A14-004, SC-A14-003)

## Phase 5: User Story 3 — The shell builds with the experience absent (P2)

- [ ] T-A14-006 [US3] Build the one app for testing (`--name app-build -- python3 scripts/release_check.py --only app-build-for-testing-ios27`)
- [ ] T-A14-007 [US3] Experience package check (`--name experience-packages -- python3 scripts/check_experience_packages.py`: 13 experiences, none A14); `grep -c a14 Catalog/registrations.json Apps/VisualCore/App/ExperienceRegistry.swift` gives 0 (FR-A14-005, SC-A14-004)

## Phase 6: User Story 4 — Stop/go decision (P2)

- [ ] T-A14-008 [US4] Complete the contract's `gaps` (every non-available row: owning module, VisualCore or app-local, and phase A14-P01..P06) and `decision` (verdict and reasons; "stop" if no working host or buildable 3D drawing path; the body catalog with sourced data, Kepler propagation, simulated clock and date range, scale modes and unit conversion, camera-relative positions, procedural bodies and starfield, orbit lines and labels, focus without near-clip surprises, fact cards, tours and saved view state assessed per FR-A14-003 with the owners of clarification 5); re-run the checker (`--name contract-final -- python3 scripts/check_app_contract.py --app solar-system-explorer --render`) (FR-A14-003, 006; SC-A14-002)

## Phase 7: Polish and evidence

- [ ] T-A14-009 No-change proof (`--name no-change -- git diff --exit-code --stat 9335c07c..HEAD -- Packages External`) (FR-A14-008, SC-A14-005)
- [ ] T-A14-010 Script tests (`--name script-tests -- python3 scripts/test_scripts.py`) and the release-check document steps (`--name fast-checks -- python3 scripts/release_check.py --only docs app-contracts compliance dependencies`); every run-check of this gate stays within its 600 s limit and the contract check under 10 s (SC-A14-006)
- [ ] T-A14-011 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record A14-P00; update README.md (status, gate count) in the record commit (rule 16)

## Dependencies

T-A14-001 → T-A14-002 → T-A14-003 → T-A14-008; T-A14-004/005 and 006/007 are independent of the contract (reference
and app build run serially: one xcodebuild at a time); Polish last.

## Parallel examples

Agent: T-A14-002 (contract draft, read-heavy). Lead: T-A14-001, the runs, T-A14-008 review, ticks and commits.

## Implementation strategy

MVP is US1 (the matrix) with US2 (reference); US3 and US4 complete the gate.
