# Tasks: Oscilloscope Studio — Phase 00 Foundation and VisualCore boundary audit

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/contract.md](contracts/contract.md), [quickstart.md](quickstart.md). Gate A08-P00 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A08-P00 --timeout 600 --name <check> -- <command>`. Commit after every task (no trailers). No Swift, package or project change.

## Phase 1: Setup

- [X] T-A08-001 Create `docs/apps/oscilloscope-studio/README.md` (what the experience is per the manual §1–§2, that it is an experience of the one app, its documents) and `docs/apps/oscilloscope-studio/regression-baseline.md` with the phase start `6fdb5ca9` (the specify commit; constitution `0cdd2ca0`) and the reference pin `d93edd1` — Verified 2026-11-14: 2026-11-14: docs/apps/oscilloscope-studio/README.md and regression-baseline.md (phase start 6fdb5ca9, constitution 0cdd2ca0, pin d93edd1); gap phases aligned with the manual's phase titles

## Phase 3: User Story 1 — Evidence-backed integration matrix (P1) 🎯

- [X] T-A08-002 [US1] Write `docs/apps/oscilloscope-studio/visualcore-contract.json` (schema 1; app `oscilloscope-studio`; gate `A08-P00`): `inventory` of every FR-A08-001 area with paths, the release-check step count from `python3 scripts/release_check.py --list`; `matrix` rows covering the 5 brainstorm capabilities and 6 version 0.1 features with status ∈ {available, requires adaptation, upstream gap} per clarification 2 and file/symbol/product evidence; `traceability`; `negative` rules of FR-A08-006; audio rows cite `VisualCoreAudio` and `VisualCoreAudioDSP` (shared since A06: `AudioSource`, `MicrophonePermission`, `SampleRingBuffer`, `SpectrumAnalyzer`, `DemoSignal`), line rows the scene graph's `.line` and `PrimitiveRenderer` (FR-A08-001, 002) — Verified 2026-11-14: 2026-11-14: visualcore-contract.json, 25 rows (14 available, 6 adaptation, 5 upstream), 10 gaps, 93 release steps, decision go
- [X] T-A08-003 [US1] Run the contract checker and render the view (`python3 Tools/python/desktop_runbook.py run-check --stage A08-P00 --timeout 600 --name contract -- python3 scripts/check_app_contract.py --app oscilloscope-studio --render`); `docs/apps/oscilloscope-studio/visualcore-contract.md` is generated (FR-A08-007, SC-A08-001) — Verified 2026-11-14: 2026-11-14: .autonomy/checks/A08-P00.contract.json exit 0 (PASS 25 rows, 98 citations, 10 gaps); visualcore-contract.md rendered

## Phase 4: User Story 2 — The reference stays proven (P1)

- [X] T-A08-004 [US2] Reference chunk 1 (`python3 Tools/python/desktop_runbook.py run-check --stage A08-P00 --timeout 600 --name reference-1 -- python3 scripts/release_check.py --only reference-engine-xcframework reference-build-projectm-ios-sim reference-clean`) — Verified 2026-11-14: 2026-11-14: .autonomy/checks/A08-P00.reference-1.json exit 0
- [X] T-A08-005 [US2] Reference chunk 2 (`python3 Tools/python/desktop_runbook.py run-check --stage A08-P00 --timeout 600 --name reference-2 -- python3 scripts/release_check.py --only reference-test-anglerendering-ios27 reference-test-anglerendering-ios26 projectm-reference-ios27 projectm-reference-ios26`); record the 7 steps, commands and results in `docs/apps/oscilloscope-studio/regression-baseline.md` (FR-A08-004, SC-A08-003) — Verified 2026-11-14: 2026-11-14: .autonomy/checks/A08-P00.reference-2.json exit 0; regression-baseline.md records 7/7 pass

## Phase 5: User Story 3 — The shell builds with the experience absent (P2)

- [ ] T-A08-006 [US3] Build the one app for testing (`python3 Tools/python/desktop_runbook.py run-check --stage A08-P00 --timeout 600 --name app-build -- python3 scripts/release_check.py --only app-build-for-testing-ios27`)
- [ ] T-A08-007 [US3] Experience package check (`python3 Tools/python/desktop_runbook.py run-check --stage A08-P00 --timeout 600 --name experience-packages -- python3 scripts/check_experience_packages.py`: 7 experiences, none A08); `grep -c a08 Catalog/registrations.json Apps/VisualCore/App/ExperienceRegistry.swift` gives 0 (FR-A08-005, SC-A08-004)

## Phase 6: User Story 4 — Stop/go decision (P2)

- [ ] T-A08-008 [US4] Complete the contract's `gaps` (every non-available row: owning VisualCore module and phase A08-P01..P06) and `decision` (verdict and reasons; "stop" if no working host or buildable audio path; trigger and timebase window, min/max decimation, square and sweep demo, two-channel capture, multi-point trace strips and spectrum annotation assessed per FR-A08-003 with the owners of clarification 5); re-run the checker (`python3 Tools/python/desktop_runbook.py run-check --stage A08-P00 --timeout 600 --name contract-final -- python3 scripts/check_app_contract.py --app oscilloscope-studio --render`) (FR-A08-003, 006; SC-A08-002)

## Phase 7: Polish and evidence

- [ ] T-A08-009 No-change proof (`python3 Tools/python/desktop_runbook.py run-check --stage A08-P00 --timeout 600 --name no-change -- git diff --exit-code --stat 6fdb5ca9..HEAD -- Packages External`) (FR-A08-008, SC-A08-005)
- [ ] T-A08-010 Script tests (`python3 Tools/python/desktop_runbook.py run-check --stage A08-P00 --timeout 600 --name script-tests -- python3 scripts/test_scripts.py`) and the release-check document steps (`python3 Tools/python/desktop_runbook.py run-check --stage A08-P00 --timeout 600 --name fast-checks -- python3 scripts/release_check.py --only docs app-contracts compliance dependencies`); every run-check of this gate stays within its 600 s limit and the contract check under 10 s (SC-A08-006)
- [ ] T-A08-011 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record A08-P00

## Dependencies

T-A08-001 → T-A08-002 → T-A08-003 → T-A08-008; T-A08-004/005, 006/007 are independent of the contract; Polish last.

## Parallel examples

Agent: T-A08-002 (contract draft). Lead: T-A08-001, the runs and T-A08-008 review.

## Implementation strategy

MVP is US1 (the matrix) with US2 (reference); US3 and US4 complete the gate.
