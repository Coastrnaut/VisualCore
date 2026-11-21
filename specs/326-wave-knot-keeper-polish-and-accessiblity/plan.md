# Implementation Plan: R02-G03-06 — Wave Knot Keeper: polish and accessibility

**Branch**: `326-wave-knot-keeper-polish-and-accessiblity` (spec directory only; work on `main`) | **Date**: 2026-11-21 |
**Spec**: [spec.md](spec.md)

## Summary

Polish Wave Knot Keeper for every player, following feature 316. In the host-tested `WaveKnotKeeperCore`, three pure
presentation helpers that never touch state: `WaveKnotKeeperFeedbackPlan` (announcement text and kind and the haptic kind
for a change from one core to the next or a refusal), `WaveKnotKeeperLights` (eased light levels of the crossing marks,
the target match and the win glow, 0.15 s normally and 0.45 s under Reduce Flashing, finishing a started fade before
turning back, with a flash-rate measure; a mark that disappears fades out where it last was on its over-strand) and
`WaveKnotKeeperSoundRecipe` (an `AmbientLoopRecipe` from the summary, the target and the stage). The scene geometry's
crossing weights take the eased levels. In the iOS `WaveKnotKeeperExperience`: the presenter routes the plans to the
shared feedback route (`feedback`, injectable), keeps a feedback log, passes the eased lights to the scene, and owns a
`WaveKnotKeeperSound` that plays the ambient loop while wanted, on screen and active; the panel scrolls, grows with
Dynamic Type, wraps its button rows, keeps a 520-point readable width on iPad, labels every control, shows refusals in
words and adds a Sound toggle. Research: [research.md](research.md). Data: [data-model.md](data-model.md). API:
[contracts/api.md](contracts/api.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Swift 6, SwiftUI, OpenGL ES 3.0 through ANGLE (shaders unchanged: the crossing weight `a_uv.x`
already scales the caustic pulse; the target match and the win glow scale the glow gain `u_gain`, never above the Reduce
Flashing cap). **Primary dependencies**: WaveKnotKeeperCore; VisualCoreSimulation (`HapticKind`, `AnnouncementKind`);
VisualCoreAudioDSP (`AmbientLoopRecipe`, `AmbientLoopPartial`) — a new product dependency of WaveKnotKeeperCore;
VisualCoreAudio (`AmbientLoopPlayer`) and VisualCoreExperienceHost (`ExperienceFeedback`) for the iOS experience. No new
package, target or app change.
**Seeds**: tests use seed 2_326 for scripted sequences.
**Testing**: `swift test --package-path Packages/ExperiencesRound02` (Core); the round-two simulator suite on sim-27.2
with recording sinks (VoiceOver forced on through the route's init); regression as in 325; system accessibility audits
wait for device testing.
**Performance**: the plans are O(1) per action; the lights step at most one level per crossing mark (at most
16 × 13 / 2 = 104 segment pairs, in practice under 12) plus two per frame; geometry weights are rebuilt only while a
crossing fade runs; the recipe is built only when the loop is rebuilt.
**Constraints**: no state, digest or snapshot change (schema 2 stays); presentation only; Reduce Motion and Reduce
Flashing from the host contract.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| I Proven renderer only | PASS — same scene and shaders; lights feed existing weights and uniforms. |
| II App-neutral API | PASS — game code stays in ExperiencesRound02; shared routes reused, not changed. |
| IV Host-testable | PASS — plans, lights and recipe are pure Core types with host tests. |
| V Implementation before devices | PASS — sound, haptics and VoiceOver on hardware wait for D1–D3. |
| VI Evidence Over Assertion | PASS — announcements, haptics and fades proven by recorded sinks and measured levels. |
| VII Native, Accessible UI | PASS — labels, values, adjustable picker, announcements, Dynamic Type, contrast, reduced motion and flashing. |
| IX Bounded input | PASS — rate limits from the shared planners; no unbounded queue. |
| X Licensing and provenance | PASS — all text original; sound synthesized. |
| XII One purchase, no advertising | PASS — free; no store code. |
| XIII Code-driven visuals | PASS — no assets. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/ExperiencesRound02/Package.swift                                                   edit  WaveKnotKeeperCore + VisualCoreAudioDSP (lead)
Packages/ExperiencesRound02/WaveKnotKeeper/Core/WaveKnotKeeperFeedbackPlan.swift            new   (agent A)
Packages/ExperiencesRound02/WaveKnotKeeper/Core/WaveKnotKeeperLights.swift                  new   (agent B)
Packages/ExperiencesRound02/WaveKnotKeeper/Core/WaveKnotKeeperSoundRecipe.swift             new   (agent B)
Packages/ExperiencesRound02/WaveKnotKeeper/Core/WaveKnotKeeperSceneGeometry.swift           edit  weights from lights (lead)
Packages/ExperiencesRound02/WaveKnotKeeper/CoreTests/WaveKnotKeeperFeedbackPlanTests.swift  new   (agent A)
Packages/ExperiencesRound02/WaveKnotKeeper/CoreTests/{WaveKnotKeeperLightsTests, WaveKnotKeeperSoundRecipeTests}.swift new (agent B)
Packages/ExperiencesRound02/WaveKnotKeeper/Experience/WaveKnotKeeperSound.swift             new   (lead)
Packages/ExperiencesRound02/WaveKnotKeeper/Experience/{WaveKnotKeeperPresenter, WaveKnotKeeperControls, WaveKnotKeeperRopeScene}.swift edit (lead)
Packages/ExperiencesRound02/WaveKnotKeeper/ExperienceTests/WaveKnotKeeperAccessibilityTests.swift new (agent C)
docs/architecture/wave-knot-keeper.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md                edit (lead)
```

**Migration**: none. **Rollback**: revert the commits; no stored data or state changes.

## Parallel work

The lead adds the package dependency first; agents A (feedback plan) and B (lights, sound recipe) then work in parallel
against the contract; the lead wires the geometry, presenter, scene, sound and panel; agent C writes the simulator
accessibility tests; the lead runs every check and records only after every agent has reported.
