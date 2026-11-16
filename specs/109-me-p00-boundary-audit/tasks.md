# Tasks: Molecular Explorer — Phase 00 Foundation and VisualCore boundary audit

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/contract.md](contracts/contract.md), [quickstart.md](quickstart.md). Gate A15-P00 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A15-P00 --timeout 600 --name <check> -- <command>`. Commit
after every task (no trailers); read every check's exit before ticking. No Swift, package or project change.

## Phase 1: Setup

- [X] T-A15-001 Create `docs/apps/molecular-explorer/README.md` (what the experience is per the manual §1–§2: an approachable 3D molecule viewer with clear atom and bond styling and constrained structured-data import; that it is an experience of the one app; its documents) and `docs/apps/molecular-explorer/regression-baseline.md` with the phase start `fc60a33d` (the specify commit; constitution `aaeeb3a7`) and the reference pin `d93edd1` — Verified 2026-11-15: docs/apps/molecular-explorer/README.md (manual §1–§2 goal, audiences, version 0.1 features, non-goals, one-app placement, documents) and regression-baseline.md (phase start fc60a33d after constitution aaeeb3a7, pin d93edd1, the seven steps)

## Phase 3: User Story 1 — Evidence-backed integration matrix (P1) 🎯

- [X] T-A15-002 [US1] Write `docs/apps/molecular-explorer/visualcore-contract.json` (schema 1; app `molecular-explorer`; gate `A15-P00`): `inventory` of every FR-A15-001 area with paths, the release-check step count from `python3 scripts/release_check.py --list`; `matrix` rows covering the 5 brainstorm capabilities (instanced geometry, materials, camera controls, lighting, structured scientific data visualization) and 6 version 0.1 features plus cross-cutting rows (strict bounded XYZ parsing with typed errors, inferred bonds labelled as estimates, determinism, persistence with migration, quality tiers and low power, accessibility with Reduce Motion and colour-independent element identity, lifecycle and context loss, data provenance and licenses, file import through the document picker without permissions, truthful claims) with status ∈ {available, requires adaptation, upstream gap} per clarification 2 and file/symbol/product evidence; `traceability`; `negative` rules of FR-A15-006 (FR-A15-001, 002) — Verified 2026-11-15: docs/apps/molecular-explorer/visualcore-contract.json (schema 1, gate A15-P00): 11 inventory areas incl. 128 release-check steps, 23 matrix rows (5 brainstorm capabilities, 6 version 0.1 features, cross-cutting rows), traceability and 14 negative rules; drafted by an agent, every cited path and symbol retested by the checker (149 citations)
- [X] T-A15-003 [US1] Run the contract checker and render the view (`--name contract -- python3 scripts/check_app_contract.py --app molecular-explorer --render`); `docs/apps/molecular-explorer/visualcore-contract.md` is generated (FR-A15-007, SC-A15-001) — Verified 2026-11-15: .autonomy/checks/A15-P00.contract-2.json exit 0 in 0.05 s (PASS: 23 rows, 149 citations, 11 gaps, decision go); visualcore-contract.md generated with --render (the first run, .autonomy/checks/A15-P00.contract.json exit 1, lacked the view's generated-block markers; the intro with markers was added)

## Phase 4: User Story 2 — The reference stays proven (P1)

- [X] T-A15-004 [US2] Reference chunk 1 (`--name reference-1 -- python3 scripts/release_check.py --only reference-engine-xcframework reference-build-projectm-ios-sim reference-clean`) — Verified 2026-11-15: .autonomy/checks/A15-P00.reference-1.json exit 0 (reference-engine-xcframework, reference-build-projectm-ios-sim, reference-clean)
- [X] T-A15-005 [US2] Reference chunk 2 (`--name reference-2 -- python3 scripts/release_check.py --only reference-test-anglerendering-ios27 reference-test-anglerendering-ios26 projectm-reference-ios27 projectm-reference-ios26`); record the 7 steps, commands and results in `docs/apps/molecular-explorer/regression-baseline.md` (FR-A15-004, SC-A15-003) — Verified 2026-11-15: .autonomy/checks/A15-P00.reference-2.json exit 0 (anglerendering iOS 27 and 26, projectm reference iOS 27 and 26); 7 of 7 steps recorded in docs/apps/molecular-explorer/regression-baseline.md

## Phase 5: User Story 3 — The shell builds with the experience absent (P2)

- [X] T-A15-006 [US3] Build the one app for testing (`--name app-build -- python3 scripts/release_check.py --only app-build-for-testing-ios27`) — Verified 2026-11-15: .autonomy/checks/A15-P00.app-build.json exit 0 (app-build-for-testing-ios27 with Molecular Explorer absent)
- [X] T-A15-007 [US3] Experience package check (`--name experience-packages -- python3 scripts/check_experience_packages.py`: 14 experiences, none A15); `grep -c a15 Catalog/registrations.json Apps/VisualCore/App/ExperienceRegistry.swift` gives 0 (FR-A15-005, SC-A15-004) — Verified 2026-11-15: .autonomy/checks/A15-P00.experience-packages.json exit 0 (PASS: 14 experiences in 1 packages); grep -c a15 gives 0 in Catalog/registrations.json and Apps/VisualCore/App/ExperienceRegistry.swift

## Phase 6: User Story 4 — Stop/go decision (P2)

- [X] T-A15-008 [US4] Complete the contract's `gaps` (every non-available row: owning module, VisualCore or app-local, and phase A15-P01..P06) and `decision` (verdict and reasons; "stop" if no working host or buildable 3D drawing path; the element catalog, the domain with versioned schemas, the strict XYZ parser, inferred bonds, sphere and cylinder geometry, instancing or batching, display modes, picking, persisted camera, labels and metadata panel, curated library, document-picker import, recent molecules and settings assessed per FR-A15-003 with the owners of clarification 5); re-run the checker (`--name contract-final -- python3 scripts/check_app_contract.py --app molecular-explorer --render`) (FR-A15-003, 006; SC-A15-002) — Verified 2026-11-15: contract gaps: 11 app-local gaps covering all 14 non-available rows with owner and phase 1-5; decision go (RenderHost, MeshRenderer, DepthMeshPass, OrbitCamera public and tested; no blocker); research §2 records the audit as found (Mesh.tube is a tested capped cylinder, correcting clarification 5); .autonomy/checks/A15-P00.contract-final.json exit 0

## Phase 7: Polish and evidence

- [X] T-A15-009 No-change proof (`--name no-change -- git diff --exit-code --stat fc60a33d..HEAD -- Packages External`) (FR-A15-008, SC-A15-005) — Verified 2026-11-15: .autonomy/checks/A15-P00.no-change.json exit 0 (git diff --exit-code --stat fc60a33d..HEAD -- Packages External is empty)
- [X] T-A15-010 Script tests (`--name script-tests -- python3 scripts/test_scripts.py`) and the release-check document steps (`--name fast-checks -- python3 scripts/release_check.py --only docs app-contracts compliance dependencies`); every run-check of this gate stays within its 600 s limit and the contract check under 10 s (SC-A15-006) — Verified 2026-11-15: .autonomy/checks/A15-P00.script-tests-2.json exit 0 (42 s, rerun after the contract existed; the earlier script-tests run passed too) and .autonomy/checks/A15-P00.fast-checks.json exit 0 (docs, app-contracts, compliance, dependencies in 2.7 s); every run-check under its 600 s limit (longest 42 s), contract check 0.05 s
- [ ] T-A15-011 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record A15-P00; update README.md (status, gate count) in the record commit (rule 16) and `docs/automatedtesting.md` if a test tool, rule or lesson changed (rule 17)

## Dependencies

T-A15-001 → T-A15-002 → T-A15-003 → T-A15-008; T-A15-004/005 and 006/007 are independent of the contract (reference
and app build run serially: one xcodebuild at a time); Polish last.

## Parallel examples

Agent: T-A15-002 (contract draft, read-heavy). Lead: T-A15-001, the runs, T-A15-008 review, ticks and commits.

## Implementation strategy

MVP is US1 (the matrix) with US2 (reference); US3 and US4 complete the gate.

## Phase 8: Convergence

- [X] T-A15-012 Cite `docs/apps/molecular-explorer/regression-baseline.md` in the `paths` of the contract's "ProjectM reference regression" inventory area (it exists now with 7 of 7 results; the description still says "written by T-A15-001/005") and re-run the checker (`--name contract-final-2 -- python3 scripts/check_app_contract.py --app molecular-explorer --render`) per FR-A15-001, FR-A15-004 (partial) — Verified 2026-11-15: the contract's ProjectM reference regression area cites docs/apps/molecular-explorer/regression-baseline.md in its paths and states 7 of 7 passing; .autonomy/checks/A15-P00.contract-final-2.json exit 0 (PASS: 23 rows, 149 citations, 11 gaps, decision go)
