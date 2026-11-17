# Tasks: Digital Zen Garden — Phase 00 Foundation and VisualCore boundary audit

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/contract.md](contracts/contract.md), [quickstart.md](quickstart.md). Gate A20-P00 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A20-P00 --timeout 600 --name <check> -- <command>`. Commit
after every task (no trailers); read every check's exit before ticking, never in the same command. No Swift, package
or project change. Precedent: `specs/137-lw-p00-boundary-audit/tasks.md`. Rollback: revert the commits (documents
only).

## Phase 1: Setup

- [X] T-A20-001 Create `docs/apps/digital-zen-garden/README.md` (what the experience is per the manual §1–§2: a calm, tactile sand-raking and stone-arrangement experience with persistent compositions, offline, no permission; that it is an experience of the one app; its documents) and `docs/apps/digital-zen-garden/regression-baseline.md` with the phase start `4a0ba17b` (the specify commit; constitution `eb1f1233`) and the reference pin `d93edd1` — Verified 2026-11-17: 2026-11-17: docs/apps/digital-zen-garden/README.md and regression-baseline.md written (phase start 4a0ba17b, constitution eb1f1233, reference pin d93edd1 read from the submodule)

## Phase 3: User Story 1 — Evidence-backed integration matrix (P1) 🎯

- [X] T-A20-002 [US1] Write `docs/apps/digital-zen-garden/visualcore-contract.json` (schema 1; app `digital-zen-garden`; gate `A20-P00`): `inventory` of every FR-A20-001 area with paths and the release-check step count from `python3 scripts/release_check.py --list`; `matrix` rows covering the 5 brainstorm capabilities and the 6 version 0.1 features (research D2) plus cross-cutting rows (context loss, resize and orientation, quality tiers, accessibility and gesture alternatives, bounded resources, permissions, truthful claims, sound and haptics), each with evidence per clarification Q2, and a row for every item FR-A20-003 lists; `traceability` for all 11 items (FR-A20-001, FR-A20-002, FR-A20-003) — Verified 2026-11-17: 2026-11-17: docs/apps/digital-zen-garden/visualcore-contract.json (schema 1, gate A20-P00): 11 inventory areas (153 release-check steps), 31 matrix rows (11 available, 15 requires adaptation, 5 upstream gap) covering the 5 brainstorm capabilities, the 6 version 0.1 features, every FR-A20-003 item and cross-cutting rows; 12 traceability entries; written by an agent, symbols re-verified, reviewed
- [X] T-A20-003 [US1] Run the contract checker and render the view (`--name contract -- python3 scripts/check_app_contract.py --app digital-zen-garden --render`); `docs/apps/digital-zen-garden/visualcore-contract.md` is generated, with its generated-block markers written before the first render (FR-A20-007, SC-A20-001) — Verified 2026-11-17: 2026-11-17: .autonomy/checks/A20-P00.contract.json exit 0 (PASS: 31 rows, 175 citations, 14 gaps, decision go); visualcore-contract.md generated between its markers, which were written before the first render

## Phase 4: User Story 2 — The reference stays proven (P1)

- [X] T-A20-004 [US2] Reference chunk 1 (`--name reference-1 -- python3 scripts/release_check.py --only reference-engine-xcframework reference-build-projectm-ios-sim reference-clean`) — Verified 2026-11-17: 2026-11-17: .autonomy/checks/A20-P00.reference-1.json exit 0 (reference-engine-xcframework, reference-build-projectm-ios-sim, reference-clean pass)
- [X] T-A20-005 [US2] Reference chunk 2 (`--name reference-2 -- python3 scripts/release_check.py --only reference-test-anglerendering-ios27 reference-test-anglerendering-ios26 projectm-reference-ios27 projectm-reference-ios26`); record the 7 steps, commands and results in `docs/apps/digital-zen-garden/regression-baseline.md` (FR-A20-004, SC-A20-003) — Verified 2026-11-17: 2026-11-17: .autonomy/checks/A20-P00.reference-2.json exit 0 (reference-test-anglerendering-ios27 and -ios26, projectm-reference-ios27 and -ios26 pass); 7 of 7 steps recorded in docs/apps/digital-zen-garden/regression-baseline.md

## Phase 5: User Story 3 — The shell builds with the experience absent (P2)

- [X] T-A20-006 [US3] Build the one app for testing (`--name app-build -- python3 scripts/release_check.py --only app-build-for-testing-ios27`) — Verified 2026-11-17: 2026-11-17: .autonomy/checks/A20-P00.app-build.json exit 0 (app-build-for-testing-ios27 passes with Digital Zen Garden absent)
- [X] T-A20-007 [US3] Experience package check (`--name experience-packages -- python3 scripts/check_experience_packages.py`: 19 experiences, none A20); `grep -c a20 Catalog/registrations.json Apps/VisualCore/App/ExperienceRegistry.swift` gives 0 (FR-A20-005, SC-A20-004) — Verified 2026-11-17: 2026-11-17: .autonomy/checks/A20-P00.experience-packages.json exit 0 (19 experiences in 1 package, none A20); grep -c a20 gives 0 in Catalog/registrations.json and Apps/VisualCore/App/ExperienceRegistry.swift

## Phase 6: User Story 4 — Stop/go decision (P2)

- [X] T-A20-008 [US4] Complete the contract's `gaps` (every non-available row: owning module, VisualCore or app-local, and phase A20-P01..P06 per research D4; the brush-stamp pass, undo stack and named-garden store app-local per clarification Q4), the three manual risks as `negative` entries naming owner, verification method and release-blocker condition (source "manual §13 risk N"), and `decision` (keys `result`, `reasons`, `blockers`; "stop" if no working host, touch input or drawable persistent target); re-run the checker (`--name contract-2`) (FR-A20-003, FR-A20-006, SC-A20-002) — Verified 2026-11-17: 2026-11-17: 14 gaps, all app-local per clarification Q4 (G-DOCUMENT, G-STROKES, G-UNDO A20-P01; G-SAND, G-RELIEF, G-PREVIEW A20-P02; G-STONES, G-SELECTION, G-SHADOWS A20-P03; G-LIBRARY, G-A11Y A20-P04; G-QUIET, G-DEVICE A20-P05; G-RELEASE A20-P06); the three manual risks as negative entries with owner, verification and release-blocker condition; decision go, no blocker; .autonomy/checks/A20-P00.contract-2.json exit 0

## Phase 7: Polish and evidence

- [ ] T-A20-009 No-change proof (`--name no-change -- git diff --exit-code --stat 4a0ba17b..HEAD -- Packages External`) (FR-A20-008, SC-A20-005)
- [ ] T-A20-010 Script tests (`--name script-tests -- python3 scripts/test_scripts.py`) and the release-check document steps (`--name fast-checks -- python3 scripts/release_check.py --only docs app-contracts compliance dependencies`); every run-check of this gate stays within its 600 s limit and the contract check under 10 s (SC-A20-006)
- [ ] T-A20-011 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record A20-P00; update README.md (status, gate count) in the record commit (rule 16) and `docs/automatedtesting.md` if a test tool, rule or lesson changed (rule 17)

## Dependencies

T-A20-001 → T-A20-002 → T-A20-003 → T-A20-008; T-A20-004/005 and 006/007 are independent of the contract (reference
and app build run serially: one xcodebuild at a time); Polish last.

## Parallel examples

Agent: T-A20-002 (the read-heavy contract audit). Lead: T-A20-001, the reference and build runs (004–007), the gap
completion review (008), the proofs and commits.

## Implementation strategy

MVP: the contract (002, 003, 008) with the baseline (001, 004, 005); the build proof (006, 007) and evidence close the
phase. Review checkpoint after 003 (checker passes) and at 008 (decision).
