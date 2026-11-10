# ProjectM boundary migration log

The reference `External/projectm-ios` is read-only (constitution II-a, ADR-0002). "Migrating a boundary"
means VisualCore re-implements that boundary app-neutrally. The reference keeps its own code, and the
unmodified reference build and regression tests are rerun after each boundary.

| # | Date | Boundary | VisualCore implementation | Reference regression after the boundary | Behavior change |
|---|---|---|---|---|---|
| 1 | 2026-11-10 | EGL display/context/surface lifecycle, frame pacing, teardown (`ANGLERenderer` §2–§7) | `VisualCoreRendering.RenderHost`, `EGLDisplayProvider`, `RenderView`, `FrameScheduler`; `VisualCoreDiagnostics.RenderLifecycle`, `FramePacing` (feature 003) | `projectM-iOS` simulator build SUCCEEDED; `ANGLERendering` tests 13/13 on iOS 27.2 and 26.5; reference tree clean (checks `F02.f02-ref-*`) | none in the reference (unchanged); VisualCore adds recreation and explicit states (intentional, render-lifecycle contract) |
| 2 | planned (F07) | ProjectM engine driven through the VisualCore host | `Harnesses/ProjectMReference` | to be recorded in F07 | — |
