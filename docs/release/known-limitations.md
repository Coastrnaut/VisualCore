# Known limitations (feature 010 T-F910; FR-F904)

VisualCore 1.0.0-rc.1 is a **release candidate verified on iOS simulators only**. Read
[support-matrix.md](support-matrix.md) first.

## Evidence

1. **No physical-device evidence.** Device performance, compatibility, rendering correctness on real GPUs,
   thermal behavior and launch times are unmeasured until campaign II (D1 → D2 → D3).
2. **Performance baselines are host and simulator numbers** ([docs/performance](../performance/README.md)). They catch
   regressions; they are not targets and not device claims.

## Unsupported capabilities

| Capability | Status | Reason |
|---|---|---|
| System / other-app audio capture | Not offered | No public iOS API for arbitrary system audio capture is used; ReplayKit or entitlement workarounds are prohibited (CLAUDE.md §5). The iOS 27 System/App Capture evaluation belongs to the ProjectM-iOS product, not VisualCore, and must show as unavailable on iPadOS 26.5 (D3). |
| Home-screen live wallpaper | Not offered | iOS has no public API for third-party live home-screen wallpapers (CLAUDE.md §4). |
| Direct Metal rendering | Not offered by design | The only renderer is OpenGL ES through ANGLE's Metal backend; a second renderer is prohibited (CLAUDE.md §4). |
| Microphone / in-app playback audio | Not built yet | See ADR-0006; any source claim needs a ten-minute real-device diagnostic. |
| User-authored GLSL | Not offered | Shaders are bundled, versioned assets; a shader editor needs strict input and resource bounds (planned with A22 Shader Studio). |

## Modules planned in the README layout but not built yet (ADR-0006; updated after A01-P01)

Built since rc.1: `VisualCoreParameters` (new), `VisualCoreUI.RenderSurface`, `VisualCoreTestSupport` image comparison,
and `VisualCoreRendering` `ShaderBundle`, the `vc/*.glsl` library and `FullScreenShaderScene` (feature 012).
Feature 013 added `SceneClock`, `ParameterEditor` and `VisualCoreUI.ParameterPanel`. Feature 014 built
`VisualCorePersistence` (`DocumentStore`). Feature 015 added offscreen still export (`RenderHost.renderOffscreen`,
`StillImage`, `StillImageEncoder`) and `VisualCoreScenes.ExportGeometry`. Feature 016 added `AccessibilityPreferences`,
`VisualCoreUI.SystemAccessibilityObserver` and `EffectScene.bypassEffects`. The table
lists what remains.

| README entry | Missing part | Where it will be built |
|---|---|---|
| VisualCoreAudio | Microphone / in-app playback taps (`VisualCoreAudio`), FFT, bands, RMS and onset (`VisualCoreAudioDSP`). Both modules are placeholders. | With the first audio app phases (A06 VisualCore Music Lab, A07 Audio Odyssey, A08 Oscilloscope Studio), with ten-minute real-device diagnostics before any source-support claim (FR-031 lesson) |
| VisualCoreInput | Game-controller adapters. Touch, tap, drag and pinch exist. | With the first app manual that requires controllers (A10 Neon Arcade), if its manual calls for them |
| VisualCoreTestSupport | Fake clock and deterministic fixtures. `ImageComparison`/`ImageStatistics` were built in A01-P01. | When an app needs them |
| VisualCoreUI | Diagnostics overlay and accessibility settings model. `RenderSurface` was built in A01-P01. | A01-P02 (accessibility settings) and the first app that needs the overlay |
| VisualCoreDiagnostics | Asset metrics. Frame, memory, thermal and Low Power Mode are present. | With the first asset-heavy app |
| VisualCoreShaders | A shader "preset" format beyond defines. ProjectM presets stay out of the public API by rule. | Only if an app manual requires one (e.g. A22 Shader Studio) |

The README's ten separate packages are consolidated into two SwiftPM packages, `VisualCore` (pure, host-testable)
and `VisualCoreRendering` (iOS, GL). ADR-0003 and the package map record this. Resources live in
`VisualCoreRendering`'s `ResourceRegistry`, shader sources in `VisualCoreShaderSource`, and scenes/input in
`VisualCoreScenes`, `VisualCoreMath` and `VisualCoreSimulation`.

## Rendering

- OpenGL ES 3.0 through ANGLE's Metal backend only. There is no direct Metal renderer and no public EGL bridge, by design
  (CLAUDE.md §4).
- All GL work runs on the main thread (`@MainActor` RenderHost). A Swift actor is not an EGL-thread guarantee.
- The ProjectM engine path in `Harnesses/ProjectMReference` matches its reference within the engine's own
  noise floor (SC-F702 amended: noise floor − 1 pp, ≥ 95 %, mean ≤ 2), not bit-exactly.
- Effect graphs are limited to 32 passes and a 256 MiB render-target quota by default.

## Distribution

- No App Store submission, signing or purchase setup is part of this release; those are owner actions.
- LGPL-licensed projectM appears only in a harness that is not distributed
  ([lgpl-analysis](../legal/lgpl-analysis.md)).
