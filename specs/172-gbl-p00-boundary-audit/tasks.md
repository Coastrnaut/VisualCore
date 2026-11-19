# Tasks: Graphics Benchmark Lab — Phase 00 Foundation and VisualCore boundary audit

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/contract.md](contracts/contract.md), [quickstart.md](quickstart.md). Gate A24-P00 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A24-P00 --timeout 595 --name <check> -- <command>`.
- **Commits:** one after every task, with no trailers.
- **Checks:** read every check's exit before ticking, never in the same command.
- **Scope:** no Swift, package or project change.
- **Precedent:** `specs/165-vpl-p00-boundary-audit/tasks.md`.
- **Rollback:** revert the commits (documents only).

## Phase 1: Setup

- [X] T-A24-001 Create the two starting documents: — Verified 2026-11-19: 2026-11-19: docs/apps/graphics-benchmark-lab/README.md (manual §1–§2, one-app rules, constitution 2.20.0) and regression-baseline.md (phase start 7de0f2af, constitution 6c0a7d35, pin d93edd1); validate_docs passes
  - `docs/apps/graphics-benchmark-lab/README.md`, from the manual §1–§2: a transparent, repeatable suite of GPU
    workloads (textured quads, shader ALU stress, particles) with warm-up, measurement and cool-down, percentile
    results with provenance and caveats; offline; no permission; no upload; an experience of the one app; its
    documents;
  - `docs/apps/graphics-benchmark-lab/regression-baseline.md`, with the phase start `7de0f2af` (the specify commit;
    constitution 2.20.0 at `6c0a7d35`) and the reference pin `d93edd1`

## Phase 3: User Story 1 — Evidence-backed integration matrix (P1) 🎯

- [X] T-A24-002 [US1] Write `docs/apps/graphics-benchmark-lab/visualcore-contract.json` (schema 1; app — Verified 2026-11-19: 2026-11-19: docs/apps/graphics-benchmark-lab/visualcore-contract.json: 11 inventory areas, 38 rows (12 available, 23 requires adaptation, 3 upstream gap), 166 citations, 11 traceability entries
  `graphics-benchmark-lab`; gate `A24-P00`), with:
  - an `inventory` of every FR-A24-001 area, with paths and the release-check line count (from `python3
    scripts/release_check.py --list`);
  - `matrix` rows covering the 5 brainstorm capabilities (GPU timing, diagnostics, profiling, benchmark scenes,
    device and configuration reporting) and the 6 version 0.1 features (baseline scenes; warm-up, measurement and
    cool-down; frame-time percentiles, CPU submit time and optional GPU timer; device and context report; JSON or CSV
    export; explanation of limits) (research D3);
  - rows for the twelve FR-A24-003 areas and cross-cutting rows: context loss, resize and orientation, quality tiers,
    accessibility, bounded resources, permissions, the render thread, and truthful claims;
  - on every row, evidence as "a public declaration in a VisualCore framework product with at least one test", with
    the facts of the clarification session (`FrameInfo`, `PacingMeter`, `PerformanceRecord`, `DeviceConditions`,
    `FramePacing`, `RenderCapabilities`, `RendererRecord`, `RenderContext`, `FullScreenShaderScene`, `FieldPass`,
    `ParticleRenderer`, `ParticleSystem`, `Texture`, `ExperienceStorage`, `MigrationChain`; no timer query; the
    internal `CVisualCoreGL` shim);
  - a `traceability` entry per capability and feature
  (FR-A24-001, FR-A24-002)
- [X] T-A24-003 [US1] Write the generated-block markers into `docs/apps/graphics-benchmark-lab/visualcore-contract.md` — Verified 2026-11-19: 2026-11-19: .autonomy/checks/A24-P00.contract.json exit 0 (PASS: 38 rows, 166 citations, 12 gaps, decision go); visualcore-contract.md rendered
  before the first render, then run the contract checker and render the view (`--name contract -- python3
  scripts/check_app_contract.py --app graphics-benchmark-lab --render`) (FR-A24-007, SC-A24-001)

## Phase 4: User Story 2 — The reference stays proven (P1)

- [X] T-A24-004 [US2] Reference chunk 1 (`--name reference-1 -- python3 scripts/release_check.py --only — Verified 2026-11-19: 2026-11-19: .autonomy/checks/A24-P00.reference-1.json exit 0 (reference-engine-xcframework, reference-build-projectm-ios-sim, reference-clean)
  reference-engine-xcframework reference-build-projectm-ios-sim reference-clean`)
- [X] T-A24-005 [US2] Reference chunk 2 (`--name reference-2 -- python3 scripts/release_check.py --only — Verified 2026-11-19: 2026-11-19: .autonomy/checks/A24-P00.reference-2.json exit 0; regression-baseline.md records 7 of 7 steps pass
  reference-test-anglerendering-ios27 reference-test-anglerendering-ios26 projectm-reference-ios27
  projectm-reference-ios26`); record the 7 steps, commands and results in
  `docs/apps/graphics-benchmark-lab/regression-baseline.md` (FR-A24-004, SC-A24-003)

## Phase 5: User Story 3 — The shell builds with the experience absent (P2)

- [X] T-A24-006 [US3] Build the one app for testing (`--name app-build -- python3 scripts/release_check.py --only — Verified 2026-11-19: 2026-11-19: .autonomy/checks/A24-P00.app-build.json exit 0 (build for testing on the iOS 27.2 phone simulator)
  app-build-for-testing-ios27`)
- [X] T-A24-007 [US3] Experience package check: — Verified 2026-11-19: 2026-11-19: .autonomy/checks/A24-P00.experience-packages.json exit 0 (23 experiences, none A24); grep -c a24 gives 0 and 0
  - `--name experience-packages -- python3 scripts/check_experience_packages.py` passes (23 experiences, none A24);
  - `grep -c a24 Catalog/registrations.json Apps/VisualCore/App/ExperienceRegistry.swift` gives 0 and 0 (the colour
    `#050A24` is matched case-sensitively as `0A24`, not `a24`)
  (FR-A24-005, SC-A24-004)

## Phase 6: User Story 4 — Stop/go decision (P2)

- [X] T-A24-008 [US4] Complete the contract, then rerun the checker (`--name contract-2`): — Verified 2026-11-19: 2026-11-19: 12 gaps (G-MODEL, G-STATS P1; G-SCENES P2; G-RUNNER, G-REPORT, U-RENDERINFO, U-GPUTIMER P3; G-RESULTS, G-EXPORT P4; G-DEVICE, G-EXPLAIN P5; G-RELEASE P6), 14 negative entries with the three manual risks, decision go with no blockers; .autonomy/checks/A24-P00.contract-2.json exit 0
  - **`gaps`:** for every non-available row, the owning module and the phase per research D4: G-MODEL, G-STATS
    (A24-P01); G-SCENES (A24-P02); G-RUNNER, G-REPORT (A24-P03), plus the upstream gaps U-RENDERINFO and U-GPUTIMER
    (VisualCore, A24-P03, per clarifications Q1 and Q2); G-RESULTS, G-EXPORT (A24-P04); G-DEVICE, G-EXPLAIN
    (A24-P05); G-RELEASE (A24-P06).
  - **Risks:** the three manual risks (thermal and refresh skew, GPU timer availability, overheating from stress runs)
    as `negative` entries naming the owner, verification method and release-blocker condition (source "manual §13
    risk N"); plus the FR-A24-006 negative rules.
  - **`decision`:** keys `result`, `reasons`, `blockers`. It is "stop" (US4 scenario 2) if a bounded workload cannot
    be drawn in the host's context or a monotonic frame time cannot be read over the existing renderer; a missing
    host never permits a second backend.
  (FR-A24-003, FR-A24-006, SC-A24-002)

## Phase 7: Polish and evidence

- [X] T-A24-009 No-change proof (`--name no-change -- git diff --exit-code --stat 7de0f2af..HEAD -- Packages — Verified 2026-11-19: 2026-11-19: .autonomy/checks/A24-P00.no-change.json and no-change-2.json exit 0 (empty diff of Packages and External since 7de0f2af)
  External`) (FR-A24-008, SC-A24-005)
- [X] T-A24-010 Run the script tests (`--name script-tests -- python3 scripts/test_scripts.py`) and the release-check — Verified 2026-11-19: 2026-11-19: .autonomy/checks/A24-P00.script-tests.json and fast-checks.json exit 0; the contract check runs in about 0.05 s
  document steps (`--name fast-checks -- python3 scripts/release_check.py --only docs app-contracts compliance
  dependencies`). Every run-check of this gate stays within its limit, and the contract check runs in under 10 s
  (SC-A24-006)
- [ ] T-A24-011 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record
  A24-P00. Update README.md (status, gate count) in the record commit (rule 16), and `docs/automatedtesting.md` if a
  test tool, rule or lesson changed (rule 17)

## Dependencies

- **Contract:** T-A24-001 → T-A24-002 → T-A24-003 → T-A24-008.
- **Independent of the contract:** T-A24-004/005 and 006/007. The reference and the build run one after the other,
  because only one xcodebuild runs at a time.
- **Last:** the polish tasks.

## Parallel examples

- **Agent:** T-A24-002, the read-heavy contract audit (a separate file; the lead reviews and runs the checker).
- **Lead:** T-A24-001, the reference and build runs (004–007), the gap review (008), the proofs and the commits.

## Implementation strategy

- **MVP:** the contract (002, 003, 008) with the baseline (001, 004, 005).
- **Close:** the build proof (006, 007) and the evidence close the phase.
- **Review checkpoints:** after 003 (the checker passes) and at 008 (the decision).
- **Commits:** one per task.
