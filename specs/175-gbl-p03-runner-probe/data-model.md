# Data Model: A24-P03 (feature 175)

- **ResourceRegistry.renderCapabilities** (VisualCoreRendering): `RenderCapabilities`, the current generation's.
- **GPUFrameTimer** (VisualCoreRendering): ring of 4 query names, the generation, pending frames; `poll()` →
  `[GPUFrameTime]` (`frame: Int`, `milliseconds: Double`); `disjointCount`.
- **TimerProbe** (core): `decide(extensions:) -> TimerSupport` (`supported` | `unsupported(reason)`), extension name
  `GL_EXT_disjoint_timer_query`.
- **DroppedFrameRule** (core): `periodMs` = 1,000 / 60, `factor` = 1.5; `isDropped(intervalMs:)`.
- **RunReport** (core): the fields of clarification Q5; validation: every string 1…128 characters, booleans, the
  thermal states as `FramePacing.Thermal` raw values, timing sources from a fixed set.
- **Run file:** version 2, body `{case, report, samples, state, summary}`; version 1 migrates with `report: null`.
