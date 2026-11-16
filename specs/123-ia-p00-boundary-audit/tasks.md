# Tasks: Interactive Anatomy — Phase 00 Foundation and VisualCore boundary audit

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/contract.md](contracts/contract.md), [quickstart.md](quickstart.md). Gate A17-P00 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A17-P00 --timeout 600 --name <check> -- <command>`. Commit
after every task (no trailers); read every check's exit before ticking. No Swift, package or project change.
Precedent: `specs/116-sl-p00-boundary-audit/tasks.md`.

## Phase 1: Setup

- [X] T-A17-001 Create `docs/apps/interactive-anatomy/README.md` (what the experience is per the manual §1–§2: a labelled, layer-controlled 3D reference of one anatomy region (the right knee joint, procedural schematic geometry) with plain-language cited descriptions, educational and not medical; that it is an experience of the one app; its documents) and `docs/apps/interactive-anatomy/regression-baseline.md` with the phase start `f437fd0b` (the specify commit; constitution `a834dda9`) and the reference pin `d93edd1` — Verified 2026-11-16: 2026-11-16: docs/apps/interactive-anatomy/README.md and regression-baseline.md written (phase start f437fd0b, constitution a834dda9, reference pin d93edd1); validate_docs.py PASS

## Phase 3: User Story 1 — Evidence-backed integration matrix (P1) 🎯

- [ ] T-A17-002 [US1] Write `docs/apps/interactive-anatomy/visualcore-contract.json` (schema 1; app `interactive-anatomy`; gate `A17-P00`): `inventory` of every FR-A17-001 area with paths and the release-check step count from `python3 scripts/release_check.py --list`; `matrix` rows covering the 5 brainstorm capabilities (3D model rendering, textures and materials, camera controls, lighting, labels and overlays) and the 6 version 0.1 features plus cross-cutting rows (procedural geometry, the structure graph as a GPU-free model, picking, layered visibility with isolate and ghost translucency, anchored labels with overlap and the list alternative, search, content provenance and the review record, the offline content pack with schema and migration, saved view, quality tiers and budgets, accessibility with Reduce Motion and colour-independent layers, lifecycle with resize and context loss, licenses, educational not medical labels) with status ∈ {available, requires adaptation, upstream gap} per clarification 2 and evidence files, symbols and products verified in code; `traceability`; `negative` per FR-A17-006 (FR-A17-001, 002, 006)
- [ ] T-A17-003 [US1] Run the contract checker and render the view (`--name contract -- python3 scripts/check_app_contract.py --app interactive-anatomy --render`); `docs/apps/interactive-anatomy/visualcore-contract.md` is generated (FR-A17-007, SC-A17-001)

## Phase 4: User Story 2 — The reference stays proven (P1)

- [X] T-A17-004 [US2] Reference chunk 1 (`--name reference-1 -- python3 scripts/release_check.py --only reference-engine-xcframework reference-build-projectm-ios-sim reference-clean`) — Verified 2026-11-16: 2026-11-16: .autonomy/checks/A17-P00.reference-1.json exit 0 (reference-engine-xcframework, reference-build-projectm-ios-sim, reference-clean pass)
- [X] T-A17-005 [US2] Reference chunk 2 (`--name reference-2 -- python3 scripts/release_check.py --only reference-test-anglerendering-ios27 reference-test-anglerendering-ios26 projectm-reference-ios27 projectm-reference-ios26`); record the 7 steps, commands and results in `docs/apps/interactive-anatomy/regression-baseline.md` (FR-A17-004, SC-A17-003) — Verified 2026-11-16: 2026-11-16: .autonomy/checks/A17-P00.reference-2.json exit 0 (the four ANGLE and ProjectM reference tests on iOS 27 and 26 pass); 7 of 7 steps recorded in docs/apps/interactive-anatomy/regression-baseline.md

## Phase 5: User Story 3 — The shell builds with the experience absent (P2)

- [ ] T-A17-006 [US3] Build the one app for testing (`--name app-build -- python3 scripts/release_check.py --only app-build-for-testing-ios27`)
- [ ] T-A17-007 [US3] Experience package check (`--name experience-packages -- python3 scripts/check_experience_packages.py`: 16 experiences, none A17); `grep -c a17 Catalog/registrations.json Apps/VisualCore/App/ExperienceRegistry.swift` gives 0 (FR-A17-005, SC-A17-004)

## Phase 6: User Story 4 — Stop/go decision (P2)

- [ ] T-A17-008 [US4] Complete the contract's `gaps` (every non-available row: owning module, VisualCore or app-local, and phase A17-P01..P06 per research D4), the three manual risks as `negative` entries naming owner, verification method and release-blocker condition (source "manual §13 risk N"; the checker has no risk key), and `decision` (keys `result`, `reasons`, `blockers`) (verdict and reasons; "stop" if no working host or buildable lit, depth-tested mesh path); re-run the checker (`--name contract-final -- python3 scripts/check_app_contract.py --app interactive-anatomy --render`) (FR-A17-003, 006; SC-A17-002)

## Phase 7: Polish and evidence

- [ ] T-A17-009 No-change proof (`--name no-change -- git diff --exit-code --stat f437fd0b..HEAD -- Packages External`) (FR-A17-008, SC-A17-005)
- [ ] T-A17-010 Script tests (`--name script-tests -- python3 scripts/test_scripts.py`) and the release-check document steps (`--name fast-checks -- python3 scripts/release_check.py --only docs app-contracts compliance dependencies`); every run-check of this gate stays within its 600 s limit and the contract check under 10 s (SC-A17-006)
- [ ] T-A17-011 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record A17-P00; update README.md (status, gate count) in the record commit (rule 16) and `docs/automatedtesting.md` if a test tool, rule or lesson changed (rule 17)

## Dependencies

T-A17-001 → T-A17-002 → T-A17-003 → T-A17-008; T-A17-004/005 and 006/007 are independent of the contract (reference
and app build run serially: one xcodebuild at a time); Polish last.

## Parallel examples

Agent: T-A17-002 (the read-heavy contract audit). Lead: T-A17-001, the reference and build runs (004–007), the gap
completion review (008), the proofs and commits.

## Implementation strategy

MVP: the contract (002, 003, 008) with the baseline (001, 004, 005); the build proof (006, 007) and evidence close the
phase. Review checkpoint after 003 (checker passes) and at 008 (decision).
