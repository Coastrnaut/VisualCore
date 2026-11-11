# ProjectM boundary migration log

The reference `External/projectm-ios` is read-only (constitution II-a, ADR-0002). "Migrating a boundary"
means VisualCore re-implements that boundary app-neutrally. The reference keeps its own code, and the
unmodified reference build and regression tests are rerun after each boundary.

| # | Date | Boundary | VisualCore implementation | Reference regression after the boundary | Behavior change |
|---|---|---|---|---|---|
| 1 | 2026-11-10 | EGL display/context/surface lifecycle, frame pacing, teardown (`ANGLERenderer` §2–§7) | `VisualCoreRendering.RenderHost`, `EGLDisplayProvider`, `RenderView`, `FrameScheduler`; `VisualCoreDiagnostics.RenderLifecycle`, `FramePacing` (feature 003) | `projectM-iOS` simulator build SUCCEEDED; `ANGLERendering` tests 13/13 on iOS 27.2 and 26.5; reference tree clean (checks `F02.f02-ref-*`) | none in the reference (unchanged); VisualCore adds recreation and explicit states (intentional, render-lifecycle contract) |
| 2a | 2026-11-10 | GPU state and resources coexisting with the engine in one context | `GLState.resetForVisualCore` (VisualCoreRendering, app-neutral: any foreign GL engine may leave VAO/program/blend/cull/scissor/mask/texture-unit/unpack state that VisualCore assumes default) and `RenderContext.redirected` so wrappers capture content that binds `context.framebuffer`; VisualCore `EffectScene` (feature 005) runs over `ProjectMEngine` output. Why VisualCore: every app that embeds third-party GL needs the same handoff; nothing ProjectM-specific. | Before: `F07.pin-d93edd1-*` (reference 14/14 both runtimes). After: `F07.t704-glstate-ios27/26` (negative control + reset), `F07.t706-effectscene-redirect-ios27`, `F07.t706-effects-over-engine` (swap matches channel means ±3, engine keeps rendering, flash limiter bounds steps), `F07.t707-vc-sim-ios26` (50 + 18), reference `F07.t707-ref-ios27/26` 14/14, `F07.t707-ref-clean` | Reference: none (unmodified). VisualCore: `EffectScene` now hands its content a context redirected to the scene target (fixes content that binds `context.framebuffer`); new public `GLState`, `RenderContext.redirected`. |
| 2 | planned (F07) | ProjectM engine driven through the VisualCore host | `Harnesses/ProjectMReference` | to be recorded in F07 | — |

**Reference pin moved to `d93edd1` (2026-11-10, ADR-0005).** No VisualCore boundary changed: the only renderer change
(delayed preset warm-up) is ProjectM-specific and stays in the reference. Full reference regression and VisualCore
regression passed at the new pin (`docs/verification/projectm-baseline.md`, section "Pin d93edd1").

### Feature 008 (F07) — before evidence (2026-11-10)

Reference at `d93edd1`, unmodified (`F07.t701-before-reference-clean`). Baseline regression at this pin
(`F07.pin-d93edd1-*`): engine xcframework, projectM-iOS/CaptureLab/RendererLab builds, ANGLERendering 14/14 on
iOS 27.2 and 26.5 (includes `testRendersTheUpstreamTestPreset`, the Phase 0 preset-render check), reference audit
PASS. These are the "before" results for batches 2a and 2; each batch adds its "after" results to its row.
