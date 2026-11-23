# Implementation Plan: R02-G11-06 — Echo Cartographer: polish and accessibility

**Branch**: `406-echo-cartographer-polish-and-accessiblity` (spec directory only; work on `main`) | **Date**: 2026-11-23
| **Spec**: [spec.md](spec.md)

## Summary

Polish Echo Cartographer on Backwards Aurora's feature-396 pattern: `EchoCartographerFeedbackPlan` (announcement kind
and text and haptic kind for every change, refusal words, the summary element), `EchoCartographerLights` (eased light
levels for the chamber's glow and the won brightening, 0.15 s or 0.45 s under Reduce Flashing) and
`EchoCartographerSoundRecipe` (an ambient loop from the energy left, the beacons located and the stage) in the Core; the
scene draws the eased levels and, under Reduce Flashing, the rings and flares at rest; the presenter routes feedback
through the shared `ExperienceFeedback` and keeps a feedback log; the panel gains labels, values, adjustable column and
row, a summary, Sound and Dynamic Type layout. Research: [research.md](research.md). Data:
[data-model.md](data-model.md). API: [contracts/api.md](contracts/api.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Audit (2026-11-23)**: `EchoCartographerCore` depends on VisualCoreSimulation, Math, Scenes, Experience, Diagnostics
and Persistence; it needs VisualCoreAudioDSP (`AmbientLoopRecipe`) as BackwardsAuroraCore has; the experience target
needs VisualCoreAudioDSP and VisualCoreAudio (`AmbientLoopPlayer`, iOS) and already has VisualCoreExperienceHost
(`ExperienceFeedback`). The chamber shader lifts won walls by `EC_WON_LIFT × v_won` (the won flag in the geometry) and
draws the rings and flares at rest when `u_reduceMotion` is 1; the glow gain is a uniform.
**Language/Version**: Swift 6, SwiftUI, OpenGL ES 3.0 through ANGLE: the glow gain uniform carries the eased glow level,
a new chamber uniform `u_wonLight` scales the won lift, and the scene passes `u_reduceMotion` = 1 under Reduce Motion or
Reduce Flashing, so no fade rebuilds geometry.
**Primary dependencies**: EchoCartographerCore; VisualCoreSimulation (`HapticKind`, `AnnouncementKind`);
VisualCoreAudioDSP; VisualCoreAudio and VisualCoreExperienceHost in the experience. No new package, target or app
change; no Objective-C++.
**Seeds**: tests use seed 2_406 for scripted sequences.
**Testing**: `swift test --package-path Packages/ExperiencesRound02` (Core); the round-two simulator suite on sim-27.2
with recording sinks (VoiceOver forced on through the route's init); regression as in 405; system accessibility audits
wait for device testing.
**Performance**: the plans are O(cells) per action; the lights step two levels per frame; the recipe is built only when
the loop is rebuilt.
**Constraints**: no state, digest or snapshot change (schema 2 stays); presentation only; Reduce Motion and Reduce
Flashing from the host contract.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| II App-neutral API | PASS — game code stays in ExperiencesRound02; VisualCore unchanged. |
| IV Host-testable | PASS — plans, lights and recipe in the Core with host tests; wiring tested on the simulator. |
| V Implementation before devices | PASS — sound, haptics and VoiceOver on hardware are `{device}` tasks. |
| VII Determinism | PASS — presentation only; the state and digest never see lights, sound or feedback. |
| XIII Code-driven visuals and sound | PASS — fades by uniforms; sound synthesized from the recipe. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/ExperiencesRound02/Package.swift                                   edit  Core + VisualCoreAudioDSP; Experience + VisualCoreAudioDSP, VisualCoreAudio (lead)
Packages/ExperiencesRound02/EchoCartographer/Core/EchoCartographerFeedbackPlan.swift       new   (agent A)
Packages/ExperiencesRound02/EchoCartographer/Core/EchoCartographerLights.swift             new   (agent B)
Packages/ExperiencesRound02/EchoCartographer/Core/EchoCartographerSoundRecipe.swift        new   (agent B)
Packages/ExperiencesRound02/EchoCartographer/Core/EchoCartographerShaders.swift            edit  u_wonLight (lead)
Packages/ExperiencesRound02/EchoCartographer/CoreTests/EchoCartographerFeedbackPlanTests.swift                           new  (agent A)
Packages/ExperiencesRound02/EchoCartographer/CoreTests/{EchoCartographerLightsTests, EchoCartographerSoundRecipeTests}.swift  new (agent B)
Packages/ExperiencesRound02/EchoCartographer/CoreTests/{EchoCartographerInvariantTests, EchoCartographerShaderSourceTests}.swift  edit (lead)
Packages/ExperiencesRound02/EchoCartographer/Experience/EchoCartographerSound.swift        new   (lead)
Packages/ExperiencesRound02/EchoCartographer/Experience/{EchoCartographerPresenter, EchoCartographerControls, EchoCartographerChamberScene}.swift  edit (lead)
Packages/ExperiencesRound02/EchoCartographer/ExperienceTests/EchoCartographerAccessibilityTests.swift                    new (agent C)
docs/architecture/echo-cartographer.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md       edit (lead)
```

**Dependency graph**: package dependency → {feedback plan, lights, recipe} → shader and presenter wiring → panel →
accessibility tests. **Migration**: none. **Rollback**: revert the commits; no stored data or state changes. **CI**: the
round-two host suite, the script tests and the steering validators run on every push; the simulator suite runs locally.

## Parallel work

The lead adds the package dependencies first; agents A (feedback plan) and B (lights, sound recipe) then work in
parallel against the contract; the lead wires the shader, presenter, scene, sound and panel; agent C writes the
simulator accessibility tests; the lead runs every check and records only after every agent has reported.
