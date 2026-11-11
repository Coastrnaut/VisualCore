---

description: "Task list for feature 011 — Generative Art Studio Phase 00 boundary audit (ledger gate A01-P00)"
---

# Tasks: Generative Art Studio — Phase 00 boundary audit

**Input**: `/specs/011-gas-p00-boundary-audit/`. **Tests** are required: checker script tests, the shell smoke test on
both simulators and the reference regression. IDs are `T-A01-0##`. Each task gets one commit and push via
`scripts/tick_task.py`. Review checkpoint: after each phase, `validate_docs.py` and `check_app_contract.py` pass.

## Phase 1: Setup

- [ ] T-A01-001 Record the phase-start commit in `docs/apps/generative-art-studio/regression-baseline.md` (header only), so the no-change diff check for `Packages/` and `External/` (FR-A01-007) has a base

## Phase 2: Foundational — app-neutral contract checker (blocks US1 and US4)

- [ ] T-A01-002 [P] Create checker fixtures `scripts/fixtures/app_contract/good/` and `scripts/fixtures/app_contract/bad/`. Each holds a mini repository (`Packages/X/Package.swift` with a `.library` product, a source file with public and internal declarations, and `docs/apps/demo/visualcore-contract.{json,md}`). The bad fixture contains:
  - a missing file;
  - a missing symbol;
  - a non-public evidence item for `public: true`;
  - an unknown product;
  - evidence in a test file;
  - evidence under `External/` (ProjectM only);
  - an `upstream gap` row with neither evidence nor notes;
  - a non-`available` row with no gap;
  - an app-local gap without justification;
  - a `go` decision with blockers.
- [ ] T-A01-003 Implement `scripts/check_app_contract.py` per `contracts/app-contract.md` and `data-model.md` (schema 1):
  - enumerations `status` ∈ {available, requires adaptation, upstream gap} and `kind` ∈ {adaptation, upstream};
  - ≤ 200 rows per list and strings ≤ 2,000 chars; unknown keys rejected;
  - declaration regex, with `public` required when `"public": true`, and `Type.member` checks;
  - products parsed from `Packages/*/Package.swift`;
  - evidence rejected under `Tests/`, `External/` and `Harnesses/` (examples allowed there);
  - `upstream gap` rows need evidence or notes;
  - `--render` writes the block between the `<!-- BEGIN GENERATED -->`/`<!-- END GENERATED -->` markers;
  - exit codes 0, 1 and 2.

  Add `AppContractTests` to `scripts/test_scripts.py`: the good fixture passes, and each bad case is reported by row
  id; `--render` is idempotent.

## Phase 3: US1 — Evidence-backed integration matrix (P1) 🎯

- [ ] T-A01-004 [US1] Write `docs/apps/generative-art-studio/visualcore-contract.json` with the inventory (FR-A01-001: products and modules, `RenderHost` entry point and main-thread rule, context loss, `ResourceRegistry` budgets, `ShaderLibrary` and `ResourceRegistry.program`, effect graph, XcodeGen specs and schemes, scripts, ownership) and the 10 matrix rows M01–M10 (research R4) with real file, symbol and product evidence and an example consumer each. Create `docs/apps/generative-art-studio/visualcore-contract.md` with the generated-block markers and render it.
- [ ] T-A01-005 [US1] Run `python3 scripts/check_app_contract.py --app generative-art-studio` under `run-check` (SC-A01-001 0 unresolved, SC-A01-002 10/10 rows).

## Phase 4: US2 — Host, thread, build and regression baseline (P1)

- [ ] T-A01-006 [US2] Run the baseline regression under `run-check` stage A01-P00:
  - `release_check.py --only reference-engine-xcframework reference-build-projectm-ios-sim reference-test-anglerendering-ios27 reference-test-anglerendering-ios26 reference-clean projectm-reference-ios27 projectm-reference-ios26`.

  Record the commands, results and check names in `docs/apps/generative-art-studio/regression-baseline.md`
  (FR-A01-004, SC-A01-004).

## Phase 5: US3 — Compilable empty app shell (P1)

- [ ] T-A01-007 [US3] Add the targets `GenerativeArtStudio` (application; sources `Apps/GenerativeArtStudio/App`; bundle `dev.visualcore.GenerativeArtStudio`; display name "Generative Art Studio"; version 0.1.0; no permissions, no usage descriptions; post-build `audit_showcase_dependencies.py --spec project.yml --target GenerativeArtStudio --sources Apps/GenerativeArtStudio --app …`) and `GenerativeArtStudioUITests`, plus scheme `GenerativeArtStudio`, to `project.yml`. Create `Apps/GenerativeArtStudio/App/GenerativeArtStudioApp.swift` with a home title "Generative Art Studio", identifier `gas.home.title` and an accessibility label, and `Apps/GenerativeArtStudio/Tests/UI/LaunchSmokeUITests.swift` (title exists within 10 s).
- [ ] T-A01-008 [US3] Build and test the shell on the iOS 27.2 and 26.5 simulators under `run-check` (SC-A01-003). Run `check_dependencies.py`, `check_compliance.py` and `check_documented_api.py --sources Apps/GenerativeArtStudio` (FR-A01-006).

## Phase 6: US4 — Gap register and stop/go decision (P2)

- [ ] T-A01-009 [US4] Add to the contract JSON:
  - the `gaps` register (G-SHADERLOAD, G-GLSLLIB → VisualCoreRendering; G-CLOCK → VisualCoreSimulation; G-PARAMS → new VisualCoreParameters; G-PERSIST → VisualCorePersistence; G-EXPORT → VisualCoreRendering `StillExporter`; G-UI → VisualCoreUI), each with a phase and a test;
  - `traceability` (v0.1 features 01–06 and journeys 1–3 → matrix rows → phases);
  - `negative` rules with sources (FR-A01-011);
  - `decision` (go, reasons, no blockers).

  Re-render the Markdown and add a narrative stop/go section. Verify with the checker (SC-A01-005, SC-A01-007).

## Phase 7: Polish and cross-cutting

- [ ] T-A01-010 Verify that `git diff --stat <phase-start>..HEAD -- Packages External` is empty (SC-A01-006). Add the release-check step `app-contracts` (runs `check_app_contract.py` for every `docs/apps/*/visualcore-contract.json`), with a test. Then run `validate_docs.py` and the full script tests.

## Dependencies

T-A01-001 → all. T-A01-002 → T-A01-003 → T-A01-004 → T-A01-005 → T-A01-009. T-A01-006 is independent after
T-A01-001. T-A01-007 → T-A01-008. T-A01-010 runs last.

## Parallel opportunities

- T-A01-002 (fixtures) and T-A01-007 (shell sources) touch different files.
- The Xcode lane is serial: one of T-A01-006 or T-A01-008 at a time.

## Implementation strategy

MVP = US1 (the checked matrix), then US2 and US3 (baseline and shell), then US4 (decision). The phase is complete
only when every task carries evidence and converge appends nothing.
