# Implementation Plan: R02-G10-06 — Backwards Aurora: polish and accessibility

**Branch**: `396-backwards-aurora-polish-and-accessiblity` (spec directory only; work on `main`) | **Date**: 2026-11-23
| **Spec**: [spec.md](spec.md)

## Summary

Polish Backwards Aurora on Nocturne Garden's feature-386 pattern: `BackwardsAuroraFeedbackPlan` (announcement kind and
text and haptic kind for every change, refusal words, the summary element), `BackwardsAuroraLights` (eased light levels
for the aurora's glow, the won lift, the tear cross and the freeze preview, 0.15 s or 0.45 s under Reduce Flashing) and
`BackwardsAuroraSoundRecipe` (an ambient loop from the worst bend, the checkpoints matched and the stage) in the Core;
the scene draws the eased levels; the presenter routes feedback through the shared `ExperienceFeedback` and keeps a
feedback log; the panel gains labels, values, adjustable ends, a summary, Sound and Dynamic Type layout. Research:
[research.md](research.md). Data: [data-model.md](data-model.md). API: [contracts/api.md](contracts/api.md).
Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Audit (2026-11-23)**: `BackwardsAuroraCore` depends on VisualCoreSimulation, Math, Scenes, Experience, Diagnostics
and Persistence; it needs VisualCoreAudioDSP (`AmbientLoopRecipe`) as NocturneGardenCore has; the experience target
needs VisualCoreAudio (`AmbientLoopPlayer`, iOS) and already has VisualCoreExperienceHost (`ExperienceFeedback`).
**Language/Version**: Swift 6, SwiftUI, OpenGL ES 3.0 through ANGLE (the glow gain uniform carries the eased glow
level and `u_won` the eased won lift; two aurora uniforms, `u_tearLight` and `u_previewLight`, scale the tear cross's
and the preview ribbon's alphas, so a fade rebuilds no geometry — decided at implementation, 2026-11-23, because the
meshes have no free per-vertex channel for a shade).
**Primary dependencies**: BackwardsAuroraCore; VisualCoreSimulation (`HapticKind`, `AnnouncementKind`);
VisualCoreAudioDSP; VisualCoreAudio and VisualCoreExperienceHost in the experience. No new package, target or app
change; no Objective-C++.
**Seeds**: tests use seed 2_396 for scripted sequences.
**Testing**: `swift test --package-path Packages/ExperiencesRound02` (Core); the round-two simulator suite on sim-27.2
with recording sinks (VoiceOver forced on through the route's init); regression as in 395; system accessibility audits
wait for device testing.
**Performance**: the plans are O(samples) per action; the lights step four levels per frame; the ribbon and glow meshes
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
Packages/ExperiencesRound02/BackwardsAurora/Core/BackwardsAuroraFeedbackPlan.swift       new   (agent A)
Packages/ExperiencesRound02/BackwardsAurora/Core/BackwardsAuroraLights.swift             new   (agent B)
Packages/ExperiencesRound02/BackwardsAurora/Core/BackwardsAuroraSoundRecipe.swift        new   (agent B)
Packages/ExperiencesRound02/BackwardsAurora/Core/BackwardsAuroraSceneGeometry.swift      edit  the tear cross kept on the last torn seam (lead)
Packages/ExperiencesRound02/BackwardsAurora/Core/BackwardsAuroraShaders.swift            edit  u_tearLight, u_previewLight (lead)
Packages/ExperiencesRound02/BackwardsAurora/CoreTests/BackwardsAuroraFeedbackPlanTests.swift                         new  (agent A)
Packages/ExperiencesRound02/BackwardsAurora/CoreTests/{BackwardsAuroraLightsTests, BackwardsAuroraSoundRecipeTests}.swift  new (agent B)
Packages/ExperiencesRound02/BackwardsAurora/CoreTests/BackwardsAuroraInvariantTests.swift                            edit presentation sources (lead)
Packages/ExperiencesRound02/BackwardsAurora/Experience/BackwardsAuroraSound.swift        new   (lead)
Packages/ExperiencesRound02/BackwardsAurora/Experience/{BackwardsAuroraPresenter, BackwardsAuroraControls, BackwardsAuroraAuroraScene}.swift  edit (lead)
Packages/ExperiencesRound02/BackwardsAurora/ExperienceTests/BackwardsAuroraAccessibilityTests.swift                  new (agent C)
docs/architecture/backwards-aurora.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md       edit (lead)
```

**Dependency graph**: package dependency → {feedback plan, lights, recipe} → geometry and presenter wiring → panel →
accessibility tests. **Migration**: none. **Rollback**: revert the commits; no stored data or state changes. **CI**: the
round-two host suite, the script tests and the steering validators run on every push; the simulator suite runs locally.

## Parallel work

The lead adds the package dependencies first; agents A (feedback plan) and B (lights, sound recipe) then work in
parallel against the contract; the lead wires the geometry, presenter, scene, sound and panel; agent C writes the
simulator accessibility tests; the lead runs every check and records only after every agent has reported.
