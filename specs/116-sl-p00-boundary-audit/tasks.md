# Tasks: Simulation Lab — Phase 00 Foundation and VisualCore boundary audit

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/contract.md](contracts/contract.md), [quickstart.md](quickstart.md). Gate A16-P00 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A16-P00 --timeout 600 --name <check> -- <command>`. Commit
after every task (no trailers); read every check's exit before ticking. No Swift, package or project change.
Precedent: `specs/109-me-p00-boundary-audit/tasks.md`.

## Phase 1: Setup

- [X] T-A16-001 Create `docs/apps/simulation-lab/README.md` (what the experience is per the manual §1–§2: a gallery of inspectable simulations with parameter panels and explicit numerical and educational limitations; that it is an experience of the one app; its documents) and `docs/apps/simulation-lab/regression-baseline.md` with the phase start `1006181f` (the specify commit; constitution `f2d45f77`) and the reference pin `d93edd1` — Verified 2026-11-16: 2026-11-16: docs/apps/simulation-lab/README.md and regression-baseline.md (phase start 1006181f, constitution f2d45f77, pin d93edd1) written

## Phase 3: User Story 1 — Evidence-backed integration matrix (P1) 🎯

- [X] T-A16-002 [US1] Write `docs/apps/simulation-lab/visualcore-contract.json` (schema 1; app `simulation-lab`; gate `A16-P00`): `inventory` of every FR-A16-001 area with paths and the release-check step count from `python3 scripts/release_check.py --list`; `matrix` rows covering the 5 brainstorm capabilities (GPU simulation with framebuffer feedback, numerical visualization, parameter controls, data visualization, animation and capture) and the 6 version 0.1 features plus cross-cutting rows (CPU references with storage precision, boundary rules, resource separation, float targets with probe and fallback, validity safeguards and stability limits, determinism, persistence with migration, quality tiers and low power, accessibility with Reduce Motion and Reduce Flashing and colour-independent legends, lifecycle, resize and context loss, licenses, truthful educational labels) with status ∈ {available, requires adaptation, upstream gap} per clarification 2 and evidence files, symbols and products verified in code; `traceability`; `negative` per FR-A16-006 (FR-A16-001, 002, 006) — Verified 2026-11-16: 2026-11-16: docs/apps/simulation-lab/visualcore-contract.json written (26 rows: 11 available, 15 requires adaptation; 11 inventory areas; 133 release-check steps; 17 traceability entries; 14 negative rules incl. the three risks)
- [X] T-A16-003 [US1] Run the contract checker and render the view (`--name contract -- python3 scripts/check_app_contract.py --app simulation-lab --render`); `docs/apps/simulation-lab/visualcore-contract.md` is generated (FR-A16-007, SC-A16-001) — Verified 2026-11-16: 2026-11-16: .autonomy/checks/A16-P00.contract-2.json exit 0 (PASS: 26 rows, 174 citations, 11 gaps, decision go); visualcore-contract.md rendered (the first run, contract.json exit 1, failed because the view did not yet exist with its generated-block markers)

## Phase 4: User Story 2 — The reference stays proven (P1)

- [X] T-A16-004 [US2] Reference chunk 1 (`--name reference-1 -- python3 scripts/release_check.py --only reference-engine-xcframework reference-build-projectm-ios-sim reference-clean`) — Verified 2026-11-16: 2026-11-16: .autonomy/checks/A16-P00.reference-1.json exit 0 (3/3 steps)
- [X] T-A16-005 [US2] Reference chunk 2 (`--name reference-2 -- python3 scripts/release_check.py --only reference-test-anglerendering-ios27 reference-test-anglerendering-ios26 projectm-reference-ios27 projectm-reference-ios26`); record the 7 steps, commands and results in `docs/apps/simulation-lab/regression-baseline.md` (FR-A16-004, SC-A16-003) — Verified 2026-11-16: 2026-11-16: .autonomy/checks/A16-P00.reference-2.json exit 0 (4/4 steps); 7 of 7 recorded in regression-baseline.md

## Phase 5: User Story 3 — The shell builds with the experience absent (P2)

- [X] T-A16-006 [US3] Build the one app for testing (`--name app-build -- python3 scripts/release_check.py --only app-build-for-testing-ios27`) — Verified 2026-11-16: 2026-11-16: .autonomy/checks/A16-P00.app-build.json exit 0 (app-build-for-testing-ios27)
- [X] T-A16-007 [US3] Experience package check (`--name experience-packages -- python3 scripts/check_experience_packages.py`: 15 experiences, none A16); `grep -c a16 Catalog/registrations.json Apps/VisualCore/App/ExperienceRegistry.swift` gives 0 (FR-A16-005, SC-A16-004) — Verified 2026-11-16: 2026-11-16: .autonomy/checks/A16-P00.experience-packages.json exit 0 (15 experiences, none A16); grep -c a16 Catalog/registrations.json Apps/VisualCore/App/ExperienceRegistry.swift gives 0 and 0

## Phase 6: User Story 4 — Stop/go decision (P2)

- [X] T-A16-008 [US4] Complete the contract's `gaps` (every non-available row: owning module, VisualCore or app-local, and phase A16-P01..P06 per research D4), the three manual risks as `negative` entries naming owner, verification method and release-blocker condition (source "manual §13 risk N"; the checker has no risk key), and `decision` (keys `result`, `reasons`, `blockers`) (verdict and reasons; "stop" if no working host or buildable offscreen feedback path); re-run the checker (`--name contract-final -- python3 scripts/check_app_contract.py --app simulation-lab --render`) (FR-A16-003, 006; SC-A16-002) — Verified 2026-11-16: 2026-11-16: .autonomy/checks/A16-P00.contract-final.json exit 0; 11 gaps (app-local, A16-P01 to A16-P06), the three manual risks as negative entries with owner, verification and release blocker, decision go with no blocker

## Phase 7: Polish and evidence

- [X] T-A16-009 No-change proof (`--name no-change -- git diff --exit-code --stat 1006181f..HEAD -- Packages External`) (FR-A16-008, SC-A16-005) — Verified 2026-11-16: 2026-11-16: .autonomy/checks/A16-P00.no-change.json exit 0 (no change in Packages or External since 1006181f)
- [X] T-A16-010 Script tests (`--name script-tests -- python3 scripts/test_scripts.py`) and the release-check document steps (`--name fast-checks -- python3 scripts/release_check.py --only docs app-contracts compliance dependencies`); every run-check of this gate stays within its 600 s limit and the contract check under 10 s (SC-A16-006) — Verified 2026-11-16: 2026-11-16: .autonomy/checks/A16-P00.script-tests.json and A16-P00.fast-checks.json exit 0; every run-check within 600 s; contract check 0.05 s
- [ ] T-A16-011 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record A16-P00; update README.md (status, gate count) in the record commit (rule 16) and `docs/automatedtesting.md` if a test tool, rule or lesson changed (rule 17)

## Dependencies

T-A16-001 → T-A16-002 → T-A16-003 → T-A16-008; T-A16-004/005 and 006/007 are independent of the contract (reference
and app build run serially: one xcodebuild at a time); Polish last.

## Parallel examples

Agent: T-A16-002 (the read-heavy contract audit). Lead: T-A16-001, the reference and build runs (004–007), the gap
completion review (008), the proofs and commits.

## Implementation strategy

MVP: the contract (002, 003, 008) with the baseline (001, 004, 005); the build proof (006, 007) and evidence close the
phase. Review checkpoint after 003 (checker passes) and at 008 (decision).
