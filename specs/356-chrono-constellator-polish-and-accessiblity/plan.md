# Implementation Plan: R02-G06-06 — Chrono Constellator: polish and accessibility

**Branch**: `356-chrono-constellator-polish-and-accessiblity` (spec directory only; work on `main`) | **Date**: 2026-11-21 |
**Spec**: [spec.md](spec.md)

## Summary

Polish Chrono Constellator on Colorfall Canyons's feature-346 pattern: `ChronoConstellatorFeedbackPlan` (announcement
kind and text and haptic kind for every change, refusal words, the summary element), `ChronoConstellatorLights` (eased
light levels per target ring, per star node and for the win glow and the collision mark, 0.15 s or 0.45 s under Reduce
Flashing) and `ChronoConstellatorSoundRecipe` (an ambient loop from the stars on target and the stage) in the Core; the
scene geometry draws the eased levels; the presenter routes feedback through the shared `ExperienceFeedback` and keeps a
feedback log; the panel gains labels, values, an adjustable star picker, a summary, Sound and Dynamic Type layout.
Research: [research.md](research.md). Data: [data-model.md](data-model.md). API: [contracts/api.md](contracts/api.md).
Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Audit (2026-11-21)**: `ChronoConstellatorCore` depends on VisualCoreSimulation, Math, Scenes, Experience, Diagnostics
and Persistence; it needs VisualCoreAudioDSP (`AmbientLoopRecipe`) as ColorfallCanyonsCore has; the experience target
needs VisualCoreAudio (`AmbientLoopPlayer`, iOS) and already has VisualCoreExperienceHost (`ExperienceFeedback`).
**Language/Version**: Swift 6, SwiftUI, OpenGL ES 3.0 through ANGLE (shaders unchanged: the field program's shade
carries a ring's eased level, the glow stream's colour a node's level, the win glow scales `u_glowGain` clamped by
`u_glowLimit`). **Primary dependencies**: ChronoConstellatorCore; VisualCoreSimulation (`HapticKind`,
`AnnouncementKind`); VisualCoreAudioDSP; VisualCoreAudio and VisualCoreExperienceHost in the experience. No new package,
target or app change; no Objective-C++.
**Seeds**: tests use seed 2_356 for scripted sequences.
**Testing**: `swift test --package-path Packages/ExperiencesRound02` (Core); the round-two simulator suite on sim-27.2
with recording sinks (VoiceOver forced on through the route's init); regression as in 355; system accessibility audits
wait for device testing.
**Performance**: the plans are O(stars) per action; the lights step at most 5 rings, 5 nodes and 2 marks per frame; the
field and star meshes are rebuilt only while a fade runs; the recipe is built only when the loop is rebuilt.
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
Packages/ExperiencesRound02/Package.swift                                           edit  Core + VisualCoreAudioDSP; Experience + VisualCoreAudio (lead)
Packages/ExperiencesRound02/ChronoConstellator/Core/ChronoConstellatorFeedbackPlan.swift              new   (agent A)
Packages/ExperiencesRound02/ChronoConstellator/Core/ChronoConstellatorLights.swift                    new   (agent B)
Packages/ExperiencesRound02/ChronoConstellator/Core/ChronoConstellatorSoundRecipe.swift               new   (agent B)
Packages/ExperiencesRound02/ChronoConstellator/Core/ChronoConstellatorSceneGeometry.swift             edit  ring, node and mark brightness from lights (lead)
Packages/ExperiencesRound02/ChronoConstellator/CoreTests/ChronoConstellatorFeedbackPlanTests.swift    new   (agent A)
Packages/ExperiencesRound02/ChronoConstellator/CoreTests/{ChronoConstellatorLightsTests, ChronoConstellatorSoundRecipeTests}.swift new (agent B)
Packages/ExperiencesRound02/ChronoConstellator/Experience/ChronoConstellatorSound.swift               new   (lead)
Packages/ExperiencesRound02/ChronoConstellator/Experience/{ChronoConstellatorPresenter, ChronoConstellatorControls, ChronoConstellatorSkyScene}.swift edit (lead)
Packages/ExperiencesRound02/ChronoConstellator/ExperienceTests/ChronoConstellatorAccessibilityTests.swift new (agent C)
docs/architecture/chrono-constellator.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md      edit (lead)
```

**Dependency graph**: package dependency → {feedback plan, lights, recipe} → geometry and presenter wiring → panel →
accessibility tests. **Migration**: none. **Rollback**: revert the commits; no stored data or state changes. **CI**: the
round-two host suite, the script tests and the steering validators run on every push; the simulator suite runs locally.

## Parallel work

The lead adds the package dependencies first; agents A (feedback plan) and B (lights, sound recipe) then work in parallel
against the contract; the lead wires the geometry, presenter, scene, sound and panel; agent C writes the simulator
accessibility tests; the lead runs every check and records only after every agent has reported.
