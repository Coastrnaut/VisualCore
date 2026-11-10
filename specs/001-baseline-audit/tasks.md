---

description: "Task list for feature 001 — Phase 0 baseline audit (ledger gate F00 rework)"
---

# Tasks: Phase 0 — Repository Integration and Baseline Audit

**Input**: Design documents from `/specs/001-baseline-audit/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/audit-outputs.md, quickstart.md

**Tests**: The spec makes audit outputs mechanically checkable (SC-F001, SC-F002, SC-F005), so script unit tests are included.

**Organization**: Tasks are grouped by user story. Task IDs use the feature namespace `T-F0##` (ADR-0004). A task is ticked only with `— Verified YYYY-MM-DD: <command/result>`. Every command runs through `python3 Tools/python/desktop_runbook.py run-check`.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: US1–US4 from spec.md

## Phase 1: Setup

- [X] T-F001 Confirm toolchain pins with `scripts/verify_environment.py` (reuse; no new script) — Verified 2026-11-10: run-check F02.f00rework-env exit 0 (all pins ok)
- [X] T-F002 [P] Create `scripts/check_reference_clean.py`: exit 1 listing tracked changes in `External/projectm-ios` (`git status --porcelain --ignore-submodules=untracked`) and in each nested submodule — Verified 2026-11-10: scripts/check_reference_clean.py PASS; checks F02.f00rework-clean-before/-after/-after-attempt2 exit 0

## Phase 2: Foundational

- [X] T-F003 Extend `scripts/test_scripts.py` with unit tests for `check_reference_clean.py` (clean vs modified temp git repo) and for the citation parser in T-F010 — Verified 2026-11-10: python3 scripts/test_scripts.py 13 tests OK (F02.f00rework-script-tests)

## Phase 3: User Story 1 — Verified reference pin and inventory (P1) 🎯 MVP

**Goal**: pins and a complete cited inventory. **Independent test**: rerun inventory; every path exists and pins match `git submodule status`.

- [X] T-F004 [US1] (FR-F001) Rerun `scripts/audit_projectm_reference.py` (existing) and confirm pins, forks (`Coastrnaut/*`, branch `ios`) and ANGLE build commit; output `docs/architecture/projectm-reference-audit.json` — Verified 2026-11-10: F02.f00rework-projectm-audit exit 0 (forks Coastrnaut/ios, ANGLE build commit == pin)
- [X] T-F005 [US1] (FR-F003) Create `scripts/inventory_reference.py` producing `docs/architecture/reference-inventory.json` with rows `{path, kind, role, detail}`; kind ∈ "package/app/xcodegen-spec/script/test-target/ci-workflow/dependency/license"; role ∈ "projectm-specific/reusable-candidate/tooling/content"; covers packages (manifest products, targets, deps), apps, XcodeGen specs and schemes, scripts, test targets with test-file counts, `.github/workflows/*`, submodules incl. preset packs (kind dependency, role content), licenses — Verified 2026-11-10: F02.f00rework-inventory exit 0; 8 packages, 3 apps, 0 unclassified
- [X] T-F006 [US1] Write `docs/architecture/repository-audit.md` from the inventory JSON with the pin table and a citation for every row — Verified 2026-11-10: docs/architecture/repository-audit.md generated from inventory JSON

## Phase 4: User Story 2 — Traced rendering pipeline (P1)

**Goal**: cited trace. **Independent test**: `inventory_reference.py --check-citations` resolves 100%.

- [X] T-F007 [US2] Read the reference sources for startup → renderer: `Apps/projectM-iOS/ProjectMApp.swift`, `Apps/projectM-iOS/Coordinators/*`, `Packages/ANGLERendering/Sources/ANGLERendering/*.swift`, `Packages/ANGLERendering/Sources/CANGLE/*`, `Packages/Rendering/Sources/**`, `Packages/ProjectMBridge/Sources/**` — Verified 2026-11-10: sources read; every symbol cited resolves (T-F010)
- [X] T-F008 [US2] (FR-F004, FR-F005) Write `docs/architecture/current-rendering-pipeline.md`: startup, EGL display/config/context/surfaces, GL entry resolution, Metal backend args (ANGLE.json), presentation, display link scheduling, threading (main thread + prewarmer context), synchronization, resize/orientation, thermal/low-power, teardown, recreation; citations as ``ref:`path`#`symbol` ``; unknowns labelled with follow-up IDs — Verified 2026-11-10: current-rendering-pipeline.md; unknowns U-F001..U-F003 with owners
- [X] T-F009 [US2] (FR-F006) Add a resource section (shaders, textures, framebuffers, flash-limiter FBO, prewarm BGRA FBO) with ownership and cleanup citations to `current-rendering-pipeline.md` — Verified 2026-11-10: resource table §8 with citations
- [X] T-F010 [US2] Implement `--check-citations DOC` in `scripts/inventory_reference.py` (path exists in reference; symbol text appears in file) and run it on the trace — Verified 2026-11-10: F02.f00rework-citations exit 0: 48 citations, 0 unresolved

## Phase 5: User Story 3 — Reusable-component inventory and gap analysis (P2)

- [X] T-F011 [P] [US3] (FR-F007) Write `docs/architecture/reusable-component-inventory.md`: every reference package and app classified with reason and citation (8 packages, 3 apps) — Verified 2026-11-10: reusable-component-inventory.md (8 packages + 3 apps classified)
- [X] T-F012 [P] [US3] (FR-F007) Write `docs/architecture/visualcore-gap-analysis.md`: capabilities VisualCore needs that the reference lacks (lifecycle state machine, generations, resource registry, effect graph, input/scenes, app-neutral audio features, automation runner), each mapped to F02–F09 — Verified 2026-11-10: visualcore-gap-analysis.md (13 gaps mapped to F02-F09)

## Phase 6: User Story 4 — Reproducible baseline build and smoke test (P2)

**Goal**: unmodified reference builds and its renderer tests pass on simulators. **Independent test**: rerun steps; logs match report.

- [X] T-F013 [US4] (FR-F008, FR-F009) Create `scripts/run_reference_baseline.py` with `--list` and `--step NAME` for steps `engine-xcframework`, `xcodegen-main`, `xcodegen-rendererlab`, `build-projectm-ios-sim`, `build-capturelab-sim`, `build-rendererlab-sim`, `build-projectm-ios-generic`, `test-anglerendering-ios27`, `test-anglerendering-ios26`; simulator chosen by runtime; DerivedData `Build/DerivedData/reference`; result bundles `.autonomy/xcresults/`; `CODE_SIGNING_ALLOWED=NO`; refuses any destination other than `generic/platform=iOS`, `generic/platform=iOS Simulator` or a simulator UDID, and never invokes `devicectl` — Verified 2026-11-10: scripts/run_reference_baseline.py --list; BaselineDestinationTests OK
- [X] T-F014 [US4] (FR-F002, FR-F010) Confirm preset submodules are initialized (`git -C External/projectm-ios submodule status`), run `check_reference_clean.py`, then each baseline step via `run-check`, then `check_reference_clean.py` again — Verified 2026-11-10: 10 baseline steps exit 0 (rendererlab attempt 1 exit 65 kept, attempt 2 exit 0); clean before/after
- [X] T-F015 [US4] Write `docs/verification/projectm-baseline.md`: commit, toolchain, step table (command, exit, log, sha256), xcresult summaries via `xcrun xcresulttool get test-results summary`, blocked items with observed errors — Verified 2026-11-10: docs/verification/projectm-baseline.md; xcresulttool Passed 13/13 on iOS 27.2 and 26.5

## Phase 7: Polish & Cross-Cutting

- [X] T-F016 Run `scripts/validate_docs.py`, `scripts/check_compliance.py`, `scripts/test_scripts.py` — Verified 2026-11-10: F02.f00rework-validate-docs, -compliance, -script-tests exit 0
- [X] T-F017 Append the F00 rework addendum to `docs/architecture/F00-reference-audit.md` linking the new documents and ADR-0004 — Verified 2026-11-10: F00-reference-audit.md §8 addendum
- [X] T-F018 [P] Read-only device inventory rerun `scripts/inventory_devices.py` (no install/launch/test) {device-inventory-only} — Verified 2026-11-10: F02.f00rework-device-inventory exit 0 (read-only devicectl list; no install/launch/test)

## Dependencies & Execution Order

- Setup (T-F001–T-F002) → Foundational (T-F003) → US1 (T-F004–T-F006) → US2 (T-F007–T-F010) → US3 (T-F011–T-F012, needs US1+US2) → US4 (T-F013–T-F015, independent of US2/US3; needs T-F002) → Polish.
- US4 can run while US2/US3 documents are written; only one Xcode lane at a time.

## Parallel Examples

- US3: T-F011 and T-F012 are different files.
- Setup: T-F002 alongside T-F001.

## Implementation Strategy

MVP = US1 (pins and inventory). Then US2 trace, US4 baseline (the archived exit gate "ProjectM builds at the pinned commit"), US3 classification. Stop and record `blocked` on any baseline failure; never weaken the step list.
