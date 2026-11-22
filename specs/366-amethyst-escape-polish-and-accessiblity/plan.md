# Implementation Plan: R02-G07-06 — Amethyst Escape: polish and accessibility

**Branch**: `366-amethyst-escape-polish-and-accessiblity` (spec directory only; work on `main`) | **Date**: 2026-11-22 |
**Spec**: [spec.md](spec.md)

## Summary

Polish Amethyst Escape on Chrono Constellator's feature-356 pattern: `AmethystEscapeFeedbackPlan` (announcement kind and
text and haptic kind for every change, refusal words, the summary element), `AmethystEscapeLights` (eased light levels
for the pearl glow, the exit glow and the failed wedge, 0.15 s or 0.45 s under Reduce Flashing) and
`AmethystEscapeSoundRecipe` (an ambient loop from the pearl's shell and the stage) in the Core; the scene geometry draws
the eased levels; the presenter routes feedback through the shared `ExperienceFeedback` and keeps a feedback log; the
panel gains labels, values, an adjustable shell picker, a summary, Sound and Dynamic Type layout. Research:
[research.md](research.md). Data: [data-model.md](data-model.md). API: [contracts/api.md](contracts/api.md). Quickstart:
[quickstart.md](quickstart.md).

## Technical Context

**Audit (2026-11-22)**: `AmethystEscapeCore` depends on VisualCoreSimulation, Math, Scenes, Experience, Diagnostics and
Persistence; it needs VisualCoreAudioDSP (`AmbientLoopRecipe`) as ChronoConstellatorCore has; the experience target needs
VisualCoreAudio (`AmbientLoopPlayer`, iOS) and already has VisualCoreExperienceHost (`ExperienceFeedback`).
**Language/Version**: Swift 6, SwiftUI, OpenGL ES 3.0 through ANGLE (shaders unchanged: the crystal program's shade
carries the failed wedge's eased amber, the glow stream's weight the pearl's and the exit's eased levels).
**Primary dependencies**: AmethystEscapeCore; VisualCoreSimulation (`HapticKind`, `AnnouncementKind`);
VisualCoreAudioDSP; VisualCoreAudio and VisualCoreExperienceHost in the experience. No new package, target or app
change; no Objective-C++.
**Seeds**: tests use seed 2_366 for scripted sequences.
**Testing**: `swift test --package-path Packages/ExperiencesRound02` (Core); the round-two simulator suite on sim-27.2
with recording sinks (VoiceOver forced on through the route's init); regression as in 365; system accessibility audits
wait for device testing.
**Performance**: the plans are O(shells) per action; the lights step three levels per frame; the crystal and glow
meshes are rebuilt only while a fade runs; the recipe is built only when the loop is rebuilt.
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
Packages/ExperiencesRound02/AmethystEscape/Core/AmethystEscapeFeedbackPlan.swift              new   (agent A)
Packages/ExperiencesRound02/AmethystEscape/Core/AmethystEscapeLights.swift                    new   (agent B)
Packages/ExperiencesRound02/AmethystEscape/Core/AmethystEscapeSoundRecipe.swift               new   (agent B)
Packages/ExperiencesRound02/AmethystEscape/Core/AmethystEscapeSceneGeometry.swift             edit  pearl, exit and wedge brightness from lights (lead)
Packages/ExperiencesRound02/AmethystEscape/CoreTests/AmethystEscapeFeedbackPlanTests.swift    new   (agent A)
Packages/ExperiencesRound02/AmethystEscape/CoreTests/{AmethystEscapeLightsTests, AmethystEscapeSoundRecipeTests}.swift new (agent B)
Packages/ExperiencesRound02/AmethystEscape/Experience/AmethystEscapeSound.swift               new   (lead)
Packages/ExperiencesRound02/AmethystEscape/Experience/{AmethystEscapePresenter, AmethystEscapeControls, AmethystEscapeCrystalScene}.swift edit (lead)
Packages/ExperiencesRound02/AmethystEscape/ExperienceTests/AmethystEscapeAccessibilityTests.swift new (agent C)
docs/architecture/amethyst-escape.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md      edit (lead)
```

**Dependency graph**: package dependency → {feedback plan, lights, recipe} → geometry and presenter wiring → panel →
accessibility tests. **Migration**: none. **Rollback**: revert the commits; no stored data or state changes. **CI**: the
round-two host suite, the script tests and the steering validators run on every push; the simulator suite runs locally.

## Parallel work

The lead adds the package dependencies first; agents A (feedback plan) and B (lights, sound recipe) then work in parallel
against the contract; the lead wires the geometry, presenter, scene, sound and panel; agent C writes the simulator
accessibility tests; the lead runs every check and records only after every agent has reported.
