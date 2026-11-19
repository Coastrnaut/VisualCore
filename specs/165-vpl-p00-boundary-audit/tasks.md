# Tasks: Visual Programming Lab — Phase 00 Foundation and VisualCore boundary audit

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/contract.md](contracts/contract.md), [quickstart.md](quickstart.md). Gate A23-P00 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A23-P00 --timeout 595 --name <check> -- <command>`.
- **Commits:** one after every task, with no trailers.
- **Checks:** read every check's exit before ticking, never in the same command.
- **Scope:** no Swift, package or project change.
- **Precedent:** `specs/158-ss-p00-boundary-audit/tasks.md`.
- **Rollback:** revert the commits (documents only).

## Phase 1: Setup

- [X] T-A23-001 Create the two starting documents: — Verified 2026-11-18: 2026-11-18: docs/apps/visual-programming-lab/README.md (manual §1-§2 product goal, version 0.1 features, non-goals; an experience of the one app; constitution 2.19.0) and regression-baseline.md (phase start 7b64fedf, constitution 0a9405b5, pin d93edd1); validate_docs PASS
  - `docs/apps/visual-programming-lab/README.md`, from the manual §1–§2: a node-based visual programming lab whose
    typed graphs compile into bounded GPU passes drawn in the host's context; offline; no permission; no arbitrary
    scripting; an experience of the one app; its documents;
  - `docs/apps/visual-programming-lab/regression-baseline.md`, with the phase start `7b64fedf` (the specify commit;
    constitution 2.19.0 at `0a9405b5`) and the reference pin `d93edd1`

## Phase 3: User Story 1 — Evidence-backed integration matrix (P1) 🎯

- [X] T-A23-002 [US1] Write `docs/apps/visual-programming-lab/visualcore-contract.json` (schema 1; app — Verified 2026-11-18: 2026-11-18: docs/apps/visual-programming-lab/visualcore-contract.json: 9 inventory areas with real paths (release_check --list 168 lines), 32 matrix rows (5 capabilities, 6 features, the ten FR-A23-003 areas and cross-cutting rows; 9 available, 23 requires adaptation), 167 citations of public VisualCore symbols, traceability for every capability and feature; written by an agent, reviewed and checked
  `visual-programming-lab`; gate `A23-P00`), with:
  - an `inventory` of every FR-A23-001 area, with paths and the release-check line count (168, from `python3
    scripts/release_check.py --list`);
  - `matrix` rows covering the 5 brainstorm capabilities (render graph, compositing, parameter system, reusable
    effects, graph serialization) and the 6 version 0.1 features (typed graph; node library; touch canvas; cycle
    detection and feedback; preview compiler; versioned persistence) (research D3);
  - rows for the ten FR-A23-003 areas and cross-cutting rows: context loss, resize and orientation, quality tiers,
    accessibility, bounded resources, permissions, the render thread and compile timing, and truthful claims;
  - on every row, evidence as "a public declaration in a VisualCore framework product with at least one test", with
    the facts of the clarification session (closed pass set of `EffectGraphDescription`, private Kahn order, internal
    blur shader, `FieldPass`, `PingPongTarget`, `ResourceBudget`, `MigrationChain`, `ExperienceStorage`,
    `PlaneViewport`, `Camera2D`);
  - a `traceability` entry per capability and feature
  (FR-A23-001, FR-A23-002)
- [X] T-A23-003 [US1] Write the generated-block markers into `docs/apps/visual-programming-lab/visualcore-contract.md` — Verified 2026-11-18: 2026-11-18: .autonomy/checks/A23-P00.contract.json exit 0 (PASS: 32 rows, 167 citations, 9 gaps, decision go; 0.05 s); visualcore-contract.md rendered between its generated-block markers
  before the first render, then run the contract checker and render the view (`--name contract -- python3
  scripts/check_app_contract.py --app visual-programming-lab --render`) (FR-A23-007, SC-A23-001)

## Phase 4: User Story 2 — The reference stays proven (P1)

- [X] T-A23-004 [US2] Reference chunk 1 (`--name reference-1 -- python3 scripts/release_check.py --only — Verified 2026-11-18: 2026-11-18: .autonomy/checks/A23-P00.reference-1.json exit 0 (3/3: reference-engine-xcframework, reference-build-projectm-ios-sim, reference-clean) on the phase-start tree
  reference-engine-xcframework reference-build-projectm-ios-sim reference-clean`)
- [X] T-A23-005 [US2] Reference chunk 2 (`--name reference-2 -- python3 scripts/release_check.py --only — Verified 2026-11-18: 2026-11-18: .autonomy/checks/A23-P00.reference-2.json exit 0 (4/4: reference-test-anglerendering-ios27 and -ios26, projectm-reference-ios27 and -ios26); the 7 steps, commands and results recorded in docs/apps/visual-programming-lab/regression-baseline.md
  reference-test-anglerendering-ios27 reference-test-anglerendering-ios26 projectm-reference-ios27
  projectm-reference-ios26`); record the 7 steps, commands and results in
  `docs/apps/visual-programming-lab/regression-baseline.md` (FR-A23-004, SC-A23-003)

## Phase 5: User Story 3 — The shell builds with the experience absent (P2)

- [X] T-A23-006 [US3] Build the one app for testing (`--name app-build -- python3 scripts/release_check.py --only — Verified 2026-11-18: 2026-11-18: .autonomy/checks/A23-P00.app-build.json exit 0 (build for testing on the iOS 27.2 phone simulator with Visual Programming Lab absent)
  app-build-for-testing-ios27`)
- [X] T-A23-007 [US3] Experience package check: — Verified 2026-11-18: 2026-11-18: .autonomy/checks/A23-P00.experience-packages.json exit 0 (PASS: 22 experiences); grep -c a23 Catalog/registrations.json Apps/VisualCore/App/ExperienceRegistry.swift gives 0 and 0
  - `--name experience-packages -- python3 scripts/check_experience_packages.py` passes (22 experiences, none A23);
  - `grep -c a23 Catalog/registrations.json Apps/VisualCore/App/ExperienceRegistry.swift` gives 0 and 0
  (FR-A23-005, SC-A23-004)

## Phase 6: User Story 4 — Stop/go decision (P2)

- [X] T-A23-008 [US4] Complete the contract, then rerun the checker (`--name contract-2`): — Verified 2026-11-18: 2026-11-18: 9 gaps, all app-local adaptations with phases A23-P01..P06 per research D4 (G-MODEL, G-TYPES; G-CANVAS; G-COMPILE, G-OPERATORS, G-BUDGET; G-LIBRARY; G-DEVICE; G-RELEASE), no upstream gap; 15 negative entries (the FR-A23-006 rules, a no-fork rule and the manual §13 risks 1-3 with owner, verification and release blocker); decision go with reasons (US4 scenario 2 stop condition not met), no blockers; .autonomy/checks/A23-P00.contract-2.json exit 0
  - **`gaps`:** for every non-available row, the owning module and the phase per research D4: G-MODEL, G-TYPES
    (A23-P01); G-CANVAS (A23-P02); G-COMPILE, G-OPERATORS, G-BUDGET (A23-P03); G-LIBRARY (A23-P04); the device plan
    (A23-P05); release (A23-P06). All are app-local per the five clarification answers (session 2026-11-18). No upstream gap.
  - **Risks:** the three manual risks (texture memory from user graphs, touch wiring on small screens, graph-format
    migration) as `negative` entries naming the owner, verification method and release-blocker condition (source
    "manual §13 risk N"); plus the FR-A23-006 negative rules.
  - **`decision`:** keys `result`, `reasons`, `blockers`. It is "stop" (US4 scenario 2) if a chain of passes over
    render targets in the host's context, sampling one pass's output in the next, or a bounded generated fragment
    program is missing and cannot be built over the existing renderer; a missing host never permits a second backend.
  (FR-A23-003, FR-A23-006, SC-A23-002)

## Phase 7: Polish and evidence

- [X] T-A23-009 No-change proof (`--name no-change -- git diff --exit-code --stat 7b64fedf..HEAD -- Packages — Verified 2026-11-18: 2026-11-18: .autonomy/checks/A23-P00.no-change.json exit 0 (git diff --exit-code --stat 7b64fedf..HEAD -- Packages External is empty)
  External`) (FR-A23-008, SC-A23-005)
- [ ] T-A23-010 Run the script tests (`--name script-tests -- python3 scripts/test_scripts.py`) and the release-check
  document steps (`--name fast-checks -- python3 scripts/release_check.py --only docs app-contracts compliance
  dependencies`). Every run-check of this gate stays within its limit, and the contract check runs in under 10 s
  (SC-A23-006)
- [ ] T-A23-011 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record
  A23-P00. Update README.md (status, gate count) in the record commit (rule 16), and `docs/automatedtesting.md` if a
  test tool, rule or lesson changed (rule 17)

## Dependencies

- **Contract:** T-A23-001 → T-A23-002 → T-A23-003 → T-A23-008.
- **Independent of the contract:** T-A23-004/005 and 006/007. The reference and the build run one after the other,
  because only one xcodebuild runs at a time.
- **Last:** the polish tasks.

## Parallel examples

- **Agent:** T-A23-002, the read-heavy contract audit (a separate file; the lead reviews and runs the checker).
- **Lead:** T-A23-001, the reference and build runs (004–007), the gap review (008), the proofs and the commits.

## Implementation strategy

- **MVP:** the contract (002, 003, 008) with the baseline (001, 004, 005).
- **Close:** the build proof (006, 007) and the evidence close the phase.
- **Review checkpoints:** after 003 (the checker passes) and at 008 (the decision).
- **Commits:** one per task.
