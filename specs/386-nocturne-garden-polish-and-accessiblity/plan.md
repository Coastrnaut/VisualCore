# Implementation Plan: R02-G09-06 — Nocturne Garden: polish and accessibility

**Branch**: `386-nocturne-garden-polish-and-accessiblity` (spec directory only; work on `main`) | **Date**: 2026-11-22
| **Spec**: [spec.md](spec.md)

## Summary

Polish Nocturne Garden on Faceted Forge's feature-376 pattern: `NocturneGardenFeedbackPlan` (announcement kind and text
and haptic kind for every change, refusal words, the summary element), `NocturneGardenLights` (eased light levels for
the blooms' glow and the leak crosses, 0.15 s or 0.45 s under Reduce Flashing) and `NocturneGardenSoundRecipe` (an
ambient loop from the blooms, the sun and the stage) in the Core; the scene draws the eased levels; the presenter routes
feedback through the shared `ExperienceFeedback` and keeps a feedback log; the panel gains labels, values, adjustable
pickers, a summary, Sound and Dynamic Type layout. Research: [research.md](research.md). Data:
[data-model.md](data-model.md). API: [contracts/api.md](contracts/api.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Audit (2026-11-22)**: `NocturneGardenCore` depends on VisualCoreSimulation, Math, Scenes, Experience, Diagnostics and
Persistence; it needs VisualCoreAudioDSP (`AmbientLoopRecipe`) as FacetedForgeCore has; the experience target needs
VisualCoreAudio (`AmbientLoopPlayer`, iOS) and already has VisualCoreExperienceHost (`ExperienceFeedback`).
**Language/Version**: Swift 6, SwiftUI, OpenGL ES 3.0 through ANGLE (shaders unchanged: the glow gain uniform carries
the eased glow level, the leak cross's shade its eased level).
**Primary dependencies**: NocturneGardenCore; VisualCoreSimulation (`HapticKind`, `AnnouncementKind`);
VisualCoreAudioDSP; VisualCoreAudio and VisualCoreExperienceHost in the experience. No new package, target or app
change; no Objective-C++.
**Seeds**: tests use seed 2_386 for scripted sequences.
**Testing**: `swift test --package-path Packages/ExperiencesRound02` (Core); the round-two simulator suite on sim-27.2
with recording sinks (VoiceOver forced on through the route's init); regression as in 385; system accessibility audits
wait for device testing.
**Performance**: the plans are O(blooms) per action; the lights step two levels per frame; the garden and glow meshes
are rebuilt only while a fade runs; the recipe is built only when the loop is rebuilt.
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
| XIII Code-driven visuals and sound | PASS — fades by uniforms and shades; sound synthesized from the recipe. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/ExperiencesRound02/Package.swift                                 edit  Core + VisualCoreAudioDSP; Experience + VisualCoreAudio (lead)
Packages/ExperiencesRound02/NocturneGarden/Core/NocturneGardenFeedbackPlan.swift        new   (agent A)
Packages/ExperiencesRound02/NocturneGarden/Core/NocturneGardenLights.swift              new   (agent B)
Packages/ExperiencesRound02/NocturneGarden/Core/NocturneGardenSoundRecipe.swift         new   (agent B)
Packages/ExperiencesRound02/NocturneGarden/Core/NocturneGardenSceneGeometry.swift       edit  leak cross brightness from lights (lead)
Packages/ExperiencesRound02/NocturneGarden/CoreTests/NocturneGardenFeedbackPlanTests.swift                        new   (agent A)
Packages/ExperiencesRound02/NocturneGarden/CoreTests/{NocturneGardenLightsTests, NocturneGardenSoundRecipeTests}.swift  new (agent B)
Packages/ExperiencesRound02/NocturneGarden/Experience/NocturneGardenSound.swift         new   (lead)
Packages/ExperiencesRound02/NocturneGarden/Experience/{NocturneGardenPresenter, NocturneGardenControls, NocturneGardenGardenScene}.swift  edit (lead)
Packages/ExperiencesRound02/NocturneGarden/ExperienceTests/NocturneGardenAccessibilityTests.swift                 new (agent C)
docs/architecture/nocturne-garden.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md      edit (lead)
```

**Dependency graph**: package dependency → {feedback plan, lights, recipe} → geometry and presenter wiring → panel →
accessibility tests. **Migration**: none. **Rollback**: revert the commits; no stored data or state changes. **CI**: the
round-two host suite, the script tests and the steering validators run on every push; the simulator suite runs locally.

## Parallel work

The lead adds the package dependencies first; agents A (feedback plan) and B (lights, sound recipe) then work in
parallel against the contract; the lead wires the geometry, presenter, scene, sound and panel; agent C writes the
simulator accessibility tests; the lead runs every check and records only after every agent has reported.
