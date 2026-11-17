# Implementation Plan: Ambient Clock — Phase 02 Native clock overlay and one shader theme

**Branch**: `132-ac-p02-overlay-theme` (spec directory only; work on `main`) | **Date**: 2026-11-16 | **Spec**: [spec.md](spec.md)

## Summary

This phase builds G-OVERLAY and G-BUDGETS:
- **Core:** `AmbientCore`, the experience core over numbers only, with the actions `time.set`, `time.changed`,
  `clock.format`, `theme.motion` and `theme.speed`, two quality levels and a snapshot of schema 1.
- **Presenter:**
  - it draws the "Noise gradient" theme on a `FullScreenShaderScene` (the Infinite Geometry pattern);
  - it holds the `AmbientClockState` display model with an injected environment provider and clock source;
  - it starts a `TimeChangeMonitor` with `applicationNames`;
  - it draws the time and date in the canvas overlay with system fonts and labels the canvas with the spoken time.
- **Registration:** a candidate in the one app, with the nine standard scenarios.

Research: [research.md](research.md). Data: [data-model.md](data-model.md). Contract:
[contracts/experience.md](contracts/experience.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

- **Language:** Swift 6, GLSL ES 3.00 through `FullScreenShaderScene` with `#include "vc/noise.glsl"` and
  `vc/color.glsl`.
- **Dependencies:**
  - the experience → `AmbientClockCore`;
  - VisualCore products: VisualCoreExperience, VisualCoreExperienceHost, VisualCoreRendering, VisualCoreUI,
    VisualCoreDiagnostics, VisualCoreSimulation and VisualCorePersistence;
  - SwiftUI and UIKit.
- **Testing:**
  - `AmbientClockCoreTests` and `AmbientClockExperienceTests` on sim-27.2;
  - the verification runner on iOS 27;
  - the app build and unit tests.
- **Constraints:** tests under 10 s; no wall-clock assert (the presenter tests inject `FixedClock`); no frame-rate cap
  in this phase (G-FRAMERATE). No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| I, III | PASS: one `FullScreenShaderScene` owned by the presenter through the host's `RenderContext`; no context code |
| II Reuse | PASS: `FullScreenShaderScene`, `vc_fbm`, `AccessibleColors`, the A18-P01 core and the clock source |
| IV Pure core | PASS: `AmbientCore` holds numbers only and reads no clock; the presenter reads the injected source |
| V Persistence | PASS: snapshot schema 1 (format, motion, speed); the instant is not stored |
| VI Tests | PASS: core, presenter, render, time-zone and manifest tests |
| VIII Privacy | PASS: no permission, no network |
| IX Accessibility | PASS: Dynamic Type sizing, the spoken label, Reduce Motion still, contrast ≥ 4.5 : 1 |
| X–XIII | PASS: documented API; no VisualCore change |

The A18 rules pass. Visuals are code. There is no simulated clock in production, no keep-awake and no brightness
change. Post-design: PASS.

## Project Structure

```text
Packages/ExperiencesCreative/Package.swift: targets AmbientClockExperience(Tests), product AmbientClockExperience   modify
Packages/ExperiencesCreative/AmbientClock/Experience/{Adapter/AmbientCore.swift,Adapter/AmbientManifest.swift,
  NoiseGradientTheme.swift,ClockOverlay.swift,AmbientPresenter.swift,AmbientControls.swift,
  AmbientClockExperience.swift}                                                                    new
Packages/ExperiencesCreative/AmbientClock/ExperienceTests/{AmbientTestSupport,AmbientCoreTests,ThemeTests,
  OverlayTests,PresenterClockTests,TimeZoneChangeTests,AmbientRenderTests,AmbientManifestTests}.swift  new
Packages/ExperiencesCreative/AmbientClock/scenario-manifest.json                                    generated
Catalog/registrations.json (a18 candidate), Catalog/experiences.json and the fixture copies (build_catalog.py)  modify
Apps/VisualCore/App/ExperienceRegistry.swift (candidate); project.yml (product); app and script tests listing
  registrations                                                                                    modify
docs/apps/ambient-clock/visualcore-contract.json (G-OVERLAY, G-BUDGETS closed)                     modify
```

- **Dependency direction:** the experience → the core → VisualCoreExperience and VisualCoreSimulation. Nothing in
  VisualCore depends on the experience.
- **Lifecycle:**
  - `setup` makes the scene (and again after a recreation), starts the monitor and sends nothing by itself;
  - `draw` sets the uniforms from the core and the frame and draws once;
  - `teardown` releases the scene and stops the monitor;
  - the overlay's task calls `tick(port:)` and sleeps until the deadline, and it is cancelled when the overlay
    disappears.
- **Migration:** none; snapshot schema 1 is the first.
- **Rollback:** revert the commits; the pending core of A18-P01 remains.

## Parallel work

- **Agent E:** the experience sources.
- **Agent T:** the experience tests, against the contract.
- **Lead:**
  - `Package.swift`, the registration, `ExperienceRegistry.swift` and `project.yml`;
  - the manifest generation;
  - the contract, the runs and the commits.
