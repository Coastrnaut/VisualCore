# Contract: package ownership, API surface and dependency direction (FR-F101–FR-F103, FR-F112, FR-F115)

Supersedes the table in ADR-0003 where they differ (ADR-0003 is corrected to point here).

| Package / product | Platform | Owns | Public surface | May depend on | Audit trace |
|---|---|---|---|---|---|
| `Packages/VisualCore` · `VisualCoreMath` | host + iOS | vectors, matrices, quaternions, cameras, easing | value types | Foundation | gap: input/scenes/math |
| · `VisualCoreSimulation` | host + iOS | fixed-step clock, seeded RNG, timelines, particle pool, NaN guard, `SceneClock` (A01-P02), `AccessibilityPreferences` (A01-P05) | value types, protocols | Math | gap: deterministic simulation |
| · `VisualCoreScenes` | host + iOS | input mapping, pointer tracking, mesh generators, scene graph model, export geometry (`ExportGeometry`, A01-P04) | value types | Math | gap: input/scenes |
| · `VisualCoreShaderSource` | host + iOS | shader library, include preprocessing, line maps, diagnostics parsing | value types | Foundation | gap: shader library (U-F003-adjacent) |
| · `VisualCoreEffectsGraph` | host + iOS | effect DAG model, validation, quotas, flash-limiter model | value types | Foundation | gap: multi-pass graph; reference `CFlashLimiter` idea |
| · `VisualCoreDiagnostics` | host + iOS | `RenderLifecycle`, frame stats, missed slots, reports | value types | Foundation | gap: lifecycle; reference `FrameRateMeter`, `QualityGovernor` ideas |
| · `VisualCoreAudioDSP` | host + iOS | SPSC ring, FFT, bands, RMS, onset | value types | Foundation | reference `AudioCore` (reusable candidate) |
| · `VisualCorePersistence` | host + iOS | `DocumentStore`: versioned envelopes, atomic writes, migrations, per-file problems (built A01-P03) | value types | Foundation | constitution IX |
| · `VisualCoreParameters` | host + iOS | parameter schemas (units, ranges, transforms), resolution, palettes, presets, stable parameter hash, `ParameterEditor` (A01-P02) | value types | Foundation (added A01-P01, feature 012) | gap G-PARAMS (A01 contract) |
| · `VisualCoreTestSupport` | host + iOS | fake clock, fixtures, image compare | test-only | all pure modules | constitution IV |
| `Packages/VisualCoreRendering` · `CVisualCoreEGL` | iOS | EGL subset declarations (pinned ANGLE constants) | C | libEGL | reference `CANGLE` |
| · `CVisualCoreGL` | iOS | generated ES 3.0 table (`vcgl*`) | C | libEGL, libGLESv2 | gap: full GL table |
| · `VisualCoreRendering` | iOS | `RenderHost`, `RenderView` (+ touch adapter → `PointerEvent`), capabilities, resources, programs, primitive/particle/mesh drawing (F05, feature 006), offscreen still export (`renderOffscreen`, `StillImage`, `StillImageEncoder`; A01-P04) | classes (`@MainActor`) | C shims, pure modules | reference `ANGLERenderer` sequence (ADR-0002) |
| · `VisualCoreEffects` | iOS | GPU passes, target pool, graph executor, `EffectScene` (incl. `bypassEffects`, A01-P05) | classes | Rendering, EffectsGraph | gap: effects |
| · `VisualCoreUI` | iOS | SwiftUI `RenderSurface` (A01-P01), `ParameterPanel` (A01-P02), `SystemAccessibilityObserver` (A01-P05), diagnostics overlay (planned) | views | Rendering, Diagnostics, Parameters, Simulation (amended A01-P02 and A01-P05) | gap: native UI |
| · `VisualCoreAudio` | iOS | AVAudioEngine mic/in-app taps → DSP | classes | AudioDSP | reference `AudioCore` lessons |
| · `VisualCoreAutomation` | iOS | AutomationRunner (`DEBUG \|\| VISUALCORE_AUTOMATION`; empty otherwise) | classes | Rendering, Diagnostics (amended F09, feature 010) | reference projectM-iOS AutomationRunner |
| `Showcase/`, `Apps/<Name>/`, `Harnesses/SecondConsumer/` | iOS apps | product UI/domain | none | any VisualCore product except TestSupport (tests only) | — |
| `Harnesses/ProjectMReference/` (own `ProjectMReference.yml`) | iOS app | reference adapter | none | VisualCoreRendering + reference `ProjectMBridge` | F07 |

## Rules (enforced by `scripts/check_dependencies.py`)

1. **R1** — Only `Harnesses/ProjectMReference/` may import or depend on `ProjectMBridge`,
   `ANGLERendering`, `Rendering`, `PresetLibrary`, `CaptureKit`, `CaptureUI`, `AudioCore`,
   `Diagnostics`, `CANGLE`, `CFlashLimiter` (reference packages and their C modules) or `ProjectM.xcframework`; names match whole.
2. **R2** — Pure `VisualCore` modules import only Foundation-level system modules (`Foundation`,
   `Dispatch`, `os`, `Darwin`, `Glibc`, `_Concurrency`, `Synchronization`, `simd`, `Accelerate` — the last two are system math libraries
   available on both macOS and iOS, needed for vector math and FFT) and each other; never UIKit,
   SwiftUI, QuartzCore, AVFAudio or the C GL shims. Tests may also import `XCTest`/`Testing`.
3. **R3** — No cycles between products (manifest dependency graph is acyclic).
4. **R4** — `Packages/*` never import app or harness modules.
5. **R5** — `VisualCoreTestSupport` appears only in test targets.

## Public vs internal

Public = what a consumer app needs: types listed above with `public`. Everything else is
`internal` or `package`. Every public declaration gets a doc comment (checked in F09). Each package's
version starts at 0.1.0 and stays 0.x until F09. Breaking changes before then need an ADR and a
migration note; after 1.0 they need a MAJOR bump.
