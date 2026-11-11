# Known limitations (feature 010 T-F910; FR-F904)

VisualCore 1.0.0-rc.1 is a **release candidate verified on iOS simulators only**. Read
[support-matrix.md](support-matrix.md) first.

## Evidence

1. **No physical-device evidence.** Device performance, compatibility, rendering correctness on real GPUs,
   thermal behavior and launch times are unmeasured until campaign II (D1 → D2 → D3).
2. **Performance baselines are host and simulator numbers** ([docs/performance](../performance/README.md)). They catch
   regressions; they are not targets and not device claims.

## Modules planned in the README layout but not built yet (ADR-0006)

| README entry | Missing part | Where it will be built |
|---|---|---|
| VisualCoreAudio | Microphone / in-app playback taps (`VisualCoreAudio`), FFT, bands, RMS and onset (`VisualCoreAudioDSP`). Both modules are placeholders. | With the first audio app phases (A06 VisualCore Music Lab, A07 Audio Odyssey, A08 Oscilloscope Studio), with ten-minute real-device diagnostics before any source-support claim (FR-031 lesson) |
| VisualCoreInput | Game-controller adapters. Touch, tap, drag and pinch exist. | With the first app manual that requires controllers (A10 Neon Arcade), if its manual calls for them |
| VisualCoreTestSupport | Deterministic fixtures and capture/image baselines as a shared module (placeholder today; image comparison lives in harness tests) | When a second app needs pixel baselines; promoted from `Harnesses/ProjectMReference` ImageDiff |
| VisualCoreUI | SwiftUI `RenderSurface`, diagnostics overlay, accessibility helpers (placeholder) | When the first app needs it; the Showcase pattern (`RenderCanvas`) is the reference |
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
