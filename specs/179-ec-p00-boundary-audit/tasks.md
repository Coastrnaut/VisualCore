# Tasks: Effects Composer — Phase 00 Foundation and VisualCore boundary audit

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/contract.md](contracts/contract.md), [quickstart.md](quickstart.md). Gate A25-P00 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A25-P00 --timeout 595 --name <check> -- <command>`.
- **Commits:** one after every task, with no trailers.
- **Checks:** read every check's exit before ticking, never in the same command.
- **Scope:** no Swift, package or project change.
- **Precedent:** `specs/172-gbl-p00-boundary-audit/tasks.md`.
- **Rollback:** revert the commits (documents only).

## Phase 1: Setup

- [X] T-A25-001 Create the two starting documents: — Verified 2026-11-19: 2026-11-19 docs/apps/effects-composer/README.md (manual §1–§2, one-app rules, constitution 2.21.0) and regression-baseline.md (phase start a2d68e21, constitution eec911ea, pin d93edd1); validate_docs passes
  - `docs/apps/effects-composer/README.md`, from the manual §1–§2: a visual effects-chain editor for building,
    previewing and exporting reusable shader looks (a linear chain of five built-in effects, reorder, enable and
    disable, before and after compare, presets, image import through the system picker, still export); offline; no
    upload; an experience of the one app; its documents;
  - `docs/apps/effects-composer/regression-baseline.md`, with the phase start `a2d68e21` (the specify commit;
    constitution 2.21.0 at `eec911ea`) and the reference pin `d93edd1`

## Phase 3: User Story 1 — Evidence-backed integration matrix (P1) 🎯

- [ ] T-A25-002 [US1] Write `docs/apps/effects-composer/visualcore-contract.json` (schema 1; app
  `effects-composer`; gate `A25-P00`), with:
  - an `inventory` of every FR-A25-001 area, with paths and the release-check line count (from `python3
    scripts/release_check.py --list`);
  - `matrix` rows covering the 6 brainstorm capabilities (render graph, framebuffer pipelines, shader library,
    effect parameters, preset serialization, offscreen rendering and export) and the 6 version 0.1 features (linear
    chain with five effects; reorder, enable and preview; compare and presets; image import; still export; target
    pooling and compile diagnostics) (research D3);
  - rows for the FR-A25-003 areas and cross-cutting rows: context loss, resize and orientation, quality tiers,
    accessibility, bounded resources, permissions, the render thread, and truthful claims;
  - on every row, evidence as "a public declaration in a VisualCore framework product with at least one test", with
    the facts of the clarification session (`FieldPass`, `FieldUniform`, `ResourceRegistry`, `PingPongTarget`,
    `FloatRenderSupport`, `EffectGraphDescription`, `EffectRenderer`, `ShaderLibrary`, `InfoLogParser`,
    `ParameterDefinition`, `ExperienceStorage`, `MigrationChain`, `RenderTarget`, `StillImageEncoder`,
    `ExportGeometry`, `RenderCapabilities`; no byte upload into a target, no image decoding, no picker);
  - a `traceability` entry per capability and feature
  (FR-A25-001, FR-A25-002)
- [ ] T-A25-003 [US1] Write the generated-block markers into `docs/apps/effects-composer/visualcore-contract.md`
  before the first render, then run the contract checker and render the view (`--name contract -- python3
  scripts/check_app_contract.py --app effects-composer --render`) (FR-A25-007, SC-A25-001)

## Phase 4: User Story 2 — The reference stays proven (P1)

- [ ] T-A25-004 [US2] Reference chunk 1 (`--name reference-1 -- python3 scripts/release_check.py --only
  reference-engine-xcframework reference-build-projectm-ios-sim reference-clean`)
- [ ] T-A25-005 [US2] Reference chunk 2 (`--name reference-2 -- python3 scripts/release_check.py --only
  reference-test-anglerendering-ios27 reference-test-anglerendering-ios26 projectm-reference-ios27
  projectm-reference-ios26`); record the 7 steps, commands and results in
  `docs/apps/effects-composer/regression-baseline.md` (FR-A25-004, SC-A25-003)

## Phase 5: User Story 3 — The shell builds with the experience absent (P2)

- [ ] T-A25-006 [US3] Build the one app for testing (`--name app-build -- python3 scripts/release_check.py --only
  app-build-for-testing-ios27`)
- [ ] T-A25-007 [US3] Experience package check:
  - `--name experience-packages -- python3 scripts/check_experience_packages.py` passes (24 experiences, none A25);
  - `grep -c a25 Catalog/registrations.json Apps/VisualCore/App/ExperienceRegistry.swift` gives 0 and 0
  (FR-A25-005, SC-A25-004)

## Phase 6: User Story 4 — Stop/go decision (P2)

- [ ] T-A25-008 [US4] Complete the contract, then rerun the checker (`--name contract-2`):
  - **`gaps`:** for every non-available row, the owning module and the phase per research D4: G-MODEL, G-EFFECTS
    (A25-P01); G-COMPILER, G-POOL, G-DIAG (A25-P02); G-EDIT, G-COMPARE, G-IMPORT (A25-P03), plus the upstream gap
    U-RGBAUPLOAD (VisualCore, A25-P03, per clarification Q2); G-PRESETS, G-EXPORT (A25-P04); G-COLOR, G-ROBUST
    (A25-P05); G-RELEASE (A25-P06).
  - **Risks:** the three manual risks (colour-space mistakes, images above the texture limit, unbounded intermediate
    targets) as `negative` entries naming the owner, verification method and release-blocker condition (source
    "manual §13 risk N"); plus the FR-A25-006 negative rules.
  - **`decision`:** keys `result`, `reasons`, `blockers`. It is "stop" (US4 scenario 2) if a full-screen pass sampling
    a texture into an offscreen target cannot be drawn in the host's context over the existing renderer; a missing
    host never permits a second backend.
  - **G-ROBUST** (A25-P05) owns memory limits, oversized sources and the device plan, after the risks above.
  (FR-A25-003, FR-A25-006, SC-A25-002)

## Phase 7: Polish and evidence

- [ ] T-A25-009 No-change proof (`--name no-change -- git diff --exit-code --stat a2d68e21..HEAD -- Packages
  External`) (FR-A25-008, SC-A25-005)
- [ ] T-A25-010 Run the script tests (`--name script-tests -- python3 scripts/test_scripts.py`) and the release-check
  document steps (`--name fast-checks -- python3 scripts/release_check.py --only docs app-contracts compliance
  dependencies`). Every run-check of this gate stays within its limit, and the contract check runs in under 10 s
  (SC-A25-006)
- [ ] T-A25-011 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record
  A25-P00. Update README.md (status, gate count) in the record commit (rule 16), and `docs/automatedtesting.md` if a
  test tool, rule or lesson changed (rule 17)

## Dependencies

- **Contract:** T-A25-001 → T-A25-002 → T-A25-003 → T-A25-008.
- **Independent of the contract:** T-A25-004/005 and 006/007. The reference and the build run one after the other,
  because only one xcodebuild runs at a time.
- **Last:** the polish tasks.

## Parallel examples

- **Agent:** T-A25-002, the read-heavy contract audit (a separate file; the lead reviews and runs the checker).
- **Lead:** T-A25-001, the reference and build runs (004–007), the gap review (008), the proofs and the commits.

## Implementation strategy

- **MVP:** the contract (002, 003, 008) with the baseline (001, 004, 005).
- **Close:** the build proof (006, 007) and the evidence close the phase.
- **Review checkpoints:** after 003 (the checker passes) and at 008 (the decision).
- **Commits:** one per task.
