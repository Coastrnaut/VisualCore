---

description: "Task list for feature 002 — Phase 1 architecture contracts (ledger gate F01 rework)"
---

# Tasks: Phase 1 — Architecture Constitution and Integration Contracts

**Input**: Design documents from `/specs/002-architecture-contracts/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/ (4), quickstart.md

**Tests**: SC-F102 requires seeded-violation tests for the dependency checker; included.

**Organization**: By user story. IDs `T-F1##` (ADR-0004). Tick only with `— Verified YYYY-MM-DD: <command/result>`. Checks run via `desktop_runbook.py run-check` (current gate F02, prefix `f01rework-`).

## Format: `[ID] [P?] [Story] Description`

## Phase 1: Setup

- [X] T-F101 Fix `docs/architecture/visualcore-architecture.md` links (they point at the retired `specs/001-visualcore-foundation`) to features 001/002 and the contracts — Verified 2026-11-10: visualcore-architecture.md now links features 001/002 and the four contracts (validate_docs PASS)

## Phase 2: Foundational

- [X] T-F102 Add seeded-violation tests (ProjectM import in `Apps/`, product cycle, `Packages/` importing an app module, TestSupport in a non-test target, UIKit import in a pure module) to `scripts/test_scripts.py` (written first, failing until T-F103) — Verified 2026-11-10: 7 DependencyCheckerTests written first (skipped before T-F103), now pass: test_scripts 20 tests OK (F02.f01rework-script-tests)

## Phase 3: User Story 1 — Enforceable ownership and direction (P1) 🎯 MVP

- [X] T-F103 [US1] (FR-F102, FR-F112) Create `scripts/check_dependencies.py` enforcing R1–R5 of `contracts/package-map.md` over `Packages/*/Package.swift`, root `*.yml`, `Harnesses/*.yml` and Swift/C/ObjC sources; exit 1 with `rule, path, line, detail`; module names are matched whole (reference `Diagnostics` ≠ `VisualCoreDiagnostics`) — Verified 2026-11-10: check_dependencies.py PASS on repo (F02.f01rework-dependencies); seeded R1-R5 violations rejected
- [X] T-F104 [US1] (FR-F101, FR-F115) Scaffold `Packages/VisualCore/Package.swift` (platforms iOS 26.0 + macOS 15.0; products/targets VisualCoreMath, VisualCoreSimulation, VisualCoreScenes, VisualCoreShaderSource, VisualCoreEffectsGraph, VisualCoreDiagnostics, VisualCoreAudioDSP, VisualCorePersistence, VisualCoreTestSupport; version comment 0.1.0) with one placeholder-free `Module.swift` per target declaring `public enum <Module>Info { public static let version = "0.1.0" }` — Verified 2026-11-10: swift test --package-path Packages/VisualCore: 1 test passed (F02.f01rework-pure-swift-test); describe exit 0
- [X] T-F105 [US1] (FR-F101) Scaffold `Packages/VisualCoreRendering/Package.swift` (iOS 26.0; binary targets libEGL/libGLESv2 from `../../External/projectm-ios/Build/ANGLEFrameworks`; targets CVisualCoreEGL, CVisualCoreGL (existing generated table), VisualCoreRendering, VisualCoreEffects, VisualCoreUI, VisualCoreAudio, VisualCoreAutomation) with version modules — Verified 2026-11-10: xcodebuild VisualCoreRendering-Package generic sim + generic iOS BUILD SUCCEEDED (F02.f01rework-rendering-scaffold-*-attempt2; attempt 1 exit 127 = zsh word-splitting, kept)
- [X] T-F106 [US1] (FR-F113) Correct ADR-0003 to point at `contracts/package-map.md` as the authoritative map and list the R1–R5 rules — Verified 2026-11-10: ADR-0003 correction section names package-map.md and R1-R5

## Phase 4: User Story 2 — Lifecycle, threading, resources (P1)

- [X] T-F107 [US2] (FR-F104, FR-F114, FR-F113) Correct ADR-0002 to reference `contracts/render-lifecycle.md` (reconciliation table, intentional recreation addition) — Verified 2026-11-10: ADR-0002 correction section references render-lifecycle.md reconciliation
- [X] T-F108 [US2] (FR-F105) Confirm `contracts/resources-shaders-errors.md` defines budgets, counters, stale rejection and the U-F002/U-F003 handling (doc review recorded in task note) — Verified 2026-11-10: resources-shaders-errors.md §GPU resources: budgets, counters, stale rejection, U-F002/U-F003 handling reviewed

## Phase 5: User Story 3 — Shader, diagnostics, error, logging (P2)

- [X] T-F109 [US3] (FR-F106, FR-F107) Confirm error categories and diagnostics fields with units in `contracts/resources-shaders-errors.md` (doc review) — Verified 2026-11-10: resources-shaders-errors.md error table (7 categories) and DiagnosticsSnapshot fields with units reviewed

## Phase 6: User Story 4 — Adapter, submodule, regression (P2)

- [X] T-F110 [US4] (FR-F108–FR-F111) Confirm `contracts/tests-adapter-submodule-regression.md` defines the test-boundaries table (host/sim/generic/device) and names exact baseline commands; add `regression` section to `docs/architecture/visualcore-architecture.md` — Verified 2026-11-10: tests-adapter-submodule-regression.md has test-boundaries table and exact baseline commands; regression section added to architecture doc

## Phase 7: User Story 5 — Second-app usability (P3)

- [X] T-F111 [US5] (FR-F103) Run `scripts/check_dependencies.py`; confirm no ProjectM module in either package manifest's dependency closure (`swift package describe`) — Verified 2026-11-10: check_dependencies R1 PASS; neither Package.swift references projectm-ios/Packages or ProjectM.xcframework

## Phase 8: Polish

- [X] T-F112 Run `validate_docs.py`, `check_compliance.py`, `check_dependencies.py`, `test_scripts.py`, `swift package describe` on both packages through run-check — Verified 2026-11-10: run-check f01rework-{validate-docs,compliance,dependencies,script-tests,describe-pure,describe-rendering} exit 0
- [X] T-F113 (SC-F105) Append F01 rework addendum to `docs/architecture/visualcore-architecture.md` (ADR-0004), including an ownership-ambiguity review table (each reference package → owner, VisualCore counterpart or "none") — Verified 2026-11-10: architecture doc addendum with ownership-ambiguity table (7 rows, zero shared owners)

## Dependencies & Execution Order

Setup → T-F102 (tests first) → US1 (T-F103 makes T-F102 pass; T-F104/T-F105 scaffolds) → US2–US5 (docs, parallel) → Polish.

## Parallel Examples

T-F104 ∥ T-F105 (different packages); T-F107 ∥ T-F108 ∥ T-F109 ∥ T-F110.

## Implementation Strategy

MVP = US1 (enforced boundaries + scaffolds). No renderer code is migrated (archived Phase 1 implement prompt).

## Phase 9: Convergence

- [X] T-F114 Add `Packages/VisualCore/README.md` and `Packages/VisualCoreRendering/README.md` (purpose, products, rules R1-R5, test commands) per Constitution v1.1.0 documentation standard (partial) — Verified 2026-11-10: both package READMEs present with products, R2 imports and test commands
- [X] T-F115 Reconcile R2 in `contracts/package-map.md` with `scripts/check_dependencies.py`: allow `simd` and `Accelerate` (system math available on host and iOS) with rationale per contracts: package-map R2 (contradicts) — Verified 2026-11-10: package-map R2 lists exactly PURE_ALLOWED_SYSTEM of check_dependencies.py (Foundation, Dispatch, os, Darwin, Glibc, _Concurrency, Synchronization, simd, Accelerate; tests XCTest/Testing)
- [X] T-F116 Record `scripts/xcodebuild_package.py` as the sanctioned package build/test wrapper in `contracts/tests-adapter-submodule-regression.md` per plan: project structure (unrequested) — Verified 2026-11-10: contract test-boundaries section names the wrapper and its guarantees

## Phase 10: Convergence

- [X] T-F117 Align DependencyViolation in `specs/002-architecture-contracts/data-model.md` with checker output (`path` is `file` or `file:line`) per plan: data-model (contradicts) — Verified 2026-11-10: data-model.md matches check_dependencies.py output format
