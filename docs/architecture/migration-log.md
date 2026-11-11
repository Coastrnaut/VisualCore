# ProjectM boundary migration log

The reference `External/projectm-ios` is read-only (constitution II-a, ADR-0002). "Migrating a boundary"
means VisualCore re-implements that boundary app-neutrally. The reference keeps its own code, and the
unmodified reference build and regression tests are rerun after each boundary.

| # | Date | Boundary | VisualCore implementation | Reference regression after the boundary | Behavior change |
|---|---|---|---|---|---|
| 1 | 2026-11-10 | EGL display/context/surface lifecycle, frame pacing, teardown (`ANGLERenderer` §2–§7) | `VisualCoreRendering.RenderHost`, `EGLDisplayProvider`, `RenderView`, `FrameScheduler`; `VisualCoreDiagnostics.RenderLifecycle`, `FramePacing` (feature 003) | `projectM-iOS` simulator build SUCCEEDED; `ANGLERendering` tests 13/13 on iOS 27.2 and 26.5; reference tree clean (checks `F02.f02-ref-*`) | none in the reference (unchanged); VisualCore adds recreation and explicit states (intentional, render-lifecycle contract) |
| 2a | 2026-11-10 | GPU state and resources coexisting with the engine in one context | `GLState.resetForVisualCore` (VisualCoreRendering, app-neutral: any foreign GL engine may leave VAO/program/blend/cull/scissor/mask/texture-unit/unpack state that VisualCore assumes default) and `RenderContext.redirected` so wrappers capture content that binds `context.framebuffer`; VisualCore `EffectScene` (feature 005) runs over `ProjectMEngine` output. Why VisualCore: every app that embeds third-party GL needs the same handoff; nothing ProjectM-specific. | Before: `F07.pin-d93edd1-*` (reference 14/14 both runtimes). After: `F07.t704-glstate-ios27/26` (negative control + reset), `F07.t706-effectscene-redirect-ios27`, `F07.t706-effects-over-engine` (swap matches channel means ±3, engine keeps rendering, flash limiter bounds steps), `F07.t707-vc-sim-ios26` (50 + 18), reference `F07.t707-ref-ios27/26` 14/14, `F07.t707-ref-clean` | Reference: none (unmodified). VisualCore: `EffectScene` now hands its content a context redirected to the scene target (fixes content that binds `context.framebuffer`); new public `GLState`, `RenderContext.redirected`. |
| 2 | 2026-11-10 | ProjectM engine driven through the VisualCore host | `Harnesses/ProjectMReference` (own `ProjectMReference.yml`, the R1 exception): `ProjectMScene` creates the **unmodified** `ProjectMEngine` with `vcEGLLoadProc`, sizes it from the host drawable, renders into `context.framebuffer`, hands GL state back (`GLState`), releases it in `teardown` with its context current and recreates it per context generation (preset reloaded). Why VisualCore: the EGL lifecycle, pacing, resize, recreation and diagnostics the reference `ANGLERenderer` implements privately are the shared host every app uses; the engine only needs a `RenderScene`. | Before: `F07.pin-d93edd1-*`, path A (reference sequence) frames. After: `F07.t705-projectm-scene` (render, resize, recreation, failed preset, zero size, creation failure), `F07.t708-baseline-a3` + `F07.t711-harness-ios27/26` lockstep A/B (VisualCore within8 97.7–99.0% vs engine's own floor 96.9–99.1%, mean 0.34–0.43; SC-F702 amended to noise-floor relative, `F07.t708-noise-floor`), `F07.t709-lifecycle-stress` (20 suspend/resume, 10 resizes, 3 recreations, leaked 0), harness 17/17 on iOS 27.2 and 26.5, reference `F07.t711-ref-ios27/26` 14/14, `F07.t711-ref-clean` | Reference: none — the shipping app keeps its own `ANGLERenderer` (see Retained). Harness-only: UI preset changes are queued and applied inside the next frame (engine needs its context current). |

**Reference pin moved to `d93edd1` (2026-11-10, ADR-0005).** No VisualCore boundary changed: the only renderer change
(delayed preset warm-up) is ProjectM-specific and stays in the reference. Full reference regression and VisualCore
regression passed at the new pin (`docs/verification/projectm-baseline.md`, section "Pin d93edd1").

### Feature 008 (F07) — before evidence (2026-11-10)

Reference at `d93edd1`, unmodified (`F07.t701-before-reference-clean`). Baseline regression at this pin
(`F07.pin-d93edd1-*`): engine xcframework, projectM-iOS/CaptureLab/RendererLab builds, ANGLERendering 14/14 on
iOS 27.2 and 26.5 (includes `testRendersTheUpstreamTestPreset`, the Phase 0 preset-render check), reference audit
PASS. These are the "before" results for batches 2a and 2; each batch adds its "after" results to its row.

## Retained in ProjectM (deliberately not extracted; FR-F710, archived Phase 7 "do not force extraction")

| ProjectM part (reference) | Why it stays in the submodule |
|---|---|
| `ProjectMBridge` + `ProjectM.xcframework` (engine, MilkDrop/preset evaluation) | The engine is the product the reference ships; its semantics must not change (Phase 7 rule) and its LGPL linkage stays a separate dynamic framework. VisualCore only hosts it (boundary 2). |
| `PresetLibrary` (index, packs, search, exclusions), `ANGLERenderer.prewarm` warm-up scheduling | Tightly coupled to MilkDrop presets and the reference's feature 002 performance work (d93edd1); no other app has presets. |
| Purchases / StoreKit, library unlock (`LibraryStore`, coordinators) | Product- and account-specific; owner-only business boundary. |
| `AudioCore`, `CaptureKit`, `CaptureUI` (microphone, in-app playback, System/App Capture) | Capture claims need 10-minute device diagnostics (CLAUDE.md §5); VisualCore apps get their own `VisualCoreAudio` (F08+) instead of inheriting capture behavior. |
| `CFlashLimiter` | VisualCore has its own host-tested `FlashLimiterModel` + GPU pass (feature 005); the reference keeps its C limiter so the shipping app is unchanged. |
| The reference `ANGLERenderer` EGL lifecycle itself | The shipping app keeps it; VisualCore re-implements the same sequence app-neutrally (boundary 1). Switching the shipping app to VisualCore would be a reference change, which needs an owner decision and a separate reviewed ADR. |
