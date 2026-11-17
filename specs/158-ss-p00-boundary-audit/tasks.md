# Tasks: Shader Studio — Phase 00 Foundation and VisualCore boundary audit

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/contract.md](contracts/contract.md), [quickstart.md](quickstart.md). Gate A22-P00 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A22-P00 --timeout 595 --name <check> -- <command>`.
- **Commits:** one after every task, with no trailers.
- **Checks:** read every check's exit before ticking, never in the same command.
- **Scope:** no Swift, package or project change.
- **Precedent:** `specs/151-au-p00-boundary-audit/tasks.md`.
- **Rollback:** revert the commits (documents only).

## Phase 1: Setup

- [X] T-A22-001 Create the two starting documents: — Verified 2026-11-17: 2026-11-17: docs/apps/shader-studio/README.md (the manual's product goal, version 0.1 features, non-goals and no sandbox claim; an experience of the one app; constitution 2.18.1) and regression-baseline.md (phase start 6218b9a1, constitution 27d7d83e amended 0577dcb0, pin d93edd1); validate_docs PASS
  - `docs/apps/shader-studio/README.md`, from the manual §1–§2: a mobile GLSL ES editor that compiles local shaders,
    shows diagnostics and safely previews bounded work; offline; no permission; no sandbox claim; an experience of the
    one app; its documents;
  - `docs/apps/shader-studio/regression-baseline.md`, with the phase start `6218b9a1` (the specify commit;
    constitution `27d7d83e`, amended `0577dcb0`) and the reference pin `d93edd1`

## Phase 3: User Story 1 — Evidence-backed integration matrix (P1) 🎯

- [ ] T-A22-002 [US1] Write `docs/apps/shader-studio/visualcore-contract.json` (schema 1; app `shader-studio`; gate
  `A22-P00`), with:
  - an `inventory` of every FR-A22-001 area, with paths and the release-check line count (163, from `python3
    scripts/release_check.py --list`);
  - `matrix` rows covering the 5 brainstorm capabilities and the 6 version 0.1 features (research D2);
  - cross-cutting rows: context loss, resize and orientation, quality tiers, accessibility, bounded resources,
    permissions, the compatibility profile, the render thread and compile requests, and truthful claims;
  - on every row, evidence per clarification Q2 ("a public declaration in a VisualCore framework product with at
    least one test"), with the facts of the clarification session;
  - a `traceability` entry per capability and feature
  (FR-A22-001, FR-A22-002)
- [ ] T-A22-003 [US1] Write the generated-block markers into `docs/apps/shader-studio/visualcore-contract.md` before
  the first render, then run the contract checker and render the view (`--name contract -- python3
  scripts/check_app_contract.py --app shader-studio --render`) (FR-A22-007, SC-A22-001)

## Phase 4: User Story 2 — The reference stays proven (P1)

- [ ] T-A22-004 [US2] Reference chunk 1 (`--name reference-1 -- python3 scripts/release_check.py --only
  reference-engine-xcframework reference-build-projectm-ios-sim reference-clean`)
- [ ] T-A22-005 [US2] Reference chunk 2 (`--name reference-2 -- python3 scripts/release_check.py --only
  reference-test-anglerendering-ios27 reference-test-anglerendering-ios26 projectm-reference-ios27
  projectm-reference-ios26`); record the 7 steps, commands and results in
  `docs/apps/shader-studio/regression-baseline.md` (FR-A22-004, SC-A22-003)

## Phase 5: User Story 3 — The shell builds with the experience absent (P2)

- [ ] T-A22-006 [US3] Build the one app for testing (`--name app-build -- python3 scripts/release_check.py --only
  app-build-for-testing-ios27`)
- [ ] T-A22-007 [US3] Experience package check:
  - `--name experience-packages -- python3 scripts/check_experience_packages.py` passes (21 experiences, none A22);
  - `grep -c a22 Catalog/registrations.json Apps/VisualCore/App/ExperienceRegistry.swift` gives 0
  (FR-A22-005, SC-A22-004)

## Phase 6: User Story 4 — Stop/go decision (P2)

- [ ] T-A22-008 [US4] Complete the contract, then rerun the checker (`--name contract-2`):
  - **`gaps`:** for every non-available row, the owning module and the phase per research D4. All are app-local per
    clarifications Q3–Q5: the preview scene with its last-good swap, the watchdog, the editor, the project library,
    the texture inputs and the source validator. No upstream gap.
  - **Risks:** the three manual risks as `negative` entries naming the owner, verification method and
    release-blocker condition (source "manual §13 risk N").
  - **`decision`:** keys `result`, `reasons`, `blockers`. It is "stop" if no runtime compile in the host's context,
    no compile log or no full-screen drawing.
  (FR-A22-003, FR-A22-006, SC-A22-002)

## Phase 7: Polish and evidence

- [ ] T-A22-009 No-change proof (`--name no-change -- git diff --exit-code --stat 6218b9a1..HEAD -- Packages
  External`) (FR-A22-008, SC-A22-005)
- [ ] T-A22-010 Run the script tests (`--name script-tests -- python3 scripts/test_scripts.py`) and the release-check
  document steps (`--name fast-checks -- python3 scripts/release_check.py --only docs app-contracts compliance
  dependencies`). Every run-check of this gate stays within its limit, and the contract check runs in under 10 s
  (SC-A22-006)
- [ ] T-A22-011 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record
  A22-P00. Update README.md (status, gate count) in the record commit (rule 16), and `docs/automatedtesting.md` if a
  test tool, rule or lesson changed (rule 17)

## Dependencies

- **Contract:** T-A22-001 → T-A22-002 → T-A22-003 → T-A22-008.
- **Independent of the contract:** T-A22-004/005 and 006/007. The reference and the build run one after the other,
  because only one xcodebuild runs at a time.
- **Last:** the polish tasks.

## Parallel examples

- **Agent:** T-A22-002, the read-heavy contract audit.
- **Lead:** T-A22-001, the reference and build runs (004–007), the gap review (008), the proofs and the commits.

## Implementation strategy

- **MVP:** the contract (002, 003, 008) with the baseline (001, 004, 005).
- **Close:** the build proof (006, 007) and the evidence close the phase.
- **Review checkpoints:** after 003 (the checker passes) and at 008 (the decision).
- **Commits:** one per task.
