# Research: Particle Universe Phase 05 — Profiling and low-end device tuning

**Date**: 2026-11-13 · **Spec**: [spec.md](spec.md) · Audit: `Build/agent-notes/A04-P05-audit.md` (re-verified).

## 0. Verified sources (PU = `Packages/ExperiencesCreative/ParticleUniverse`)

| Source | Fact |
|---|---|
| `PU/Core/SceneSimulation.swift:66,81` | `maxStepsPerFrame = 8`; runner with `FixedStepClock(step:maxSteps:)` |
| `Packages/VisualCore/Sources/VisualCoreSimulation/FixedStepClock.swift` | `maxSteps` 1…8, excess to `droppedTime` |
| `Packages/VisualCore/Sources/VisualCoreExperience/ExperienceEngine.swift:121,147,157,202` | `resetAccumulator()` on pause/resume; `resume()`; `advance(frame:) -> Int` (steps taken) |
| `PU/Experience/Adapter/ParticleCore.swift:115-127` | `qualityProfile`, `drawShare(tier:)` 1, 3/4, 1/2, 1/4; `instances(tier:)` |
| `PU/Experience/ParticlePresenter.swift` | `draw(_:tier:context:frame:)` receives the host tier and `FrameInfo` (has `delta`) |
| `Packages/VisualCoreRendering/Sources/VisualCoreExperienceHost/ExperienceSession.swift:137,468,523` | `lastPerformanceRecord`, `performanceRecord`, private `makeRecord` |
| `PU/ExperienceTests/ParticleSessionTests.swift:82-104` | pattern: open, `renderHost?.renderOneFrame(present:)`, `setScenePhase(.background/.active)`, digest |
| `PU/CoreTests/SceneTimeTests.swift` | existing core bound tests |
| `docs/performance/budgets.md` | budgets table (proposal, status, confirmed by) |

## 1. Decisions (clarifications binding)

- **D1 FrameBudgetMonitor** (pure, `PU/Core/FrameBudgetMonitor.swift`): `init(budget: Double = 1/60, maxTier: Int = 3)`;
  `mutating func record(frameTime: Double) -> Int` returns the requested tier (0 = full detail … 3); down rule 25% of
  120 frames over 1.2× budget; up rule 95% of 600 frames under 0.8× budget; both windows restart after a change;
  `mutating func restart()` (pause/background/resume); non-finite or non-positive frame times are ignored.
- **D2 Presenter** (`PU/Experience/ParticlePresenter.swift`): keeps a monitor; in `draw` while the core is playing it
  records `frame.delta` and draws at `max(tier, monitor.tier)`; when paused it restarts the monitor. No action logged.
- **D3 Resume test** (`PU/ExperienceTests/ParticleResumeBoundTests.swift`): through `ExperienceSession`: open, play,
  render a frame, background, active, then advance the experience's engine with a 600 s frame (the experience test seam
  that `ParticleSessionTests` uses, or `ParticleCore`'s engine via the experience shell) and assert ≤ 8 steps; then
  normal frames advance 2 steps per 1/60 s at the 1/120 s step; replay digest equal; paused gap → 0 steps.
- **D4 Profile** (`PU/ExperienceTests/ParticleProfileTests.swift`): scripted session (open, play 120 frames, close),
  print `PROFILE: {"source":"simulator", …record…}`; `docs/performance/budgets.md` gains a "Particle Universe" row.
- **D5** No VisualCore change.
