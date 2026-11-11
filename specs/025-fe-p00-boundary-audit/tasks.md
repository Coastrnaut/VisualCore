---

description: "Task list for feature 025 — Fractal Explorer Phase 00 boundary audit (ledger gate A03-P00)"
---

# Tasks: Fractal Explorer — Phase 00 boundary audit

**Input**: `/specs/025-fe-p00-boundary-audit/`.

**Tests** are required:
- the shared contract check;
- the shell smoke test on both simulators, enumeration-guarded;
- the reference regression.

**Conventions**:
- IDs are `T-A03-0##`, with one commit and push per task (`scripts/tick_task.py`).
- Commands run through `run-check --stage A03-P00`.
- Review checkpoint after each phase: `validate_docs.py` and `check_app_contract.py --app fractal-explorer` pass.

## Phase 1: Setup

- [X] T-A03-001 Create `docs/apps/fractal-explorer/regression-baseline.md` with the phase-start commit (the — Verified 2026-11-11: — Verified 2026-11-11: docs/apps/fractal-explorer/regression-baseline.md with phase-start commit 343d251 (git cat-file -t: commit) and reference pin d93edd1 (git -C External/projectm-ios rev-parse --short HEAD); validate_docs PASS
  `speckit-constitution` commit `343d251`, before any A03 file) and the reference pin `d93edd1`. This gives the
  no-change diff for `Packages/` and `External/` (FR-A03-007) its base.

## Phase 2: US1 — Evidence-backed integration matrix (P1) 🎯

- [X] T-A03-002 [US1] Write `docs/apps/fractal-explorer/visualcore-contract.json` (schema 1, app `fractal-explorer`, — Verified 2026-11-11: — Verified 2026-11-11: docs/apps/fractal-explorer/visualcore-contract.json (schema 1, gate A03-P00): 18 inventory areas (13 refreshed from A02 + full-screen passes/uniforms, shader precision and capabilities, palettes/color/animation, cameras and transforms, persistence and temporary files), every path exists; matrix M01-M10 (available: M01 fragment shaders, M04 animation, M05 palettes, M06 pinch/pan, M07 bookmarks, M09 capture/tours; requires adaptation: M02 transforms, M03 precision, M08 cost estimate, M10 precision clamp), public non-test evidence with products and an example consumer type on every row. run-check A03-P00/t002-contract-citations-2: 0 citation problems (the first run t002-contract-citations flagged example symbols not declared in their files, fixed to the consumer types); remaining findings are the gap entries and decision owned by T-A03-006
  gate A03-P00):
  - an `inventory` covering every area in FR-A03-001, each with paths;
  - `matrix` rows M01–M10 per research R1–R10:
    - five brainstorm rows: fragment shaders, coordinate transforms, precision, parameter animation, palettes;
    - five v0.1 rows: pinch/pan camera, bookmarks, iteration cap with cost estimate, capture and tours, precision
      clamping.

  Each row cites only public non-test symbols and has an example consumer. Upstream-gap and adaptation rows cite the
  closest existing consumer. Run `check_app_contract.py --app fractal-explorer`; citation problems must be 0
  (SC-A03-001, SC-A03-002). The checker renders the Markdown view only for a passing contract, so `--render` runs in
  T-A03-006 (analyze U1).

## Phase 3: US2 — Host, thread, build and regression baseline (P1)

- [X] T-A03-003 [US2] Run the 7-step reference regression in two `run-check` chunks (A03-P00). Record the steps, — Verified 2026-11-11: — Verified 2026-11-11: run-check A03-P00/t003-reference-a 3/3 (engine xcframework, projectM-iOS simulator build, reference clean at d93edd1) and t003-reference-b 4/4 (ANGLERendering 14/14 on iOS 27.2 and 26.5, ProjectMReference 17/17 on both) = 7/7; steps, commands and results recorded in docs/apps/fractal-explorer/regression-baseline.md (FR-A03-004, SC-A03-004)
  commands and results in `docs/apps/fractal-explorer/regression-baseline.md` (FR-A03-004, SC-A03-004).

## Phase 4: US3 — Compilable empty app shell (P1)

- [X] T-A03-004 [US3] Add the shell: — Verified 2026-11-11: — Verified 2026-11-11: Apps/FractalExplorer/App/FractalExplorerApp.swift (@main SwiftUI shell; HomeView with the title 'Fractal Explorer', header trait, accessibility label and identifier fe.home.title, container fe.home; no render host, permissions or networking; no promise copy); project.yml targets FractalExplorer (dev.visualcore.FractalExplorer, iOS 26.0, 0.1.0 (1), ITSAppUsesNonExemptEncryption false, no usage descriptions, no VisualCore product yet, dependency-audit post-build phase) and FractalExplorerUITests, scheme FractalExplorer; Info.plists under the gitignored Apps/*/Generated/. run-check A03-P00/t004-shell-build BUILD SUCCEEDED for generic iOS Simulator with the audit 'PASS: no ProjectM engine/preset/bridge dependency'; built Info.plist has the bundle id and 0 usage descriptions; t004-dependencies R1-R5 PASS (FR-A03-005, FR-A03-006)
  - `Apps/FractalExplorer/App/FractalExplorerApp.swift`: an @main SwiftUI app with `HomeView`, title "Fractal
    Explorer", identifier `fe.home.title`, accessibility label and header trait, container `fe.home`;
  - `project.yml` target `FractalExplorer`:
    - bundle `dev.visualcore.FractalExplorer`, iOS 26.0, version 0.1.0 (1);
    - `ITSAppUsesNonExemptEncryption` false;
    - the dependency-audit post-build script;
    - no VisualCore product yet and no usage descriptions;
  - `project.yml` target `FractalExplorerUITests`, plus the scheme. Info.plists are generated under the gitignored
    `Apps/FractalExplorer/Generated/`.

  Build for the generic iOS Simulator and run `check_dependencies.py` (FR-A03-005, FR-A03-006).
- [X] T-A03-005 [US3] Add `Apps/FractalExplorer/Tests/UI/LaunchSmokeUITests.swift`: launch, `fe.home.title` exists, — Verified 2026-11-11: — Verified 2026-11-11: Apps/FractalExplorer/Tests/UI/LaunchSmokeUITests.swift (launch, fe.home.title exists, label 'Fractal Explorer'). run-check A03-P00/t005-smoke-ios27 and t005-smoke-ios26 TEST SUCCEEDED, each confirmed by the enumeration guard (t005-smoke-*-guard PASS 1/1); the builds ran the dependency audit (SC-A03-003, FR-A03-006)
  label "Fractal Explorer". Run it on iOS 27.2 and 26.5, enumeration-guarded (SC-A03-003, FR-A03-006).

## Phase 5: US4 — Gap register and stop/go decision (P2)

- [X] T-A03-006 [US4] Complete the contract JSON: — Verified 2026-11-11: — Verified 2026-11-11: visualcore-contract.json completed: 5 gaps (G-VIEWPORT -> VisualCoreMath phase 1; G-FRACTAL app-local phase 1 with the A03 CPU-reference justification; G-PRECISION -> VisualCoreRendering query + VisualCoreMath advisor phase 2, simulator value context only; G-COST -> VisualCoreDiagnostics phase 3; G-TOUR -> VisualCoreMath phase 4), each with a test intent; traceability for the brainstorm, features 01-06 and journeys 1-3 to phases; 9 negative rules with sources; decision go with 5 reasons and 0 blockers. visualcore-contract.md rendered between the generated markers (first render t006-contract failed: the Markdown file with markers did not exist yet). run-check A03-P00/t006-contract-2 PASS: 10 rows, 32 citations, 5 gaps, decision go (FR-A03-008-011, SC-A03-005, SC-A03-007)
  - `gaps` for every non-available row, each with an owner module, a phase and a test:
    - G-VIEWPORT: VisualCoreMath, phase 1. Test: an anchored pinch keeps the touched plane point fixed within 1e-12
      relative, and an aspect change keeps the center.
    - G-FRACTAL: app-local, phase 1, with a CPU reference. Test: known interior and exterior points.
    - G-PRECISION: VisualCoreRendering query plus a VisualCoreMath advisor, phase 2. Test: the advisor's thresholds
      are derived from the mantissa bits, and a simulator query returns the reported `highp` precision. That simulator
      value is recorded as context only; device precision is measured in campaign II before any claim (constitution
      V; analyze C1).
    - G-COST: VisualCoreDiagnostics, phase 3. Test: the estimate is monotonic in pixels, iterations and samples.
    - G-TOUR: the viewport's log-zoom interpolation, phase 4.
  - `traceability` for v0.1 features 01–06 and journeys 1–3;
  - the `negative` rules (FR-A03-011);
  - the go/stop `decision` with reasons.

  Render it and run the check (FR-A03-008–011, SC-A03-005, SC-A03-007).

## Phase 6: Polish

- [X] T-A03-007 Confirm that `git diff --stat 343d251..HEAD -- Packages External` is empty (SC-A03-006). Run the — Verified 2026-11-11: — Verified 2026-11-11: run-check A03-P00/t007-no-shared-changes: git diff --stat 343d251..HEAD -- Packages External is empty (log holds only the command header; SC-A03-006); t007-release-fast 6/6 (docs, app-contracts incl. all three apps' contracts, compliance, dependencies R1-R5, licenses, script-tests); t007-documented-api PASS for Apps/FractalExplorer
  release-check fast steps (docs, app-contracts, compliance, dependencies, licenses, script-tests) and the
  documented-API check for `Apps/FractalExplorer`.

## Analyze remediation (2026-11-11, applied under CLAUDE.md §2)

- C1: simulator precision is context only.
- U1: rendering happens in T-A03-006.
- 0 critical issues.

## Dependencies

- T-A03-001 → T-A03-002 → T-A03-006.
- T-A03-003 is independent.
- T-A03-004 → T-A03-005.
- T-A03-007 runs last.

## Implementation strategy

The matrix first (US1), then the baseline, the shell and the decision, reusing the A01-P00 tooling unchanged.

## Phase 7: Convergence

- [X] T-A03-008 Correct the contract inventory's "Build" entry. `scripts/release_check.py` lists 47 steps today, not — Verified 2026-11-11: — Verified 2026-11-11: the inventory Build entry now gives release_check.py's 47 steps (release_check.py --list) by family (shared checks, per-app documented-API/isolation/host/app steps, release.json-driven release steps, reference regression); contract re-rendered; run-check A03-P00/t008-contract PASS 10 rows, 32 citations, 5 gaps, decision go
  30. Describe the step families instead: shared checks, per-app documented-API/isolation/host/app steps, the
  per-app release steps from `release.json`, and the reference regression. Then re-render the contract and run
  `check_app_contract.py --app fractal-explorer`. Covers FR-A03-001 (partial).
