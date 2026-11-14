# Research: A06-P05

- **D1 Quality levels.** `AnalysisQuality.configuration(level:) -> (size: Int, bandCount: Int)` with clamping;
  `makeExtractor(level:sampleRate:)`. Rationale: one place for the budget; halving the window halves FFT cost.
- **D2 Timing.** `ContinuousClock` around 500 `analyze(into:)` calls after 10 warm-up calls; assert < 0.5 ms mean unless
  `ProcessInfo.processInfo.environment["CI"]` is set (repository rule: no wall-clock asserts on CI).
- **D3 Metric text.** Pure `MetricText.make(rmsDB:regionEnergies:beat:)` in Core (plain Floats; regions from the four
  band groups); "−" (U+2212) sign; silent at ≤ −90 dBFS.
- **D4 Announcement gate.** Core `AnnouncementGate` (minimum interval 2 s, last text, last time); `shouldAnnounce(text:
  at:) -> Bool`; the presenter calls the sink only when VoiceOver is running.
- **D5 Palettes.** Core `MusicLabPalette` (Aurora, Ember, Mono) with RGBA colours as Doubles for bar, wave, level, peak,
  beat, sphere, cube; the presenter reads them each frame (no rebuild).
- **D6 Actions.** `palette.select [0…2]`; `preset.apply [scene, f0, g0, f1, g1, f2, g2, palette]`.
- **D7 Transitions fixture.** Experience test with the resumable double from A06-P04 (`MusicLabRecoveryTests` pattern)
  driving states, posting `UIApplication.didEnterBackgroundNotification`/`willEnterForegroundNotification`, rendering a
  frame after each step, then closing and checking `hostsAlive == 0` and the double stopped.
- **D8 Contract.** G-AUDIOBUDGET closed (M27 available: `AnalysisQuality`); G-A11YMETRICS closed app-local (M23 available:
  `MetricText`, `AnnouncementGate`); G-SIGNALTEXTURE closed as adapted (M18 available: `PrimitiveRenderer`,
  `MeshRenderer`, `AudioMapper`).
