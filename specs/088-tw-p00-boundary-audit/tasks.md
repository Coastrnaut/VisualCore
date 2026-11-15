# Tasks: Tiny Worlds — Phase 00 Foundation and VisualCore boundary audit

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/contract.md](contracts/contract.md), [quickstart.md](quickstart.md). Gate A12-P00 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A12-P00 --timeout 600 --name <check> -- <command>`. Commit
after every task (no trailers); read every check's exit before ticking. No Swift, package or project change.

## Phase 1: Setup

- [X] T-A12-001 Create `docs/apps/tiny-worlds/README.md` (what the experience is per the manual §1–§2: a curated gallery of miniature procedural worlds with orbit navigation and gentle customization; that it is an experience of the one app; its documents) and `docs/apps/tiny-worlds/regression-baseline.md` with the phase start `9315c27e` (the specify commit; constitution `dbc35ba4`) and the reference pin `d93edd1` — Verified 2026-11-15: 2026-11-15: docs/apps/tiny-worlds/README.md and regression-baseline.md (phase start 9315c27e, constitution dbc35ba4, pin d93edd1; reference 7/7 recorded); committed with the contract they link to

## Phase 3: User Story 1 — Evidence-backed integration matrix (P1) 🎯

- [X] T-A12-002 [US1] Write `docs/apps/tiny-worlds/visualcore-contract.json` (schema 1; app `tiny-worlds`; gate `A12-P00`): `inventory` of every FR-A12-001 area with paths, the release-check step count from `python3 scripts/release_check.py --list`; `matrix` rows covering the 5 brainstorm capabilities and 6 version 0.1 features plus cross-cutting rows (depth, picking, seeded determinism, geometry budget and detail tier, persistence, quality tiers and low power, accessibility and Reduce Motion, lifecycle and context loss, licenses) with status ∈ {available, requires adaptation, upstream gap} per clarification 2 and file/symbol/product evidence; `traceability`; `negative` rules of FR-A12-006 (FR-A12-001, 002) — Verified 2026-11-15: 2026-11-15: visualcore-contract.json, 21 rows (11 available, 8 adaptation, 2 upstream), 10 gaps, 113 release steps, 11 registered experiences, decision go
- [X] T-A12-003 [US1] Run the contract checker and render the view (`--name contract -- python3 scripts/check_app_contract.py --app tiny-worlds --render`); `docs/apps/tiny-worlds/visualcore-contract.md` is generated (FR-A12-007, SC-A12-001) — Verified 2026-11-15: 2026-11-15: .autonomy/checks/A12-P00.contract.json exit 0 (PASS 21 rows, 129 citations, 10 gaps); visualcore-contract.md rendered

## Phase 4: User Story 2 — The reference stays proven (P1)

- [X] T-A12-004 [US2] Reference chunk 1 (`--name reference-1 -- python3 scripts/release_check.py --only reference-engine-xcframework reference-build-projectm-ios-sim reference-clean`) — Verified 2026-11-15: 2026-11-15: .autonomy/checks/A12-P00.reference-1.json exit 0 (3/3 steps)
- [X] T-A12-005 [US2] Reference chunk 2 (`--name reference-2 -- python3 scripts/release_check.py --only reference-test-anglerendering-ios27 reference-test-anglerendering-ios26 projectm-reference-ios27 projectm-reference-ios26`); record the 7 steps, commands and results in `docs/apps/tiny-worlds/regression-baseline.md` (FR-A12-004, SC-A12-003) — Verified 2026-11-15: 2026-11-15: .autonomy/checks/A12-P00.reference-2.json exit 0 (4/4 steps); regression-baseline.md records 7/7 pass

## Phase 5: User Story 3 — The shell builds with the experience absent (P2)

- [X] T-A12-006 [US3] Build the one app for testing (`--name app-build -- python3 scripts/release_check.py --only app-build-for-testing-ios27`) — Verified 2026-11-15: 2026-11-15: .autonomy/checks/A12-P00.app-build.json exit 0 (iOS 27.2 phone simulator)
- [X] T-A12-007 [US3] Experience package check (`--name experience-packages -- python3 scripts/check_experience_packages.py`: 11 experiences, none A12); `grep -c a12 Catalog/registrations.json Apps/VisualCore/App/ExperienceRegistry.swift` gives 0 (FR-A12-005, SC-A12-004) — Verified 2026-11-15: 2026-11-15: .autonomy/checks/A12-P00.experience-packages.json exit 0 (11 experiences, none A12); grep -c a12 in Catalog/registrations.json and ExperienceRegistry.swift gives 0

## Phase 6: User Story 4 — Stop/go decision (P2)

- [X] T-A12-008 [US4] Complete the contract's `gaps` (every non-available row: owning module, VisualCore or app-local, and phase A12-P01..P06) and `decision` (verdict and reasons; "stop" if no working host or buildable 3D drawing path; the three presets, orbit camera with constrained zoom, seeded terrain with stable boundaries, prop placement and light adjustment, saved worlds with thumbnails, the detail tier, depth and picking assessed per FR-A12-003 with the owners of clarification 5); re-run the checker (`--name contract-final -- python3 scripts/check_app_contract.py --app tiny-worlds --render`) (FR-A12-003, 006; SC-A12-002) — Verified 2026-11-15: 2026-11-15: .autonomy/checks/A12-P00.contract-final.json exit 0; 10 gaps with owners and phases (G-TERRAIN VisualCoreScenes P01, G-CONTENTLICENSES app-local P01; G-MATERIALS VisualCoreRendering P02, G-PICKING VisualCoreMath P02, G-CAMERA app-local P02; G-PROPS, G-LIGHT, G-WORLDDOC P03; G-PACKS P04; G-DETAIL P05); decision go; the audit corrects clarification 5: constrained orbit and zoom exist (OrbitBounds, OrbitViewBounds since A05-P03), only world-specific clearance remains

## Phase 7: Polish and evidence

- [X] T-A12-009 No-change proof (`--name no-change -- git diff --exit-code --stat 9315c27e..HEAD -- Packages External`) (FR-A12-008, SC-A12-005) — Verified 2026-11-15: 2026-11-15: .autonomy/checks/A12-P00.no-change.json exit 0 (empty diff 9315c27e..HEAD of Packages External)
- [X] T-A12-010 Script tests (`--name script-tests -- python3 scripts/test_scripts.py`) and the release-check document steps (`--name fast-checks -- python3 scripts/release_check.py --only docs app-contracts compliance dependencies`); every run-check of this gate stays within its 600 s limit and the contract check under 10 s (SC-A12-006) — Verified 2026-11-15: 2026-11-15: .autonomy/checks/A12-P00.{script-tests,fast-checks}.json exit 0; every run under 600 s (longest script tests 39 s), contract check 0.04 s
- [ ] T-A12-011 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record A12-P00; update README.md (status, gate count) in the record commit (rule 16)

## Dependencies

T-A12-001 → T-A12-002 → T-A12-003 → T-A12-008; T-A12-004/005 and 006/007 are independent of the contract (reference
and app build run serially: one xcodebuild at a time); Polish last.

## Parallel examples

Agent: T-A12-002 (contract draft, read-heavy). Lead: T-A12-001, the runs, T-A12-008 review, ticks and commits.

## Implementation strategy

MVP is US1 (the matrix) with US2 (reference); US3 and US4 complete the gate.

## Phase 8: Convergence

- [X] T-A12-012 Record in `specs/088-tw-p00-boundary-audit/research.md` the audit's correction of D4 (constrained orbit and zoom already exist as `OrbitBounds` and `OrbitViewBounds` in `VisualCoreMath` since A05-P03; the remaining world-specific clearance is app-local, G-CAMERA; per-vertex colour G-MATERIALS is assigned to `VisualCoreRendering`, G-PICKING to `VisualCoreMath`) per plan: research D4 (partial) — Verified 2026-11-15: 2026-11-15: research.md §2 'As found by the audit' records the D4 correction (OrbitBounds, OrbitViewBounds exist; G-CAMERA app-local) and the G-MATERIALS and G-PICKING owners; validate_docs passes in the tick
