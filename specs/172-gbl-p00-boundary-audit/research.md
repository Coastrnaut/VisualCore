# Research: A24-P00 (feature 172)

- **D1 What VisualCore offers (survey, spot-checked):**
  - **Frames:** `FrameInfo` (index, time, clamped delta, target timestamp), `PresentedFrame`, present observers,
    `ExperiencePresenter.maxFramesPerSecond`.
  - **Diagnostics:** `PacingMeter` and `PacingSummary` (binned), `PerformanceRecord`, `GrowthRule`,
    `ResourceRegistry.stats`, `ResourceBudget`, `ResourceLedger`, `RenderLifecycle`, `ProcessMemory.footprint()`.
  - **Conditions and quality:** `DeviceConditions`, `FramePacing`, `QualityProfile`, `QualityLevel`.
  - **Renderer:** `RenderCapabilities` on `RenderHost.capabilities`; `RendererRecord`.
  - **Workloads:** `FullScreenShaderScene`, `FieldPass`, `ParticleRenderer`, `ParticleSystem`, `Texture.upload`,
    render targets, off-screen rendering and read-back.
  - **Persistence:** `ExperienceStorage`, `MigrationChain`, `DocumentStore`, `NamedLibrary`.
- **D2 What it lacks:** a GPU timer, the renderer's facts for presenters, a public device and build reporter, run-time
  ANGLE build, display refresh rate, statistics over raw samples, CSV, a shared export helper, a textured-quad helper,
  procedural textures, a phase runner and any benchmark scene.
- **D3 Traceability:** the five brainstorm capabilities (GPU timing, diagnostics, profiling, benchmark scenes, device
  and configuration reporting) and the six version 0.1 features (baseline scenes; warm-up, measurement and cool-down;
  frame-time percentiles, CPU submit time and optional GPU timer; device and context report; JSON or CSV export;
  explanation of limits) each map to matrix rows.
- **D4 Phase plan of the gaps (manual §9):**

  | Gap | Phase |
  |---|---|
  | G-MODEL (case, run, sample, summary), G-STATS (percentiles over raw samples) | A24-P01 |
  | G-SCENES (textured quads, ALU stress, particles) | A24-P02 |
  | G-RUNNER (phases, caps, stop, frame and CPU time), G-REPORT (device report), U-RENDERINFO, U-GPUTIMER | A24-P03 |
  | G-RESULTS (stored results), G-EXPORT (JSON and CSV) | A24-P04 |
  | G-DEVICE (repeatability, thermal context, the device plan), G-EXPLAIN (limits and variability) | A24-P05 |
  | G-RELEASE | A24-P06 |
- **D5 Numbers later:** no benchmark number is set or published; caps (duration, draw and particle counts, texture
  sizes) are set in A24-P02 and A24-P03 as bounds, not targets.
- **D6 Rejected:**
  - reusing `PacingMeter` for results (it rounds to 0.25 ms bins and hides its percentile);
  - the debug-only `AutomationRunner` device reader (absent in release builds);
  - linking the internal GL shim from the experience to reach timer queries or extension strings (it is no product
    and would bypass the host).
