# Implementation Plan: Ambient Clock — Phase 04 Power and visibility controls

**Branch**: `134-ac-p04-power-visibility` (spec directory only; work on `main`) | **Date**: 2026-11-16 | **Spec**: [spec.md](spec.md)

## Summary

This phase builds five gaps:
- **G-FRAMERATE (VisualCoreExperienceHost):** an additive `ExperiencePresenter.maxFramesPerSecond` (default 60),
  passed by `ExperienceSession` to `RenderHost`. Ambient Clock declares 30.
- **G-NIGHT:** `NightPolicy` (core), the night tint and dim in every theme, and the warm night text with its contrast
  check.
- **G-MOTION:** the in-app reduce-motion option combined with the system setting.
- **G-SCREENCARE:** `ScreenCare` (core) with the drift and the idle dim.
- **G-AWAKE:** `KeepAwake.swift` (`IdleTimerPort`, `ApplicationIdleTimer`), driven by the presenter's visibility.
- **Snapshot:** schema 3 with five controls, the migration 2 → 3 and the examples.

Research: [research.md](research.md). Data: [data-model.md](data-model.md). Contract: [contracts/power.md](contracts/power.md).
Quickstart: [quickstart.md](quickstart.md).

## Technical Context

- **Language:** Swift 6. **Dependencies:** VisualCoreExperienceHost (the presenter protocol and the session),
  VisualCoreRendering (`RenderHost`), VisualCoreDiagnostics (`FramePacing`), the A18 targets and UIKit (idle timer
  only in `KeepAwake.swift`).
- **Testing:**
  - `VisualCoreExperienceHostTests` (a frame cap test) on sim-27.2;
  - `AmbientClockCoreTests` and `AmbientClockExperienceTests` on sim-27.2;
  - the public and documented API, the runner, the app build and the unit tests.
- **Constraints:** tests under 10 s; no wall-clock assert (fixed clocks); the reference regression at X-A18. No NEEDS
  CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| I, III | PASS: the host keeps context ownership; the cap goes through `RenderHost` |
| II-a VisualCore change | PASS: additive protocol requirement with a default; other experiences unchanged; `///`, tests, the API baseline, a README row; the reference regression at X-A18 |
| IV Pure core | PASS: `NightPolicy` and `ScreenCare` are pure and take the instant and local minute as input |
| V Persistence | PASS: schema 3 with a migration and registered examples |
| VIII Privacy | PASS: keep-awake is opt-in and off by default, in one named file; no brightness write |
| IX Accessibility | PASS: the in-app reduce motion, still drift, night contrast ≥ 4.5 : 1 |

The A18 rules pass. The system brightness is never set, and keep-awake is opt-in. Post-design: PASS.

## Project Structure

```text
Packages/VisualCoreRendering/Sources/VisualCoreExperienceHost/{ExperiencePresenter,ExperienceSession}.swift   modify
Packages/VisualCoreRendering/Tests/VisualCoreExperienceHostTests/FrameCapTests.swift                       new
Packages/VisualCoreRendering/README.md, docs/api/visualcore-public-api.txt                                 modify
Packages/ExperiencesCreative/AmbientClock/Core/{NightPolicy,ScreenCare}.swift                              new
Packages/ExperiencesCreative/AmbientClock/CoreTests/{NightPolicyTests,ScreenCareTests}.swift               new
Packages/ExperiencesCreative/AmbientClock/Experience/KeepAwake.swift                                       new
Packages/ExperiencesCreative/AmbientClock/Experience/{Adapter/AmbientCore,AmbientSchemaExamples,AmbientPresenter,
  ThemeShaders,ClockOverlay,AmbientControls,Adapter/AmbientManifest}.swift                                 modify
Packages/ExperiencesCreative/AmbientClock/ExperienceTests/{NightRenderTests,KeepAwakeTests,ResumeTests,
  SourceScanTests,PowerCoreTests}.swift                                                                    new
Packages/ExperiencesCreative/AmbientClock/scenario-manifest.json                                          regenerated
Apps/VisualCore/App/ExperienceRegistry.swift (schema-2 example added)                                      modify
docs/apps/ambient-clock/visualcore-contract.json (five gaps closed)                                        modify
```

- **Dependency direction:** as before. `KeepAwake.swift` is the only experience file that touches `UIApplication`'s
  idle timer.
- **Lifecycle:**
  - The idle timer is on only while the setting is on and the clock is visible: set at setup or `didBecomeActive`, and
    released at `willResignActive`, `didEnterBackground`, teardown and when the setting goes off.
  - Drift and dim are computed per frame from the clock's instant.
  - The night state is computed from the local minute of the display environment.
- **Migration:** snapshot 2 → 3 with the defaults.
- **Rollback:** revert. The protocol default keeps every other experience at 60.

## Parallel work

- **Agent V:** the host frame cap and its test.
- **Agent C:** `NightPolicy` and `ScreenCare` with their tests.
- **Agent E:** the experience sources.
- **Agent T:** the experience tests.
- **Lead:** README, API baseline, registry, manifest, contract, runs and commits.
