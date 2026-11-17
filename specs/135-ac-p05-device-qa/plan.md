# Implementation Plan: Ambient Clock — Phase 05 Overnight device tests and App Store QA

**Branch**: `135-ac-p05-device-qa` (spec directory only; work on `main`) | **Date**: 2026-11-16 | **Spec**: [spec.md](spec.md)

## Summary

This phase builds G-DEVICE and the manual's regression fixture:
- **The fixture:** the additive VisualCoreRendering `CachedScene` redraws its child only when its key changes. The
  presenter keys the picture when it is still and passes it through while it moves.
- **G-DEVICE:** `docs/apps/ambient-clock/device-campaign.md` with rows AC-D1 to AC-D10, all {device} and pending.
- **The MVP check:** interface tests `ACPowerUITests` in a new serial chunk `z2`.

Research: [research.md](research.md). Data: [data-model.md](data-model.md). Contract: [contracts/qa.md](contracts/qa.md).
Quickstart: [quickstart.md](quickstart.md).

## Technical Context

- **Language:** Swift 6. **Dependencies:** VisualCoreRendering (`RenderTarget`, `ResourceRegistry`, `RenderContext`),
  the A18 experience, XCTest for the interface tests.
- **Testing:**
  - `VisualCoreRenderingTests/CachedSceneTests` on sim-27.2;
  - `AmbientClockExperienceTests` on sim-27.2;
  - the app build, unit tests and interface chunk `z2` on the iOS 27.2 phone.
- **Constraints:** interface tests under 60 s, others under 10 s. No device action, and no audit (`VC_RUN_AUDITS`
  waits for devices). The reference regression at X-A18. No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| I, III | PASS: the cache lives in VisualCoreRendering; the experience calls no graphics API |
| II-a VisualCore change | PASS: additive scene with `///` docs, tests, the API baseline, a README row; the reference regression at X-A18 |
| VI Tests | PASS: draw counts, identical frames, rebuild on resize and recreation; interface tests |
| VII Devices | PASS: campaign rows only, all pending |
| VIII Privacy | PASS: unchanged |

The A18 rules pass: no number is claimed before the campaign. Post-design: PASS.

## Project Structure

```text
Packages/VisualCoreRendering/Sources/VisualCoreRendering/CachedScene.swift                     new
Packages/VisualCoreRendering/Tests/VisualCoreRenderingTests/CachedSceneTests.swift             new
Packages/VisualCoreRendering/README.md, docs/api/visualcore-public-api.txt                     modify
Packages/ExperiencesCreative/AmbientClock/Experience/AmbientPresenter.swift                    modify (cache key, still rule)
Packages/ExperiencesCreative/AmbientClock/ExperienceTests/StillWorkTests.swift                  new
Apps/VisualCore/Tests/UI/AmbientClock/{ACSupport,ACPowerUITests}.swift                         new
scripts/release_check.py (serial chunk z2)                                                     modify
docs/apps/ambient-clock/device-campaign.md                                                     new
docs/apps/ambient-clock/visualcore-contract.json (G-DEVICE closed)                             modify
```

- **Lifecycle:**
  - `CachedScene` makes its target lazily, remakes it on resize, forgets it after a context loss and redraws then.
  - Teardown releases it.
  - The presenter's crossfade (A18-P03) stays the child, so the order is cache → crossfade → theme.
- **Migration:** none.
- **Rollback:** revert. The scene is additive.

## Parallel work

- **Agent V:** `CachedScene` and its tests.
- **Agent E:** the presenter change and `StillWorkTests`.
- **Agent U:** the interface tests.
- **Lead:** the campaign document, `release_check.py`, the README, the API baseline, the contract, the runs and the
  commits.
