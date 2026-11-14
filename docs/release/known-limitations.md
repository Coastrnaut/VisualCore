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
`VisualCoreUI.SystemAccessibilityObserver`, `AccessibilitySettingsSection`, `AccessibleColors` and
`EffectScene.bypassEffects`. The table
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

## Experiences

### Particle Universe (A04; feature 038 T-A04-617)

- Frame pacing, the drawn-detail steps under load, thermal behaviour and memory are unmeasured on devices; the only
  profile is a simulator signal. They wait for the device campaign ([device-campaign.md](../apps/particle-universe/device-campaign.md)).
- The system accessibility audits (default and largest text size) wait for the device campaign (owner ruling of
  2026-11-13).
- Drawn detail reacts to frame time, heat and Low Power Mode; the simulation itself is never thinned.
- One placed force at a time; saved scenes stay on the device (no sync, no sharing, no export).

### Infinite Geometry (A05; feature 045 T-A05-607)

- Frame time per quality tier for every preset kind, the tier the governor settles on, memory with the mesh cache
  full, the thermal state over a short session and the export time are unmeasured on devices. They wait for the device
  campaign ([device-campaign.md](../apps/infinite-geometry/device-campaign.md)).
- The system accessibility audits (default and largest text size) and the VoiceOver journeys wait for the device
  campaign (owner ruling of 2026-11-13).
- Drawn detail of the 3D composition follows the host's quality level (thermal state and Low Power Mode); the 2D
  presets draw the same at every level, and the composition and its digest never change.
- Compositions are static: nothing moves with time, so Reduce Motion has nothing to reduce.
- Saved compositions stay on the device (no sync); a picture leaves only through the share sheet, as a PNG without
  metadata. At most 64 files fit in the experience's storage.

### VisualCore Music Lab (A06; feature 052 T-A06-607)

- Frame time per scene and analysis level, the tier the governor settles on, memory and the thermal state over ten
  minutes are unmeasured on devices. They wait for the device campaign
  ([device-campaign.md](../apps/visualcore-music-lab/device-campaign.md)).
- Interruptions (call, alarm, Siri), route changes (headphones out) and media resets are tested only as simulated
  audio-session events; their behaviour on hardware, and that other apps' music keeps playing, wait for the device
  campaign.
- The microphone permission flows (first request, refusal, grant, revoke in Settings while running) are tested with an
  injected permission state only; the system prompt itself is answered by the owner on the devices.
- The system accessibility audits (default and largest text size), VoiceOver labels and values on hardware (including
  the sound metrics text), Dynamic Type at the largest size, Reduce Motion and the contrast of each palette wait for
  the device campaign (owner ruling of 2026-11-13).
- The sound metrics text is an approximate visual aid, not a measurement; no hearing, health or accuracy claim is made.
- Sound is analysed in memory only and never recorded; the sound of other apps cannot be captured. A picked file is
  read in place; a file that cannot be decoded keeps the previous source and shows a message.
- Presets stay on the device (no sync); at most 64 files fit in the experience's storage, and a save beyond the quota
  is refused with a message.

## Distribution

- No App Store submission, signing or purchase setup is part of this release; those are owner actions.
- LGPL-licensed projectM appears only in a harness that is not distributed
  ([lgpl-analysis](../legal/lgpl-analysis.md)).
