# Implementation Plan: Generative Art Studio — Phase 05 Polish, accessibility and regression

**Branch**: `016-gas-p05-polish-a11y` | **Date**: 2026-11-11 | **Spec**: [spec.md](spec.md) | **Gate**: A01-P05

## Summary

Gap G-UI (matrix row M10) is closed in VisualCore, following constitution Principle II:

- **VisualCoreSimulation** (pure, host-testable) gets `AccessibilityChoice` (system, on, off),
  `AccessibilityPreferences` (the app's choices, Codable) and `SystemAccessibility` (the system flags). `resolve(_:)`
  gives `EffectiveAccessibility` with `reduceMotion`, `reduceFlashing` and the clock rate. The module already owns
  `SceneClock.reducedMotionFactor`.
- **VisualCoreUI** gets `SystemAccessibilityObserver` (`@MainActor @Observable`). It reads
  `UIAccessibility.isReduceMotionEnabled` and `MADimFlashingLightsEnabled()` and refreshes on their public change
  notifications. Its source can be replaced in tests.
- **VisualCoreEffects** gets `EffectScene.bypassEffects`. When it is true, the content renders straight into the
  host framebuffer: the graph and limiter are skipped and the renderer state is kept. That serves two purposes: zero
  cost when no effect is wanted, and still exports that must not be limited.

The app adds:
- `SettingsView`, with Reduce Motion and Reduce Flashing pickers (`@AppStorage`) and About;
- `SceneModel.apply(_ effective:)`, which applies changes live to the clock rate and to the flash limiter's
  `EffectScene` wrapper;
- `CanvasDescription` in Core;
- the accessibility audit UI tests;
- the background/foreground and recreation regression fixture.

## Technical Context

**Language/Version**: Swift 6.4.2

**Primary Dependencies**:
- VisualCoreSimulation: Foundation only (rule R2).
- VisualCoreUI: SwiftUI, UIKit and MediaAccessibility (public; `MADimFlashingLightsEnabled` is iOS 16.4+), plus the
  new dependency on VisualCoreSimulation (pure → UI direction, rules R2/R3 hold).
- VisualCoreEffects: unchanged dependencies.

**Storage**: two `UserDefaults` strings in the app's own domain: `gas.a11y.reduceMotion` and
`gas.a11y.reduceFlashing` (`system`, `on` or `off`).

**Testing**:
- host: `AccessibilityPreferencesTests`, 12 resolution cases plus Codable and unknown raw values;
  `CanvasDescriptionTests` (Core);
- VisualCoreRendering simulator tests:
  - `SystemAccessibilityObserverTests`: the injected source and a notification refresh;
  - `EffectSceneBypassTests`: bypass renders content identical to direct rendering, keeps the limiter's renderer, and
    0 leaks;
- app hosted tests:
  - `AccessibilityApplyTests`: rate and limiter follow `apply` within one frame; black↔white alternation is limited
    to ≤ 0.3 × Δt + 1/255 per frame, and unlimited without; an export during limiting equals the unlimited content;
  - `LifecycleRegressionTests`: background/foreground notifications and `recreateContext` for 4 families; same image
    (mean ≤ 1/255); stale delta 0 after recovery; leaks 0; 20 cycles with no growth; export after recovery;
- UI tests:
  - `SettingsUITests`: pickers, persistence across relaunch, footer text;
  - `AccessibilityAuditUITests`: `performAccessibilityAudit` on gallery, scene, controls, export, library and
    settings, at the default text size and `UICTContentSizeCategoryAccessibilityXXXL`; canvas description changes
    after a palette change;
- the full app suites on both runtimes, the ProjectM regression, API and contract checks.

**Target Platform**: iOS/iPadOS 26.0+

**Performance Goals**: none claimed. With bypass, the default path adds no pass. The limiter adds one copy pass and
the limiter pass only when Reduce Flashing is effective.

**Constraints**: offline; no permission; `UserDefaults` only for the two choices; no device claims.

**Scale/Scope**: 4 VisualCore types plus 1 property, 1 Core type, 1 view, 3 app changes, 6 test files.

## Constitution Check

| Principle | Status |
|---|---|
| I Renderer | PASS: same host; the limiter is the existing VisualCore pass; no GL in the app |
| II Maximize reuse | PASS: preferences, observer and bypass are in VisualCore; the app keeps the settings UI and the canvas wording |
| II-a Reference | PASS: ProjectM regression after the VisualCore change |
| III Lifecycle | PASS: the regression fixture checks recreation, stale use and leaks for every family |
| IV Host-testable | PASS: preference resolution and the canvas description are pure |
| V Simulator only | PASS |
| VI Evidence | PASS |
| VII Accessible UI | PASS: this phase's subject, with the audit at two text sizes |
| VIII Privacy | PASS: two local preference strings; reading accessibility flags needs no permission |
| IX Bounded input | PASS: unknown stored values fall back to System |
| X Licensing | PASS: no assets |
| A01 rules | PASS |

## Project Structure

```text
Packages/VisualCore/Sources/VisualCoreSimulation/AccessibilityPreferences.swift   (+ Tests/VisualCoreSimulationTests/AccessibilityPreferencesTests.swift)
Packages/VisualCoreRendering/Sources/VisualCoreUI/SystemAccessibilityObserver.swift (+ Tests/VisualCoreUITests/SystemAccessibilityObserverTests.swift)
Packages/VisualCoreRendering/Package.swift                                        # VisualCoreUI → VisualCoreSimulation
Packages/VisualCoreRendering/Sources/VisualCoreEffects/EffectScene.swift          # + bypassEffects (+ Tests/VisualCoreEffectsTests/EffectSceneBypassTests.swift)
Apps/GenerativeArtStudio/Core/Sources/GenerativeArtStudioCore/CanvasDescription.swift (+ CanvasDescriptionTests.swift)
Apps/GenerativeArtStudio/App/SettingsView.swift                                   # pickers, footer, About; gas.settings.*
Apps/GenerativeArtStudio/App/SceneScreen.swift                                    # EffectScene wrapper, apply(effective), canvas label
Apps/GenerativeArtStudio/App/ExportSheet.swift                                    # bypassEffects during export
Apps/GenerativeArtStudio/App/GalleryView.swift                                    # Settings button gas.settings.open
Apps/GenerativeArtStudio/App/GenerativeArtStudioApp.swift                         # one SystemAccessibilityObserver in the environment
Apps/GenerativeArtStudio/Tests/Unit/{AccessibilityApplyTests,LifecycleRegressionTests}.swift
Apps/GenerativeArtStudio/Tests/UI/{SettingsUITests,AccessibilityAuditUITests}.swift
project.yml                                                                       # + VisualCoreEffects product on the app
docs/apps/generative-art-studio/visualcore-contract.{json,md}                     # G-UI closed, M10 available
```

**Dependency direction**:
- App → Core → VisualCoreSimulation and VisualCoreParameters.
- App → VisualCoreUI, VisualCoreEffects and VisualCoreRendering.
- VisualCoreUI → VisualCoreSimulation (pure).
- No ProjectM module anywhere.

**Lifecycle contracts**:
- **Live scene**: the host scene becomes `EffectScene(content: clocked, graph: copy)`, with
  `bypassEffects = !effective.reduceFlashing` and `reduceFlashing = effective.reduceFlashing`.
  `SceneModel.apply(_:)` sets them and `clock.reducedMotion`, and takes effect on the next frame.
- **Export**: `ExportRunner` sets `bypassEffects = true` for the offscreen render and restores the previous value in
  its `defer`. The limiter's renderer is not invalidated, so its state is kept.
- **Settings to scene**: SceneScreen observes `SystemAccessibilityObserver` and the two `@AppStorage` values, and
  calls `apply` on change (`onChange`) and on appear.
- **Background, foreground and context loss**: the host already suspends on `didEnterBackground` and resumes on
  `willEnterForeground`. `recreateContext()` tears the scene down and sets it up again. The fixture checks the
  outcome; there are no new host paths.

**Data migration**: none. The new preference keys default to System when absent.

**Rollback**: revert the phase commits. The VisualCore additions are additive. `bypassEffects` defaults to false,
so existing `EffectScene` users are unchanged.

## Complexity Tracking

None.
