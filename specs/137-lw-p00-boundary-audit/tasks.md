# Tasks: Living Wallpapers — Phase 00 Foundation and VisualCore boundary audit

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/contract.md](contracts/contract.md), [quickstart.md](quickstart.md). Gate A19-P00 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A19-P00 --timeout 600 --name <check> -- <command>`. Commit
after every task (no trailers); read every check's exit before ticking, never in the same command. No Swift, package
or project change. Precedent: `specs/130-ac-p00-boundary-audit/tasks.md`. Rollback: revert the commits (documents
only).

## Phase 1: Setup

- [X] T-A19-001 Create `docs/apps/living-wallpapers/README.md` (what the experience is per the manual §1–§2: a creator of procedural backgrounds exported as correctly sized stills, applied by the person through the system's own controls, offline; that it is an experience of the one app; its documents) and `docs/apps/living-wallpapers/regression-baseline.md` with the phase start `530855ef` (the specify commit; constitution `2f592d76`) and the reference pin `d93edd1` — Verified 2026-11-17: 2026-11-17: docs/apps/living-wallpapers/README.md and regression-baseline.md written (phase start 530855ef, constitution 2f592d76, reference pin d93edd1); validate_docs.py PASS

## Phase 3: User Story 1 — Evidence-backed integration matrix (P1) 🎯

- [X] T-A19-002 [US1] Write `docs/apps/living-wallpapers/visualcore-contract.json` (schema 1; app `living-wallpapers`; gate `A19-P00`): `inventory` of every FR-A19-001 area with paths and the release-check step count from `python3 scripts/release_check.py --list`; `matrix` rows covering the 5 brainstorm capabilities (offscreen rendering, high-resolution rendering, effects and compositing, frame capture, export pipelines) and the 6 version 0.1 features (research D2) plus cross-cutting rows (size limits and the fallback, GPU budget and memory warnings, encoding with a verified sRGB profile, still at a chosen time, share-sheet saving with the permission word, export job with progress, cancellation and cleanup, history in experience storage, device templates with provenance, lifecycle with resize and context loss, quality tiers, accessibility, licenses, truthful claims) with status ∈ {available, requires adaptation, upstream gap} per clarification 2 and evidence files, symbols and products verified in code; `traceability`; `negative` per FR-A19-006 (FR-A19-001, 002, 006) — Verified 2026-11-17: 2026-11-17: docs/apps/living-wallpapers/visualcore-contract.json written (11 inventory areas, 148 release-check steps; 26 matrix rows: 8 available, 15 requires adaptation, 3 upstream gap; 130 citations; 14 gaps; 14 negative entries incl. the three manual risks; decision go); written by an agent, rechecked by the lead (every row and gap read; the checker re-verifies every citation)
- [X] T-A19-003 [US1] Run the contract checker and render the view (`--name contract -- python3 scripts/check_app_contract.py --app living-wallpapers --render`); `docs/apps/living-wallpapers/visualcore-contract.md` is generated, with its generated-block markers written before the first render (FR-A19-007, SC-A19-001) — Verified 2026-11-17: 2026-11-17: .autonomy/checks/A19-P00.contract.json exit 0 (PASS: 26 rows, 130 citations, 14 gaps, decision go); visualcore-contract.md generated between its markers, which were written before the first render

## Phase 4: User Story 2 — The reference stays proven (P1)

- [X] T-A19-004 [US2] Reference chunk 1 (`--name reference-1 -- python3 scripts/release_check.py --only reference-engine-xcframework reference-build-projectm-ios-sim reference-clean`) — Verified 2026-11-17: 2026-11-17: .autonomy/checks/A19-P00.reference-1.json exit 0 (reference-engine-xcframework, reference-build-projectm-ios-sim, reference-clean pass)
- [X] T-A19-005 [US2] Reference chunk 2 (`--name reference-2 -- python3 scripts/release_check.py --only reference-test-anglerendering-ios27 reference-test-anglerendering-ios26 projectm-reference-ios27 projectm-reference-ios26`); record the 7 steps, commands and results in `docs/apps/living-wallpapers/regression-baseline.md` (FR-A19-004, SC-A19-003) — Verified 2026-11-17: 2026-11-17: .autonomy/checks/A19-P00.reference-2.json exit 0 (reference-test-anglerendering-ios27 and -ios26, projectm-reference-ios27 and -ios26 pass); 7 of 7 steps recorded in docs/apps/living-wallpapers/regression-baseline.md (committed here; it belongs to T-A19-001 too)

## Phase 5: User Story 3 — The shell builds with the experience absent (P2)

- [X] T-A19-006 [US3] Build the one app for testing (`--name app-build -- python3 scripts/release_check.py --only app-build-for-testing-ios27`) — Verified 2026-11-17: 2026-11-17: .autonomy/checks/A19-P00.app-build.json exit 0 (app-build-for-testing-ios27 passes with Living Wallpapers absent)
- [ ] T-A19-007 [US3] Experience package check (`--name experience-packages -- python3 scripts/check_experience_packages.py`: 18 experiences, none A19); `grep -c a19 Catalog/registrations.json Apps/VisualCore/App/ExperienceRegistry.swift` gives 0 (FR-A19-005, SC-A19-004)

## Phase 6: User Story 4 — Stop/go decision (P2)

- [ ] T-A19-008 [US4] Complete the contract's `gaps` (every non-available row: owning module, VisualCore or app-local, and phase A19-P01..P06 per research D4, with G-ENCODE `VisualCore:VisualCoreRendering` A19-P02, G-STILLTIME `VisualCore:VisualCoreExperienceHost` A19-P02 and G-VIDEO decided at A19-P01 assessed), the three manual risks as `negative` entries naming owner, verification method and release-blocker condition (source "manual §13 risk N"), and `decision` (keys `result`, `reasons`, `blockers`; "stop" if no working host or no offscreen render-and-read-back path); re-run the checker (`--name contract-final -- python3 scripts/check_app_contract.py --app living-wallpapers --render`) (FR-A19-003, 006; SC-A19-002)

## Phase 7: Polish and evidence

- [ ] T-A19-009 No-change proof (`--name no-change -- git diff --exit-code --stat 530855ef..HEAD -- Packages External`) (FR-A19-008, SC-A19-005)
- [ ] T-A19-010 Script tests (`--name script-tests -- python3 scripts/test_scripts.py`) and the release-check document steps (`--name fast-checks -- python3 scripts/release_check.py --only docs app-contracts compliance dependencies`); every run-check of this gate stays within its 600 s limit and the contract check under 10 s (SC-A19-006)
- [ ] T-A19-011 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record A19-P00; update README.md (status, gate count) in the record commit (rule 16) and `docs/automatedtesting.md` if a test tool, rule or lesson changed (rule 17)

## Dependencies

T-A19-001 → T-A19-002 → T-A19-003 → T-A19-008; T-A19-004/005 and 006/007 are independent of the contract (reference
and app build run serially: one xcodebuild at a time); Polish last.

## Parallel examples

Agent: T-A19-002 (the read-heavy contract audit). Lead: T-A19-001, the reference and build runs (004–007), the gap
completion review (008), the proofs and commits.

## Implementation strategy

MVP: the contract (002, 003, 008) with the baseline (001, 004, 005); the build proof (006, 007) and evidence close the
phase. Review checkpoint after 003 (checker passes) and at 008 (decision).
