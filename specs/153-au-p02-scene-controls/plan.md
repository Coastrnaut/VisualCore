# Implementation Plan: Aurora — Phase 02 Scene selection and controls

**Branch**: `153-au-p02-scene-controls` (spec directory only; work on `main`) | **Date**: 2026-11-17 | **Spec**: [spec.md](spec.md)

## Summary

This phase adds the Aurora experience and closes G-CONTROLS, G-CAP and G-CHROME:
- **Controls:** eight bounded actions (preset, hue, speed, turbulence, ribbons, stars, clouds, limit) in an adapter
  core with snapshot schema 1.
- **Cap:** a brightness limit in the shader and the reference, so every frame, including mid-change, stays under it.
- **Change:** an eased 1.5 s blend of the shader inputs between presets, immediate under Reduce Motion.
- **Chrome:** native controls that hide and return by a tap or the accessibility action "Show controls".
- **Registration:** a candidate with a manifest of standard scenarios and fixtures.

Research: [research.md](research.md). Data: [data-model.md](data-model.md). Contract:
[contracts/experience.md](contracts/experience.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

- **Language:** Swift 6, SwiftUI and GLSL (as text). **Dependencies:** the experience target uses the products the
  Digital Zen Garden experience uses (VisualCoreMath, VisualCoreScenes, VisualCoreSimulation, VisualCoreDiagnostics,
  VisualCorePersistence, VisualCoreExperience, VisualCoreRendering, VisualCoreExperienceHost, VisualCoreUI).
- **Testing:** `AuroraCoreTests` and `AuroraExperienceTests` on sim-27.2; the app build and unit tests; the runner on
  iOS 27.
- **Constraints:** no GL call outside the scene protocol; no availability before X-A21; no VisualCore change. No NEEDS
  CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| I | PASS: the presenter's scene draws on the host's context only |
| II | PASS: reuses `FullScreenShaderScene`, `SceneClock`, `ExperienceEngine`, `GestureAlternatives`, the manifest tools |
| IV | PASS: the adapter core and the limit math are pure and tested |
| IX | PASS: native controls with spoken labels; a tap and an accessibility action restore hidden controls |
| A21 | PASS: the limit caps every frame; nothing flashes; changes immediate under Reduce Motion |

Post-design: PASS.

## Project Structure

```text
Packages/ExperiencesCreative/Package.swift                                 modify  AuroraExperience(+Tests), product
Packages/ExperiencesCreative/Aurora/Core/{SkyShader,SkyReference}.swift      modify  u_limit, reference limit
Packages/ExperiencesCreative/Aurora/CoreTests/LimitTests.swift               new     reference under every limit
Packages/ExperiencesCreative/Aurora/Experience/Adapter/{AuroraCore,AuroraManifest}.swift   new
Packages/ExperiencesCreative/Aurora/Experience/{SkyBlend,AuroraPresenter,AuroraControls,AuroraExperience}.swift new
Packages/ExperiencesCreative/Aurora/ExperienceTests/{AuroraCoreTests,LimitRenderTests,BlendTests,ChromeTests,
  AuroraManifestTests,RebuildTests}.swift                                    new
Packages/ExperiencesCreative/Aurora/scenario-manifest.json                   new
Catalog/registrations.json; Apps/VisualCore/App/ExperienceRegistry.swift; project.yml   modify  candidate a21
Apps/VisualCore/Tests/Unit/AppModelTests.swift (synthetic id a22.shader-studio); RealCatalogTests; scripts/test_scripts.py
docs/apps/aurora/visualcore-contract.json (G-CONTROLS, G-CAP, G-CHROME closed)   modify
```

- **Dependency direction:** app → experience → core → VisualCore.
- **Lifecycle:** the presenter creates the scene in setup, rebuilds it after a context loss or resize from the state,
  releases it in teardown; the clock advances only by frame deltas.
- **Migration:** schema 1. **Rollback:** revert the commits.

## Parallel work

- **Agent E:** the adapter, presenter, blend, controls, factory and their tests; the limit in the shader and
  reference with its core test.
- **Agent M:** the manifest and its tests (after E's adapter).
- **Lead:** Package.swift, the registration, app and script tests, the contract, runs and commits.
