# Implementation Plan: Shader Studio — Phase 02 Compile and last-good-preview path

**Branch**: `160-ss-p02-compile-preview` (spec directory only; work on `main`) | **Date**: 2026-11-17 | **Spec**: [spec.md](spec.md)

## Summary

The experience arrives:
- **Core:** a `StudioCore` adapter holds the template, the uniform values and the run count.
- **Presenter:** `StudioPresenter` keeps the document. At its next frame it compiles the newest run request through
  VisualCore. On success it swaps in a new `FullScreenShaderScene`. On failure it keeps the live one and reports the
  mapped diagnostics.
- **Interface:** native controls (template picker, Run, uniform sliders, status, diagnostics list).
- **Registration:** a candidate.

This closes G-PREVIEW and G-RUN. Research: [research.md](research.md). Data: [data-model.md](data-model.md). Contract:
[contracts/experience.md](contracts/experience.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

- **Language:** Swift 6, SwiftUI.
- **Dependencies:** the experience → `ShaderStudioCore`, `VisualCoreShaderSource`, `VisualCoreParameters`,
  `VisualCoreExperience`, `VisualCoreRendering`, `VisualCoreExperienceHost`, `VisualCoreUI` (`VisualCoreDiagnostics` waits for
  the A22-P04 watchdog).
  Only APIs verified at A22-P00 and A22-P01 are used:
  - `ExperienceControl`, `ExperienceShell` and `ExperiencePresenter`;
  - `context.resources.program`, `FullScreenShaderScene` and `ShaderBundle(files:)`;
  - `ShaderAssembly`, `ShaderValidator`, `DiagnosticMapper` and `ShaderTemplates`.
- **Testing:**
  - `ShaderStudioCoreTests` and `ShaderStudioExperienceTests` on sim-27.2;
  - the app build and unit tests;
  - the runner on iOS 27.
- **Constraints:**
  - no GL call outside VisualCore's scenes, and no compile from a control's action;
  - the preview runs at 30 frames per second;
  - each test runs in under 10 s.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| I | PASS: every program compiled inside the presenter's calls in the host's context; scenes are VisualCore's |
| II | PASS: reuses `FullScreenShaderScene`, `ResourceRegistry.program`, the A22-P01 core; nothing copied |
| III | PASS: main-actor presenter; compile at the next frame only |
| IV | PASS: core actions and digest tested without the GPU |
| IX | PASS: native controls with spoken labels |
| XI | PASS: a candidate, not available; one app target |
| A22 (2.18.1) | PASS: queued compile requests, caps before compile, last good program kept, no sandbox claim |

Post-design: PASS.

## Project Structure

```text
Packages/ExperiencesCreative/Package.swift                                       modify  ShaderStudioExperience(+Tests), product
Packages/ExperiencesCreative/ShaderStudio/Experience/Adapter/{StudioCore,StudioManifest}.swift   new
Packages/ExperiencesCreative/ShaderStudio/Experience/{PreviewPipeline,StudioPresenter,StudioControls,ShaderStudioExperience}.swift new
Packages/ExperiencesCreative/ShaderStudio/ExperienceTests/{StudioCoreTests,LastGoodPreviewTests,RunQueueTests,
  UniformPreviewTests,RebuildTests,StudioManifestTests,StudioTestSupport}.swift   new
Packages/ExperiencesCreative/ShaderStudio/scenario-manifest.json                 new
Catalog/registrations.json; Apps/VisualCore/App/ExperienceRegistry.swift; project.yml   modify  candidate a22
Apps/VisualCore/Tests/Unit/AppModelTests.swift (synthetic id a23.visual-programming-lab); RealCatalogTests; scripts/test_scripts.py
docs/apps/shader-studio/visualcore-contract.json (G-PREVIEW, G-RUN closed)       modify
```

- **Dependency direction:** app → experience → core → VisualCore.
- **Lifecycle:**
  - the presenter builds the first template's scene in setup;
  - it compiles a pending request at its next draw and swaps scenes only on success;
  - it rebuilds the live scene from the last good source after a context loss or resize;
  - it tears every scene down in teardown, and drops a pending request on teardown.
- **Migration:** schema 1. **Rollback:** revert the commits.

## Parallel work

- **Agent C:** core adapter, manifest, their tests.
- **Agent P:** preview pipeline, presenter, controls, experience factory, presenter tests.
- **Lead:** Package.swift, registration (catalog, registry, project.yml, app and script tests), the contract, runs,
  commits.
