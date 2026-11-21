# Implementation Plan: R02-G04-06 — Hue Compass: polish and accessibility

**Branch**: `336-hue-compass-polish-and-accessiblity` (spec directory only; work on `main`) | **Date**: 2026-11-21 |
**Spec**: [spec.md](spec.md)

## Summary

Polish Hue Compass for every player, following feature 326. In the host-tested `HueCompassCore`, three pure presentation
helpers that never touch state: `HueCompassFeedbackPlan` (announcement text and kind and the haptic kind for a change
from one core to the next, a band pick or a refusal), `HueCompassLights` (eased light levels of the probe marks, the
selection mark, the target ring and the win glow, 0.15 s normally and 0.45 s under Reduce Flashing, finishing a started
fade before turning back, with a flash-rate measure; a mark that disappears fades out where it last was) and
`HueCompassSoundRecipe` (an `AmbientLoopRecipe` from the last clue and the stage). The scene geometry's mark part takes
the eased levels (each mark's size scaled by its level; fading marks kept at their remembered bearing); the win glow
scales the needle glow gain, never above the Reduce Flashing cap. In the iOS `HueCompassExperience`: the presenter routes
the plans to the shared feedback route (`feedback`, injectable), keeps a feedback log, passes the eased lights to the
scene, and owns a `HueCompassSound` that plays the ambient loop while wanted, on screen and active; the panel scrolls,
grows with Dynamic Type, wraps its button rows, keeps a 520-point readable width on iPad, labels every control, adds a
summary element, shows refusals in words and adds a Sound toggle. Research: [research.md](research.md). Data:
[data-model.md](data-model.md). API: [contracts/api.md](contracts/api.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Swift 6, SwiftUI, OpenGL ES 3.0 through ANGLE (shaders unchanged: mark size carries the level;
the win glow scales `u_gain` of the glow shells, clamped by `u_gainLimit`). **Primary dependencies**: HueCompassCore;
VisualCoreSimulation (`HapticKind`, `AnnouncementKind`); VisualCoreAudioDSP (`AmbientLoopRecipe`,
`AmbientLoopPartial`) — a new product dependency of HueCompassCore; VisualCoreAudio (`AmbientLoopPlayer`) and
VisualCoreExperienceHost (`ExperienceFeedback`) for the iOS experience. No new package, target or app change.
**Seeds**: tests use seed 2_336 for scripted sequences.
**Testing**: `swift test --package-path Packages/ExperiencesRound02` (Core); the round-two simulator suite on sim-27.2
with recording sinks (VoiceOver forced on through the route's init); regression as in 335; system accessibility audits
wait for device testing.
**Performance**: the plans are O(1) per action; the lights step at most one level per probe mark (at most 24 probes)
plus three per frame; the mark mesh is rebuilt only while a fade runs; the recipe is built only when the loop is rebuilt.
**Constraints**: no state, digest or snapshot change (schema 2 stays); presentation only; Reduce Motion and Reduce
Flashing from the host contract.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| I Proven renderer only | PASS — same scene and shaders; lights feed existing geometry and uniforms. |
| II App-neutral API | PASS — game code stays in ExperiencesRound02; shared routes reused, not changed. |
| IV Host-testable | PASS — plans, lights and recipe are pure Core types with host tests. |
| V Implementation before devices | PASS — sound, haptics and VoiceOver on hardware wait for D1–D3. |
| VI Evidence Over Assertion | PASS — announcements, haptics and fades proven by recorded sinks and measured levels. |
| VII Native, Accessible UI | PASS — labels, values, adjustable stepper, summary, announcements, Dynamic Type, contrast, reduced motion and flashing. |
| IX Bounded input | PASS — rate limits from the shared planners; no unbounded queue. |
| X Licensing and provenance | PASS — all text original; sound synthesized. |
| XII One purchase, no advertising | PASS — free; no store code. |
| XIII Code-driven visuals | PASS — no assets. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/ExperiencesRound02/Package.swift                                              edit  HueCompassCore + VisualCoreAudioDSP (lead)
Packages/ExperiencesRound02/HueCompass/Core/HueCompassFeedbackPlan.swift               new   (agent A)
Packages/ExperiencesRound02/HueCompass/Core/HueCompassLights.swift                     new   (agent B)
Packages/ExperiencesRound02/HueCompass/Core/HueCompassSoundRecipe.swift                new   (agent B)
Packages/ExperiencesRound02/HueCompass/Core/HueCompassSceneGeometry.swift              edit  mark sizes from lights (lead)
Packages/ExperiencesRound02/HueCompass/CoreTests/HueCompassFeedbackPlanTests.swift     new   (agent A)
Packages/ExperiencesRound02/HueCompass/CoreTests/{HueCompassLightsTests, HueCompassSoundRecipeTests}.swift new (agent B)
Packages/ExperiencesRound02/HueCompass/Experience/HueCompassSound.swift                new   (lead)
Packages/ExperiencesRound02/HueCompass/Experience/{HueCompassPresenter, HueCompassControls, HueCompassCompassScene}.swift edit (lead)
Packages/ExperiencesRound02/HueCompass/ExperienceTests/HueCompassAccessibilityTests.swift new (agent C)
docs/architecture/hue-compass.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md                  edit (lead)
```

**Migration**: none. **Rollback**: revert the commits; no stored data or state changes. **CI**: the round-two host
suite (`swift test`), the script tests and the steering validators run on every push; the simulator suite runs locally.

## Parallel work

The lead adds the package dependency first; agents A (feedback plan) and B (lights, sound recipe) then work in parallel
against the contract; the lead wires the geometry, presenter, scene, sound and panel; agent C writes the simulator
accessibility tests; the lead runs every check and records only after every agent has reported.
