# Fluid Art Playground — store listing draft

This is a draft for the owner. The name, subtitle and keywords are placeholders until the owner chooses store
branding; the bundle ID `dev.visualcore.FluidArtPlayground` is the approved placeholder. Every claim below maps to a
passing test. A claim that cannot be traced is removed, not softened. The fluid is described as an artistic
simulation (manual §13).

**Name:** Fluid Art Playground
**Subtitle:** Paint with flowing, glowing dye

**Description:**

> Swipe to paint with dye that swirls and drifts in an artistic fluid simulation, or tap Add splash. Choose Ink,
> Smoke or Glowing dye, pinch or use the slider to size your brush, and tune viscosity, fade, quality and the edges
> in Adjust. Pick a simulation detail level; when your device is hot or in Low Power Mode, quality is lowered
> automatically.
>
> Pause the fluid, step it one frame at a time, or reset to the starting picture. Capture a still and share or save
> it.
>
> Works with VoiceOver and large text, and honors Dim Flashing Lights. Everything stays on your device: no account,
> no tracking, no network.

## Claim traceability

| Claim | Test |
|---|---|
| Swipe to paint; Add splash | `PlaygroundUITests.testSplashControlAndSwipe`; `PlaygroundModelTests.testPointerEventsBecomeAppliedSplats` |
| Dye swirls and drifts (advection, projection) | `AdvectionFixtureTests.testSplatThenAdvectWithDissipationMatchesCPU`; `ProjectionFixtureTests.testProjectionMatchesCPU` |
| Ink, Smoke, Glowing dye | `PaletteRenderTests.testPalettesAreDistinctAndMatchTheirDefinition`; `PaletteCaptureUITests.testPaletteBrushAndCapture` |
| Pinch or slider brush size | `PinchTests.testPinchScalesTheBrushWithoutSplats`; `PaletteCaptureUITests.testPaletteBrushAndCapture` |
| Viscosity, fade, quality, edges in Adjust | `AdjustUITests.testControlsChangeAndReset`; `ProjectionFixtureTests.testLiveConfigurationUpdate` |
| Simulation detail levels | `DetailTests.testEachLevelBuildsItsGrid` |
| Quality lowered automatically when hot or in Low Power Mode | `QualityWiringTests.testHotDeviceLowersIterationsFirstThenSplats`; `QualityWiringTests.testRecoveryAfterCalmAndLowPowerCeiling` |
| Pause, step one frame, reset | `ControlsUITests.testPauseStepResetResume`; `ControlTests.testStepWhilePausedRunsExactlyOneStep`; `ControlTests.testResetRestoresTheStartingFields` |
| Capture a still; share or save | `CaptureTests.testCaptureProducesPNGWithoutStepping`; `PaletteCaptureUITests.testPaletteBrushAndCapture` |
| VoiceOver and large text | `AccessibilityAuditUITests.testAuditDefaultTextSize`; `AccessibilityAuditUITests.testAuditLargestAccessibilityTextSize` |
| Honors Dim Flashing Lights | `PaletteRenderTests.testGlowBloomsAndHonorsReduceFlashing` |
| On device only; no account, tracking or network | `PrivacyTests.testSessionStoresNothing`; `check_privacy_manifest.py` (Data Not Collected); `check_compliance.py` (no networking APIs) |

**Removed:** frame-rate, battery, device-compatibility and physical-accuracy wording. There is no device evidence
before campaign II, and the simulation is artistic.
