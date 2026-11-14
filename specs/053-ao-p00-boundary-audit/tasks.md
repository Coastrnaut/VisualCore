# Tasks: Audio Odyssey — Phase 00 Foundation and VisualCore boundary audit

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/contract.md](contracts/contract.md), [quickstart.md](quickstart.md). Gate A07-P00 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A07-P00 --timeout 600 --name <check> -- <command>`. Commit after every task (no trailers). No Swift, package or project change.

## Phase 1: Setup

- [X] T-A07-001 Create `docs/apps/audio-odyssey/README.md` (what the experience is per the manual §1–§2, that it is an experience of the one app, its documents) and `docs/apps/audio-odyssey/regression-baseline.md` with the phase start `b5c919b4` (the specify commit; constitution `fcf6ad46`) and the reference pin `d93edd1` — Verified 2026-11-14: Verified 2026-11-14: docs/apps/audio-odyssey/README.md and regression-baseline.md (phase start b5c919b4, constitution fcf6ad46, pin d93edd1)

## Phase 3: User Story 1 — Evidence-backed integration matrix (P1) 🎯

- [X] T-A07-002 [US1] Write `docs/apps/audio-odyssey/visualcore-contract.json` (schema 1; app `audio-odyssey`; gate `A07-P00`): `inventory` of every FR-A07-001 area with paths, the release-check step count from `python3 scripts/release_check.py --list`; `matrix` rows covering the 5 brainstorm capabilities and 6 version 0.1 features with status ∈ {available, requires adaptation, upstream gap} per clarification 2 and file/symbol/product evidence; `traceability`; `negative` rules of FR-A07-006; audio rows cite `VisualCoreAudio` and `VisualCoreAudioDSP` (reused from A06), camera rows `OrbitCamera`/`Camera2D` and `DepthMeshPass` — Verified 2026-11-14: Verified 2026-11-14: docs/apps/audio-odyssey/visualcore-contract.json (schema 1; 7 inventory areas, 88 release steps, 22 matrix rows: 13 available, 9 not; audio rows cite VisualCoreAudio/VisualCoreAudioDSP; 10 negative rules); lead retested with the checker
- [X] T-A07-003 [US1] Run the contract checker and render the view (`python3 Tools/python/desktop_runbook.py run-check --stage A07-P00 --timeout 600 --name contract -- python3 scripts/check_app_contract.py --app audio-odyssey --render`); `docs/apps/audio-odyssey/visualcore-contract.md` is generated (FR-A07-007, SC-A07-001) — Verified 2026-11-14: Verified 2026-11-14: .autonomy/checks/A07-P00.contract-2.json exit 0 (PASS: 22 rows, 104 citations, 6 gaps, decision go; visualcore-contract.md generated; first attempt contract.json failed only on the missing marker block of the new view)

## Phase 4: User Story 2 — The reference stays proven (P1)

- [X] T-A07-004 [US2] Reference chunk 1 (`python3 Tools/python/desktop_runbook.py run-check --stage A07-P00 --timeout 600 --name reference-1 -- python3 scripts/release_check.py --only reference-engine-xcframework reference-build-projectm-ios-sim reference-clean`) — Verified 2026-11-14: Verified 2026-11-14: .autonomy/checks/A07-P00.reference-1.json exit 0 (steps 1-3)
- [X] T-A07-005 [US2] Reference chunk 2 (`python3 Tools/python/desktop_runbook.py run-check --stage A07-P00 --timeout 600 --name reference-2 -- python3 scripts/release_check.py --only reference-test-anglerendering-ios27 reference-test-anglerendering-ios26 projectm-reference-ios27 projectm-reference-ios26`); record the 7 steps, commands and results in `docs/apps/audio-odyssey/regression-baseline.md` (FR-A07-004, SC-A07-003) — Verified 2026-11-14: Verified 2026-11-14: .autonomy/checks/A07-P00.reference-2.json exit 0 (steps 4-7); 7 of 7 recorded in regression-baseline.md

## Phase 5: User Story 3 — The shell builds with the experience absent (P2)

- [X] T-A07-006 [US3] Build the one app for testing (`python3 Tools/python/desktop_runbook.py run-check --stage A07-P00 --timeout 600 --name app-build -- python3 scripts/release_check.py --only app-build-for-testing-ios27`) — Verified 2026-11-14: Verified 2026-11-14: .autonomy/checks/A07-P00.app-build.json exit 0 (build-for-testing, iOS 27.2 phone)
- [X] T-A07-007 [US3] Experience package check (`python3 Tools/python/desktop_runbook.py run-check --stage A07-P00 --timeout 600 --name experience-packages -- python3 scripts/check_experience_packages.py`: 6 experiences, none A07); `grep -c a07 Catalog/registrations.json Apps/VisualCore/App/ExperienceRegistry.swift` gives 0 (FR-A07-005, SC-A07-004) — Verified 2026-11-14: Verified 2026-11-14: .autonomy/checks/A07-P00.experience-packages.json exit 0; grep -c a07 Catalog/registrations.json Apps/VisualCore/App/ExperienceRegistry.swift gives 0 and 0

## Phase 6: User Story 4 — Stop/go decision (P2)

- [X] T-A07-008 [US4] Complete the contract's `gaps` (every non-available row: owning VisualCore module and phase A07-P01..P06) and `decision` (verdict and reasons; "stop" if no working host or buildable audio path; the camera rail, streaming segments and origin rebasing assessed per FR-A07-003); re-run the checker (`python3 Tools/python/desktop_runbook.py run-check --stage A07-P00 --timeout 600 --name contract-final -- python3 scripts/check_app_contract.py --app audio-odyssey --render`) (FR-A07-003, 006; SC-A07-002) — Verified 2026-11-14: Verified 2026-11-14: .autonomy/checks/A07-P00.contract-final.json exit 0; 6 gaps each with module and phase (G-CAMERARAIL, G-ORIGINREBASE VisualCoreMath P01; G-RAILDRAW VisualCoreRendering, G-SEGMENTSTREAM VisualCoreScenes P02; G-JOURNEYBUDGET VisualCoreScenes, G-JOURNEYA11Y app-local P05); decision go, no blockers

## Phase 7: Polish and evidence

- [ ] T-A07-009 No-change proof (`python3 Tools/python/desktop_runbook.py run-check --stage A07-P00 --timeout 600 --name no-change -- git diff --exit-code --stat b5c919b4..HEAD -- Packages External`) (FR-A07-008, SC-A07-005)
- [ ] T-A07-010 Script tests (`python3 Tools/python/desktop_runbook.py run-check --stage A07-P00 --timeout 600 --name script-tests -- python3 scripts/test_scripts.py`) and the release-check document steps (`python3 Tools/python/desktop_runbook.py run-check --stage A07-P00 --timeout 600 --name fast-checks -- python3 scripts/release_check.py --only docs app-contracts compliance dependencies`)
- [ ] T-A07-011 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record A07-P00

## Dependencies

T-A07-001 → T-A07-002 → T-A07-003 → T-A07-008; T-A07-004/005, 006/007 are independent of the contract; Polish last.

## Parallel examples

Agent: T-A07-002 (contract draft). Lead: T-A07-001, the runs and T-A07-008 review.

## Implementation strategy

MVP is US1 (the matrix) with US2 (reference); US3 and US4 complete the gate.
