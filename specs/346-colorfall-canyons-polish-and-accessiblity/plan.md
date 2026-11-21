# Implementation Plan: R02-G05-06 — Colorfall Canyons: polish and accessibility

**Branch**: `346-colorfall-canyons-polish-and-accessiblity` (spec directory only; work on `main`) | **Date**: 2026-11-21 |
**Spec**: [spec.md](spec.md)

## Summary

Polish Colorfall Canyons for every player, following feature 336. In the host-tested `ColorfallCanyonsCore`, three pure
presentation helpers that never touch state: `ColorfallCanyonsFeedbackPlan` (announcement text and kind and the haptic
kind for a change from one core to the next, a cell pick or a refusal, plus the summary element's words),
`ColorfallCanyonsLights` (eased light levels of every fluid sheet, every spring emitter and the win glow, 0.15 s normally
and 0.45 s under Reduce Flashing, finishing a started fade before turning back, with a flash-rate measure; a sheet whose
cell empties fades out in its last colour) and `ColorfallCanyonsSoundRecipe` (an `AmbientLoopRecipe` from the basins'
colour mass and the stage). The scene geometry's fluid and feature parts take the eased levels (a sheet's brightness and
an emitter's brightness from the lights; fading sheets kept with their remembered colour weights); the win glow scales
the fluid glow gain, never above the Reduce Flashing limit. In the iOS `ColorfallCanyonsExperience`: the presenter
routes the plans to the shared feedback route (`feedback`, injectable), keeps a feedback log, passes the eased lights to
the scene, and owns a `ColorfallCanyonsSound` that plays the ambient loop while wanted, on screen and active; the panel
scrolls, grows with Dynamic Type, wraps its button rows, keeps a 520-point readable width on iPad, labels every control,
adds a summary element, shows refusals in words and adds a Sound toggle. Research: [research.md](research.md). Data:
[data-model.md](data-model.md). API: [contracts/api.md](contracts/api.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Swift 6, SwiftUI, OpenGL ES 3.0 through ANGLE (shaders unchanged: the fluid stream's brightness
carries the eased level; the win glow scales `u_glowGain`, clamped by `u_glowLimit`). **Primary dependencies**:
ColorfallCanyonsCore; VisualCoreSimulation (`HapticKind`, `AnnouncementKind`); VisualCoreAudioDSP (`AmbientLoopRecipe`,
`AmbientLoopPartial`) — a new product dependency of ColorfallCanyonsCore, as for HueCompassCore; VisualCoreAudio
(`AmbientLoopPlayer`) and VisualCoreExperienceHost (`ExperienceFeedback`) for the iOS experience. No new package, target
or app change; no Objective-C++.
**Seeds**: tests use seed 2_346 for scripted sequences.
**Testing**: `swift test --package-path Packages/ExperiencesRound02` (Core); the round-two simulator suite on sim-27.2
with recording sinks (VoiceOver forced on through the route's init); regression as in 345; system accessibility audits
wait for device testing.
**Performance**: the plans are O(basins) per action; the lights step one level per cell (at most 120) and per spring plus
the glow per frame; the fluid and feature meshes are rebuilt only while a fade runs; the recipe is built only when the
loop is rebuilt.
**Constraints**: no state, digest or snapshot change (schema 2 stays); presentation only; Reduce Motion and Reduce
Flashing from the host contract.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| I Proven renderer only | PASS — same scene and shaders; lights feed existing geometry streams and uniforms. |
| II App-neutral API | PASS — game code stays in ExperiencesRound02; shared routes reused, not changed. |
| IV Host-testable | PASS — plans, lights and recipe are pure Core types with host tests. |
| V Implementation before devices | PASS — sound, haptics and VoiceOver on hardware wait for D1–D3. |
| VI Evidence Over Assertion | PASS — announcements, haptics and fades proven by recorded sinks and measured levels. |
| VII Native, Accessible UI | PASS — labels, values, adjustable picker, summary, announcements, Dynamic Type, contrast, reduced motion and flashing. |
| IX Bounded input | PASS — rate limits from the shared planners; no unbounded queue. |
| X Licensing and provenance | PASS — all text original; sound synthesized. |
| XII One purchase, no advertising | PASS — free; no store code. |
| XIII Code-driven visuals | PASS — no assets. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/ExperiencesRound02/Package.swift                                                          edit  ColorfallCanyonsCore + VisualCoreAudioDSP (lead)
Packages/ExperiencesRound02/ColorfallCanyons/Core/ColorfallCanyonsFeedbackPlan.swift               new   (agent A)
Packages/ExperiencesRound02/ColorfallCanyons/Core/ColorfallCanyonsLights.swift                     new   (agent B)
Packages/ExperiencesRound02/ColorfallCanyons/Core/ColorfallCanyonsSoundRecipe.swift                new   (agent B)
Packages/ExperiencesRound02/ColorfallCanyons/Core/ColorfallCanyonsSceneGeometry.swift              edit  fluid and emitter brightness from lights (lead)
Packages/ExperiencesRound02/ColorfallCanyons/CoreTests/ColorfallCanyonsFeedbackPlanTests.swift     new   (agent A)
Packages/ExperiencesRound02/ColorfallCanyons/CoreTests/{ColorfallCanyonsLightsTests, ColorfallCanyonsSoundRecipeTests}.swift new (agent B)
Packages/ExperiencesRound02/ColorfallCanyons/Experience/ColorfallCanyonsSound.swift                new   (lead)
Packages/ExperiencesRound02/ColorfallCanyons/Experience/{ColorfallCanyonsPresenter, ColorfallCanyonsControls, ColorfallCanyonsCanyonScene}.swift edit (lead)
Packages/ExperiencesRound02/ColorfallCanyons/ExperienceTests/ColorfallCanyonsAccessibilityTests.swift new (agent C)
project.yml                                                                                        edit  only if the app's package product list needs VisualCoreAudio (lead checks)
docs/architecture/colorfall-canyons.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md                  edit (lead)
```

**Migration**: none. **Rollback**: revert the commits; no stored data or state changes. **CI**: the round-two host
suite (`swift test`), the script tests and the steering validators run on every push; the simulator suite runs locally.

## Parallel work

The lead adds the package dependency first; agents A (feedback plan) and B (lights, sound recipe) then work in parallel
against the contract; the lead wires the geometry, presenter, scene, sound and panel; agent C writes the simulator
accessibility tests; the lead runs every check and records only after every agent has reported.
