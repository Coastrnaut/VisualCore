# Implementation Plan: Effects Composer — Phase 02 Linear pass compiler and preview

**Branch**: `181-ec-p02-pass-compiler-preview` (spec directory only; work on `main`) | **Date**: 2026-11-19 | **Spec**: [spec.md](spec.md)

## Summary

The pure pass compiler and a larger test image join the core; the experience target arrives with its core adapter
(the chain and its history behind validated actions), a presenter that draws the compiled plan with the effect
programs over pooled targets and reports program failures, inline native controls and a scenario manifest. The
experience registers as a candidate and the runner checks it on iOS 27.2. Gaps G-COMPILER, G-POOL and G-DIAG close.

Research: [research.md](research.md). Data: [data-model.md](data-model.md). Contract:
[contracts/experience.md](contracts/experience.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

- **Language:** Swift 6, Swift Testing, SwiftUI for the controls; GLSL ES 3.00 programs from the core.
- **Dependencies:** the core as in A25-P01; the experience also VisualCoreRendering (`FieldPass`, `ResourceRegistry`
  pools), VisualCoreExperienceHost (`ExperiencePresenter`, `ExperienceShell`, `ExperienceSession`) and VisualCoreUI.
- **Storage:** the session snapshot only (the chain).
- **Testing:** `EffectsComposerCoreTests` and `EffectsComposerExperienceTests` on sim-27.2; the app build and unit
  tests; the runner `verify_experiences.py --only a25.effects-composer --runtime 27`.
- **Performance:** a 256 × 256 preview with at most 8 passes; each unit test under 10 s.
- **Constraints:** no VisualCore change; no availability to a person; no GL call outside `FieldPass` and the registry.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| I | PASS: drawn through `FieldPass` in the host's context |
| II | PASS: reused `FieldPass`, `acquireTarget`/`recycle`, `ExperiencePresenter`; compiler app-local by decision |
| II-a | PASS: no VisualCore change |
| III | PASS: GPU objects created in setup, rebuilt after a context loss, released in teardown |
| IV | PASS: compiler and actions pure and tested |
| V | PASS: no device step |
| VI | PASS: no claim |
| VII–X | PASS |
| XI | PASS: a candidate, not available |
| XII, XIII | PASS: test image made in code |

A25 rules: drawing never changes the chain; no pass samples its output; targets bounded and pooled. PASS. Post-design:
PASS.

## Project Structure

```text
Packages/ExperiencesCreative/Package.swift                     modify  EffectsComposerExperience(+Tests), product
Packages/ExperiencesCreative/EffectsComposer/Core/{PassPlan.swift (new), TestImage.swift (make(size:))}
Packages/ExperiencesCreative/EffectsComposer/CoreTests/PassPlanTests.swift                                new
Packages/ExperiencesCreative/EffectsComposer/Experience/Adapter/{ComposerCore,ECManifest}.swift           new
Packages/ExperiencesCreative/EffectsComposer/Experience/{PreviewRenderer,ComposerPresenter,ECControls,EffectsComposerExperience}.swift new
Packages/ExperiencesCreative/EffectsComposer/ExperienceTests/{ComposerTestSupport,ComposerCoreTests,PreviewDrawTests,IdentityTests,DiagnosticTests,
  PoolTests,ECManifestTests}.swift                              new
Packages/ExperiencesCreative/EffectsComposer/scenario-manifest.json                                       new
Catalog/registrations.json; Apps/VisualCore/App/ExperienceRegistry.swift; project.yml   modify  candidate a25
Apps/VisualCore/Tests/Unit/AppModelTests.swift (synthetic id r02-g01.aurora-loom); RealCatalogTests; scripts/test_scripts.py
docs/apps/effects-composer/visualcore-contract.json (G-COMPILER, G-POOL, G-DIAG closed)   modify
```

- **Dependency direction:** app → experience → core → VisualCore.
- **Lifecycle:** the presenter builds the programs and uploads the source in `setup`, acquires and recycles targets in
  `draw`, recompiles the plan when the chain's fingerprint changes, passes the size in `resize` and releases
  everything in `teardown`; a context rebuild repeats `setup`.
- **Migration:** snapshot schema 1. **Rollback:** revert the commits.

## Parallel work

- **Agent C:** PassPlan, TestImage.make(size:) and PassPlanTests (core).
- **Agent X:** the experience files and their tests (after the lead's Package.swift change).
- **Agent G:** registration, manifest JSON, ExperienceRegistry, project.yml, AppModelTests and the synthetic id, after
  the X agent's ECManifest exists.
- **Lead:** Package.swift, the contract, the runs, the commits.
