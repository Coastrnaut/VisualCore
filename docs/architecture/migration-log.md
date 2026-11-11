# ProjectM boundary migration log

The reference `External/projectm-ios` is read-only (constitution II-a, ADR-0002). "Migrating a boundary"
means VisualCore re-implements that boundary app-neutrally. The reference keeps its own code, and the
unmodified reference build and regression tests are rerun after each boundary.

| # | Date | Boundary | VisualCore implementation | Reference regression after the boundary | Behavior change |
|---|---|---|---|---|---|
| 1 | 2026-11-10 | EGL display/context/surface lifecycle, frame pacing, teardown (`ANGLERenderer` §2–§7) | `VisualCoreRendering.RenderHost`, `EGLDisplayProvider`, `RenderView`, `FrameScheduler`; `VisualCoreDiagnostics.RenderLifecycle`, `FramePacing` (feature 003) | `projectM-iOS` simulator build SUCCEEDED; `ANGLERendering` tests 13/13 on iOS 27.2 and 26.5; reference tree clean (checks `F02.f02-ref-*`) | none in the reference (unchanged); VisualCore adds recreation and explicit states (intentional, render-lifecycle contract) |
| 2a | planned (F07) | GPU resources/shaders coexisting with the engine in one context | VisualCore `ResourceRegistry`/`ShaderProgram` (feature 004) used by the harness scene alongside `ProjectMEngine`, whose own shaders and presets stay unchanged | harness pixel check + reference `ANGLERendering` 13/13 | — |
| 2 | planned (F07) | ProjectM engine driven through the VisualCore host | `Harnesses/ProjectMReference` | to be recorded in F07 | — |

**Reference pin moved to `d93edd1` (2026-11-10, ADR-0005).** No VisualCore boundary changed: the only renderer change
(delayed preset warm-up) is ProjectM-specific and stays in the reference. Full reference regression and VisualCore
regression passed at the new pin (`docs/verification/projectm-baseline.md`, section "Pin d93edd1").

### Feature 008 (F07) — before evidence (2026-11-10)

Reference at `d93edd1`, unmodified (`F07.t701-before-reference-clean`). Baseline regression at this pin
(`F07.pin-d93edd1-*`): engine xcframework, projectM-iOS/CaptureLab/RendererLab builds, ANGLERendering 14/14 on
iOS 27.2 and 26.5 (includes `testRendersTheUpstreamTestPreset`, the Phase 0 preset-render check), reference audit
PASS. These are the "before" results for batches 2a and 2; each batch adds its "after" results to its row.
