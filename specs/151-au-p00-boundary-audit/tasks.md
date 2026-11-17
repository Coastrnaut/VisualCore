# Tasks: Aurora — Phase 00 Foundation and VisualCore boundary audit

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/contract.md](contracts/contract.md), [quickstart.md](quickstart.md). Gate A21-P00 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A21-P00 --timeout 595 --name <check> -- <command>`. Commit
after every task (no trailers); read every check's exit before ticking, never in the same command. No Swift, package
or project change. Precedent: `specs/144-zg-p00-boundary-audit/tasks.md`. Rollback: revert the commits (documents
only).

## Phase 1: Setup

- [X] T-A21-001 Create `docs/apps/aurora/README.md` (what the experience is per the manual §1–§2: a full-screen — Verified 2026-11-17: 2026-11-17: docs/apps/aurora/README.md (the experience per the manual §1–§2, stylized and not a forecast, offline, no permission, an experience of the one app) and regression-baseline.md (phase start b40fdbee, constitution d143ebd2, pin d93edd1) written; validate_docs exit 0
  ambient aurora experience with procedural skies, gentle stars and optional synthesised sound, stylized and not a
  forecast, offline, no permission; that it is an experience of the one app; its documents) and
  `docs/apps/aurora/regression-baseline.md` with the phase start `b40fdbee` (the specify commit; constitution
  `d143ebd2`) and the reference pin `d93edd1`

## Phase 3: User Story 1 — Evidence-backed integration matrix (P1) 🎯

- [X] T-A21-002 [US1] Write `docs/apps/aurora/visualcore-contract.json` (schema 1; app `aurora`; gate `A21-P00`): — Verified 2026-11-17: 2026-11-17: docs/apps/aurora/visualcore-contract.json (schema 1, gate A21-P00): 10 inventory areas with real paths (158 release-check lines), 26 matrix rows (5 brainstorm capabilities available, the 6 version 0.1 features, 15 cross-cutting rows) with evidence of public declarations in framework products, 12 traceability entries; written by an agent, reviewed
  `inventory` of every FR-A21-001 area with paths and the release-check line count from `python3
  scripts/release_check.py --list`; `matrix` rows covering the 5 brainstorm capabilities and the 6 version 0.1
  features (research D2) plus cross-cutting rows (context loss, resize and orientation, quality tiers, accessibility,
  bounded resources, permissions, rendered versus wall-clock time, truthful claims), each with evidence per
  clarification Q2 ("a public declaration in a VisualCore framework product with at least one test"), and a
  `traceability` entry per capability and feature (FR-A21-001, FR-A21-002)
- [ ] T-A21-003 [US1] Run the contract checker and render the view (`--name contract -- python3
  scripts/check_app_contract.py --app aurora --render`); `docs/apps/aurora/visualcore-contract.md` is generated, with
  its generated-block markers written before the first render (FR-A21-007, SC-A21-001)

## Phase 4: User Story 2 — The reference stays proven (P1)

- [X] T-A21-004 [US2] Reference chunk 1 (`--name reference-1 -- python3 scripts/release_check.py --only — Verified 2026-11-17: 2026-11-17: .autonomy/checks/A21-P00.reference-1.json exit 0 (reference-engine-xcframework, reference-build-projectm-ios-sim, reference-clean pass)
  reference-engine-xcframework reference-build-projectm-ios-sim reference-clean`)
- [X] T-A21-005 [US2] Reference chunk 2 (`--name reference-2 -- python3 scripts/release_check.py --only — Verified 2026-11-17: 2026-11-17: .autonomy/checks/A21-P00.reference-2.json exit 0 (reference-test-anglerendering-ios27 and -ios26, projectm-reference-ios27 and -ios26 pass); 7 of 7 steps recorded in docs/apps/aurora/regression-baseline.md
  reference-test-anglerendering-ios27 reference-test-anglerendering-ios26 projectm-reference-ios27
  projectm-reference-ios26`); record the 7 steps, commands and results in `docs/apps/aurora/regression-baseline.md`
  (FR-A21-004, SC-A21-003)

## Phase 5: User Story 3 — The shell builds with the experience absent (P2)

- [X] T-A21-006 [US3] Build the one app for testing (`--name app-build -- python3 scripts/release_check.py --only — Verified 2026-11-17: 2026-11-17: .autonomy/checks/A21-P00.app-build.json exit 0 (app-build-for-testing-ios27 passes with Aurora absent)
  app-build-for-testing-ios27`)
- [X] T-A21-007 [US3] Experience package check (`--name experience-packages -- python3 — Verified 2026-11-17: 2026-11-17: .autonomy/checks/A21-P00.experience-packages.json exit 0 (20 experiences in 1 package, none A21); grep -c a21 gives 0 in Catalog/registrations.json and Apps/VisualCore/App/ExperienceRegistry.swift
  scripts/check_experience_packages.py`: 20 experiences, none A21); `grep -c a21 Catalog/registrations.json
  Apps/VisualCore/App/ExperienceRegistry.swift` gives 0 (FR-A21-005, SC-A21-004)

## Phase 6: User Story 4 — Stop/go decision (P2)

- [ ] T-A21-008 [US4] Complete the contract's `gaps` (every non-available row: owning module, VisualCore or
  app-local, and phase A21-P01..P06 per research D4; the ambient loop player owned by VisualCoreAudio in A21-P04 per
  clarification Q4; the luminance cap, static fallback and hide-and-restore controls app-local per clarifications Q3
  and Q5), the three manual risks as `negative` entries naming owner, verification method and release-blocker
  condition (source "manual §13 risk N"), and `decision` (keys `result`, `reasons`, `blockers`; "stop" if no working
  host, full-screen shader drawing or additive compositing); re-run the checker (`--name contract-2`) (FR-A21-003,
  FR-A21-006, SC-A21-002)

## Phase 7: Polish and evidence

- [ ] T-A21-009 No-change proof (`--name no-change -- git diff --exit-code --stat b40fdbee..HEAD -- Packages
  External`) (FR-A21-008, SC-A21-005)
- [ ] T-A21-010 Script tests (`--name script-tests -- python3 scripts/test_scripts.py`) and the release-check document
  steps (`--name fast-checks -- python3 scripts/release_check.py --only docs app-contracts compliance dependencies`);
  every run-check of this gate stays within its limit and the contract check under 10 s (SC-A21-006)
- [ ] T-A21-011 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record
  A21-P00; update README.md (status, gate count) in the record commit (rule 16) and `docs/automatedtesting.md` if a
  test tool, rule or lesson changed (rule 17)

## Dependencies

T-A21-001 → T-A21-002 → T-A21-003 → T-A21-008; T-A21-004/005 and 006/007 are independent of the contract (reference
and app build run serially: one xcodebuild at a time); Polish last.

## Parallel examples

Agent: T-A21-002 (the read-heavy contract audit). Lead: T-A21-001, the reference and build runs (004–007), the gap
completion review (008), the proofs and commits.

## Implementation strategy

MVP: the contract (002, 003, 008) with the baseline (001, 004, 005); the build proof (006, 007) and evidence close the
phase. Review checkpoint after 003 (checker passes) and at 008 (decision). One commit per task.
