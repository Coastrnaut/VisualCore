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

## 2. Analysis record (`/speckit-analyze`, 2026-11-13)

Round 1: 0 critical, 0 high, 2 medium (C1 ceiling wins, C2 paused frames not counted — both added to T-A04-506), 1 low
(new session starts fresh by construction). Round 2: clean; 17 of 17 requirements and 6 of 6 success criteria covered.

## D7 — The frame budget from the host's target timestamps (T-A04-516, converge round 1)

- **Decision:** the monitor's budget is the display interval estimated by `FrameIntervalEstimate`
  (`ParticleUniverse/Core/FrameBudgetMonitor.swift`): the smallest step between the target presentation times of
  consecutive frames since setup, accepting steps of 1/240 s to 0.1 s. Until a step is seen the budget is 1/60 s.
  When the estimate differs from the budget by more than 10%, the presenter rebuilds the monitor for the new budget at
  the same tier (`FrameBudgetMonitor(budget:maxTier:tier:)`); the estimate resets on setup and teardown.
- **Rationale:** the task text named `targetTimestamp − time`, but `FrameInfo.time` counts seconds since the host
  started while `targetTimestamp` is a media-clock reading, so their difference is not an interval. Steps between
  consecutive targets are whole multiples of the display interval (a late frame skips whole intervals), so their
  minimum is the interval and slow frames cannot inflate the budget. No VisualCore change (FR-A04-540).
- **Alternatives:** a median of recent steps (a run of late frames doubles it and hides the slowness); a new
  `FrameInfo` field for the link duration (a VisualCore change, out of scope).
