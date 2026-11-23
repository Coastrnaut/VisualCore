# Implementation Plan: R02-G10-04 — Backwards Aurora: gameplay spatial interaction

**Branch**: `394-backwards-aurora-gameplay-spatial-interaction` (spec directory only; work on `main`) | **Date**:
2026-11-22 | **Spec**: [spec.md](spec.md)

## Summary

Give Backwards Aurora its gestures, following Nocturne Garden's R02-G09-04 in the same package: in the host-tested Core
an orbit (`BackwardsAuroraOrbit`, `camera(_:aspect:orbit:)`), an analytic picker (`BackwardsAuroraPicker`: the touch ray
against the timeline plane, the section's ends with the 22-point minimum target, the band and the sample column under a
point), the freeze preview (`BackwardsAuroraFreezePreview`: the would-be samples of reversing the chosen section with
the kernel's own reversal, its bends above the limit, the seam that would tear and a line in words) and the gesture
controller (`BackwardsAuroraGestureController`: idle, sample press, end drag, band press, swipe, freeze, orbiting,
cancelled; setStart, setEnd, reverse and view reset); the snapshot gains the preview samples, drawn as a pale dashed
copy of the ribbon (a new material code in the aurora program); in the experience the presenter's pointer entry, the
preview while it lasts, and "Reset view" in the panel; host tests with an independent pick, a host test that wins all
100 levels through panel actions, and simulator wiring tests. Research: [research.md](research.md). Data:
[data-model.md](data-model.md). API: [contracts/api.md](contracts/api.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Audit (2026-11-22)**: `Packages/ExperiencesRound02/Package.swift` already has `BackwardsAuroraCore` (with
VisualCoreScenes, VisualCoreMath, VisualCoreExperience), `BackwardsAuroraExperience` (iOS rendering dependencies) and
their test targets (R02-G10-03); `project.yml` links both products into the one app; no new target or scheme is needed.
**Language/Version**: Swift 6, GLSL ES 3.00. **Primary dependencies**: VisualCoreScenes (`PointerEvent`,
`PointerPhase`) and VisualCoreMath (`Vec2`, `Mat4`) as Nocturne Garden's gesture controller uses them; the Backwards
Aurora Core of R02-G10-01 … 03; VisualCoreExperienceHost (pointer events) in the experience. No new package, target,
Objective-C++ or VisualCore API.
**Testing**: host `swift test --package-path Packages/ExperiencesRound02`; simulator package tests on sim-27.2; the app
unit tests; regression; script tests alone. Seed 2_394.
**Constraints**: presentation-only orbit, section and preview; tap distance 10 points, drag distance 16 points, minimum
target 22 points, tap duration 0.5 s, hold 0.5 s and double tap 0.35 s by event timestamps; a swipe needs |dx| ≥ 2·|dy|;
yaw ±35°, pitch −15° … +20°; tests under 10 s.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| II App-neutral API | PASS — game code stays in ExperiencesRound02; VisualCore API unchanged. |
| IV Host-testable | PASS — picking, preview and gestures in the Core with host tests; wiring tested on the simulator. |
| V Implementation before devices | PASS — touch feel and latency are `{device}` tasks. |
| VII Determinism | PASS — only event timestamps are read; actions are sent through the kernel's declared controls. |
| IX Bounded input | PASS — pointer events bounded by the view; orbit clamped; ends clamped; actions validated by the kernel. |
| XI One app | PASS — candidate experience only. |
| XIII Code-driven visuals | PASS — the preview is generated geometry with a shader material. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/ExperiencesRound02/BackwardsAurora/Core/BackwardsAuroraSceneGeometry.swift      edit  orbit, camera(_:aspect:orbit:), preview ribbon (agent B)
Packages/ExperiencesRound02/BackwardsAurora/Core/BackwardsAuroraSceneSnapshot.swift      edit  preview samples (lead)
Packages/ExperiencesRound02/BackwardsAurora/Core/BackwardsAuroraShaders.swift            edit  preview material code 13 (lead)
Packages/ExperiencesRound02/BackwardsAurora/Core/BackwardsAuroraPicker.swift             new   ray, ends, band, sample column (agent B)
Packages/ExperiencesRound02/BackwardsAurora/Core/BackwardsAuroraFreezePreview.swift      new   would-be samples, kinks, tear, words (agent C)
Packages/ExperiencesRound02/BackwardsAurora/Core/BackwardsAuroraGestureController.swift  new   arbitration, taps, end drags, swipes, hold, double taps, orbit (agent C)
Packages/ExperiencesRound02/BackwardsAurora/CoreTests/{BackwardsAuroraPickerTests (B), BackwardsAuroraGestureControllerTests (C), BackwardsAuroraPanelWinTests (D)}.swift  new
Packages/ExperiencesRound02/BackwardsAurora/CoreTests/{BackwardsAuroraSceneGeometryTests, BackwardsAuroraShaderSourceTests}.swift  edit (B; lead)
Packages/ExperiencesRound02/BackwardsAurora/Experience/{BackwardsAuroraPresenter, BackwardsAuroraAuroraScene, BackwardsAuroraControls}.swift  edit (lead)
Packages/ExperiencesRound02/BackwardsAurora/ExperienceTests/BackwardsAuroraGestureWiringTests.swift   new   (agent E)
docs/architecture/backwards-aurora.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md   edit (lead)
```

**Dependency graph**: snapshot preview field and shader code (lead) → orbit, picker and preview ribbon (B) and freeze
preview (C) → gesture controller (C) → presenter wiring → wiring tests (E); the panel win test (D) needs only the
adapter. **CI checks**: the package host tests, the simulator package tests, app-unit, the reference regression and the
script tests, as for R02-G10-03. **Migration**: none (snapshot schema 1; orbit, section and previews are not saved).
**Rollback**: revert the commits; the panel remains a complete control path.

## Parallel work

The lead adds the snapshot's preview field and the shader's preview material first; then agent B (orbit, picker,
preview ribbon), agent C (freeze preview, then the gesture controller on B's picker) and agent D (panel win test) in
parallel; the lead wires the presenter, scene and controls; agent E writes the simulator wiring tests. The lead retests
every result.
