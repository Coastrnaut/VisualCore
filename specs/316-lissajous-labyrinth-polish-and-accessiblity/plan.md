# Implementation Plan: R02-G02-06 — Lissajous Labyrinth: polish and accessibility

**Branch**: `316-lissajous-labyrinth-polish-and-accessiblity` (spec directory only; work on `main`) | **Date**: 2026-11-21 |
**Spec**: [spec.md](spec.md)

## Summary

Polish Lissajous Labyrinth for every player, following feature 306. In the host-tested `LissajousLabyrinthCore`, three
pure presentation helpers that never touch state: `LissajousLabyrinthFeedbackPlan` (announcement text and kind and the
haptic kind for a change from one core to the next or a refusal), `LissajousLabyrinthLights` (eased light levels of the
checkpoints, the obstacles and the win glow, 0.15 s normally and 0.45 s under Reduce Flashing, finishing a started fade
before turning back, with a flash-rate measure) and `LissajousLabyrinthSoundRecipe` (an `AmbientLoopRecipe` from the dials
and stage). In the iOS `LissajousLabyrinthExperience`: the presenter routes the plans to the shared feedback route
(`feedback`, injectable), keeps a feedback log, passes the eased lights to the scene, and owns a
`LissajousLabyrinthSound` that plays the ambient loop while wanted, on screen and active; the panel scrolls, grows with
Dynamic Type, wraps its button rows, keeps a 520-point readable width on iPad, labels every control and adds a Sound
toggle. Research: [research.md](research.md). Data: [data-model.md](data-model.md). API: [contracts/api.md](contracts/api.md).
Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Swift 6, SwiftUI, OpenGL ES 3.0 through ANGLE (shaders unchanged: the checkpoint and obstacle
colours already take a `u_lit` uniform; the win glow scales the glow gain). **Primary dependencies**:
LissajousLabyrinthCore; VisualCoreSimulation (`HapticKind`, `AnnouncementKind`); VisualCoreAudioDSP (`AmbientLoopRecipe`,
`AmbientLoopPartial`) — a new product dependency of LissajousLabyrinthCore; VisualCoreAudio (`AmbientLoopPlayer`) and
VisualCoreExperienceHost (`ExperienceFeedback`) for the iOS experience. No new package, target or app change.
**Seeds**: tests use seed 2_316 for scripted sequences.
**Testing**: `swift test --package-path Packages/ExperiencesRound02` (Core); the round-two simulator suite on sim-27.2
with recording sinks (VoiceOver forced on through the route's init); regression as in 315; system accessibility audits
wait for device testing.
**Performance**: the plans are O(1) per action; the lights step at most 3 + 3 + 1 levels per frame (the catalog's levels
have at most three checkpoints and three obstacles; the code takes any count); the recipe is built only when the loop is
rebuilt.
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
| VI Evidence Over Assertion | PASS — announcements, haptics and fades proven by recorded sinks and measured levels. |
| VII Native, Accessible UI | PASS — labels, values, adjustable steppers, announcements, Dynamic Type, contrast, reduced motion and flashing. |
| IX Bounded input | PASS — rate limits from the shared planners; no unbounded queue. |
| X Licensing and provenance | PASS — all text original; sound synthesized. |
| XII One purchase, no advertising | PASS — free; no store code. |
| XIII Code-driven visuals | PASS — no assets. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/ExperiencesRound02/Package.swift                                                   edit  LissajousLabyrinthCore + VisualCoreAudioDSP (lead)
Packages/ExperiencesRound02/LissajousLabyrinth/Core/LissajousLabyrinthFeedbackPlan.swift    new   (agent A)
Packages/ExperiencesRound02/LissajousLabyrinth/Core/LissajousLabyrinthLights.swift          new   (agent B)
Packages/ExperiencesRound02/LissajousLabyrinth/Core/LissajousLabyrinthSoundRecipe.swift     new   (agent B)
Packages/ExperiencesRound02/LissajousLabyrinth/CoreTests/LissajousLabyrinthFeedbackPlanTests.swift   new (agent A)
Packages/ExperiencesRound02/LissajousLabyrinth/CoreTests/{LissajousLabyrinthLightsTests, LissajousLabyrinthSoundRecipeTests}.swift new (agent B)
Packages/ExperiencesRound02/LissajousLabyrinth/Experience/LissajousLabyrinthSound.swift     new   (lead)
Packages/ExperiencesRound02/LissajousLabyrinth/Experience/{LissajousLabyrinthPresenter, LissajousLabyrinthControls, LissajousLabyrinthThreadScene}.swift edit (lead)
Packages/ExperiencesRound02/LissajousLabyrinth/ExperienceTests/LissajousLabyrinthAccessibilityTests.swift new (agent C)
docs/architecture/lissajous-labyrinth.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md            edit (lead)
```

**Migration**: none. **Rollback**: revert the commits; no stored data or state changes.

## Parallel work

The lead adds the package dependency first; agents A (feedback plan) and B (lights, sound recipe) then work in parallel
against the contract; the lead wires the presenter, scene, sound and panel; agent C writes the simulator accessibility
tests; the lead runs every check and records only after every agent has reported.
