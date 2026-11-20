# Implementation Plan: R02-G01-06 — Aurora Loom: polish and accessibility

**Branch**: `306-aurora-loom-polish-and-accessiblity` (spec directory only; work on `main`) | **Date**: 2026-11-20 |
**Spec**: [spec.md](spec.md)

## Summary

Polish Aurora Loom for every player. In the host-tested `AuroraLoomCore`, three pure presentation helpers that never
touch state: `AuroraLoomFeedbackPlan` (announcement text and kind and the haptic kind for a change from one core to the
next or a refusal), `AuroraLoomLights` (eased light levels of the 12 gate crossings and the win glow, 0.15 s normally and
0.45 s under Reduce Flashing, with a flash-rate measure) and `AuroraLoomSoundRecipe` (an `AmbientLoopRecipe` from the
steps and stage). In the iOS `AuroraLoomExperience`: the presenter routes the plans through the action port to the shared
feedback route (an injectable `ExperienceFeedback` for tests), keeps a feedback log, draws the eased lights, and owns an
`AuroraLoomSound` that plays the ambient loop by the A21 rule; the panel scrolls, grows with Dynamic Type, keeps a 520-
point readable width on iPad, labels every control and adds a Sound toggle. Research: [research.md](research.md). Data:
[data-model.md](data-model.md). API: [contracts/api.md](contracts/api.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Swift 6, SwiftUI, OpenGL ES 3.0 through ANGLE (unchanged shaders; the lights are uniforms already
drawn). **Primary dependencies**: AuroraLoomCore; VisualCoreSimulation (`HapticKind`, `AnnouncementKind`);
VisualCoreAudioDSP (`AmbientLoopRecipe`, `AmbientLoopPartial`) — a new product dependency of AuroraLoomCore from the
VisualCore package; VisualCoreAudio (`AmbientLoopPlayer`) and VisualCoreExperienceHost (`ExperienceFeedback`,
`ExperienceActionPort.haptic/announce`) for the iOS experience. No new package, target or app change; no Objective-C++.
**Seeds**: none new; tests use seed 2_306 for scripted sequences.
**Testing**: `swift test --package-path Packages/ExperiencesRound02` (Core); the round-two simulator suite on sim-27.2
with recording sinks (`RecordingHapticSink`, a recording announcement sink, VoiceOver forced on through the route's
init); regression as in 305; audits wait for device testing.
**Performance**: the plans are O(1) per action; the lights step 13 levels per frame; the recipe is built only when the
loop is rebuilt.
**Constraints**: no state, digest or snapshot change (schema 2 stays); presentation only; Reduce Motion and Reduce
Flashing from the host contract.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| I Proven renderer only | PASS — same scene and shaders; lights feed existing uniforms. |
| II App-neutral API | PASS — game code stays in ExperiencesRound02; shared routes reused, not changed. |
| IV Host-testable | PASS — plans, lights and recipe are pure Core types with host tests. |
| V Implementation before devices | PASS — sound, haptics and VoiceOver on hardware wait for D1–D3. |
| VI Accessibility | PASS — labels, values, adjustable steppers, announcements, Dynamic Type, contrast, reduced motion and flashing. |
| IX Bounded input | PASS — rate limits from the shared planners; no unbounded queue. |
| X Licensing and provenance | PASS — all text original; sound synthesized. |
| XII One purchase, no advertising | PASS — free; no store code. |
| XIII Code-driven visuals | PASS — no assets. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/ExperiencesRound02/Package.swift                                         edit  AuroraLoomCore + VisualCoreAudioDSP (lead)
Packages/ExperiencesRound02/AuroraLoom/Core/AuroraLoomFeedbackPlan.swift          new   (agent A)
Packages/ExperiencesRound02/AuroraLoom/Core/AuroraLoomLights.swift                new   (agent B)
Packages/ExperiencesRound02/AuroraLoom/Core/AuroraLoomSoundRecipe.swift           new   (agent B)
Packages/ExperiencesRound02/AuroraLoom/CoreTests/AuroraLoomFeedbackPlanTests.swift new  (agent A)
Packages/ExperiencesRound02/AuroraLoom/CoreTests/AuroraLoomLightsTests.swift      new   (agent B)
Packages/ExperiencesRound02/AuroraLoom/CoreTests/AuroraLoomSoundRecipeTests.swift new   (agent B)
Packages/ExperiencesRound02/AuroraLoom/Experience/AuroraLoomSound.swift           new   (lead)
Packages/ExperiencesRound02/AuroraLoom/Experience/AuroraLoomPresenter.swift       edit  (lead)
Packages/ExperiencesRound02/AuroraLoom/Experience/AuroraLoomControls.swift        edit  (lead)
Packages/ExperiencesRound02/AuroraLoom/Experience/AuroraLoomRibbonScene.swift     edit  lights from the presenter (lead)
Packages/ExperiencesRound02/AuroraLoom/ExperienceTests/AuroraLoomAccessibilityTests.swift new (agent C)
docs/architecture/aurora-loom.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md   edit (lead)
```

**Migration**: none. **Rollback**: revert the commits; no stored data or state changes.

## Parallel work

Lead adds the package dependency and the contract; agents A (feedback plan) and B (lights, recipe) write Core files in
parallel; the lead wires the presenter, sound, controls and scene; agent C writes the simulator tests against the
wiring; the lead retests and records checks after every agent has reported.
