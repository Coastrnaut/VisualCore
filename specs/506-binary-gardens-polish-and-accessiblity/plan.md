# Implementation Plan: R02-G21-06 — Binary Gardens: polish and accessibility

**Branch**: `506-binary-gardens-polish-and-accessiblity` (spec directory only; work on `main`) | **Date**:
2026-11-27 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/506-binary-gardens-polish-and-accessiblity/spec.md`

## Summary

Give Binary Gardens its polish and accessibility, following Mushroom Weather's R02-G20-06 (feature 496): a pure
feedback plan (announcement text and kind, haptic, trigger) from the old and new adapter core with the texts of
clarification Q1; light levels for the glow, the won look and each world's bloom, eased by the frame clock (0.15 s,
0.45 s under Reduce Flashing); the corona rays' and pollen motes' time held at 0 under Reduce Motion or Reduce Flashing
(the shaders' motion uniform); code-made sound recipes (the selected star's audition from its ring index and whether it
can change, an ambient loop from the worlds keeping their light, the stars' luminosities, the actions left and the
stage); the scene drawing the eased levels (the won uniform and the glow gain already take them; the glow mesh takes
each world's shell factor from its bloom level; the fallback system blends its not-won and won colours); the presenter
routing feedback through the shared route with a feedback log, a Sound toggle, labels and values on every control,
an adjustable star, ring, phase, luminosity, tilt and shown tick and a summary element. Research:
[research.md](research.md). Data: [data-model.md](data-model.md). API: [contracts/api.md](contracts/api.md).
Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Audit (2026-11-27, read-only)**: `BinaryGardensCore` (Core, Content, CoreTests) and `BinaryGardensExperience`
(Experience, ExperienceTests) exist in `Packages/ExperiencesRound02/Package.swift`; the Core depends on
VisualCoreSimulation (`AnnouncementKind`, `HapticKind`), the experience on VisualCoreExperienceHost
(`ExperienceFeedback`); neither has VisualCoreAudioDSP or VisualCoreAudio, so the Core and its tests gain
VisualCoreAudioDSP and the experience and its tests gain VisualCoreAudioDSP and VisualCoreAudio (iOS-conditioned), as
feature 496 did for Mushroom Weather; no new target, and `project.yml` is unchanged. Feature 503's system program blends
the won look by `u_won` (clamped 0 … 1, linear in both) and the glow by `u_glowGain` under `u_glowLimit`, and moves the
coronas and motes by `u_time` times `u_motion`; the scene passes `u_won` 0 or 1 and `u_motion`
`BinaryGardensShaders.motion(reduceMotion:)` (Reduce Flashing does not still them today). A world shell's factor is
vertex data (`a_uv.x` = `GlowKind.world.code(factor:)`, 0 or 1 from `blooms(_:_:won:)`), so easing it needs the glow
mesh built with fractional factors; no GLSL change is needed. The fallback colours come from
`systemPart(_:tier:wonLevel:)`, whose `wonLevel` changes colours only. The panel's refusal line is "That change was
refused: " plus `BinaryGardensMirror.refusalText(code:)`; there is no announcement, haptic or sound today.
**Prerequisites that land first**: R02-G21-04 (feature 504: the camera-taking `glowMesh`, `glowPart` and `systemPart`,
the orbit and preview in the scene's geometry key, the drawn snapshot, the gesture controller, the presenter's `send`
and `refusalLog`, the panel's Ring, Luminosity and Tilt pickers, Phase target with "Set phase", "Inspect" and "Reset
view") and R02-G21-05 (feature 505: `BinaryGardensHints`, `BinaryGardensFailureExplanation`, `BinaryGardensProgress`,
`BinaryGardensMode`, `BinaryGardensTutorialStep`, `level.select`, the mode controls, `tutorial.dismiss`, the codes
`r02-g21.locked` and `r02-g21.date`, snapshot schema 2, digest domain v2). Both gates are recorded before T-001 of this
feature. Readers: `BinaryGardensFeedbackPlan` reads 505's failure explanation, stars, mode, tutorial step and codes;
`BinaryGardensSceneGeometry` and `BinaryGardensSystemScene` build on 504's camera-taking builders and key;
`BinaryGardensPresenter` hooks 504's `send` and gesture commits and 505's hint reveal; `BinaryGardensControls` labels
504's direct choices and 505's hint, dismiss, level picker and mode buttons; `BinaryGardensAccessibilityTests` drives
both. `BinaryGardensLights` and `BinaryGardensSoundRecipe` read only committed kernel types.
**Language/Version**: Swift 6. **Primary dependencies**: the Binary Gardens Core of R02-G21-01 … 05,
VisualCoreSimulation (`AnnouncementKind`, `HapticKind`), VisualCoreAudioDSP (`AmbientLoopRecipe`),
VisualCoreExperienceHost (`ExperienceFeedback`), VisualCoreAudio (`AmbientLoopPlayer`, `SoundEffectPlayer`). No new
package, GLSL change, Objective-C++ or VisualCore API. **Storage**: none (the sound choice is presentation state; saving
it is R02-G21-07).
**Testing**: host `swift test --package-path Packages/ExperiencesRound02 --filter BinaryGardens`; simulator package
tests on sim-27.2 (`--only-testing BinaryGardensExperienceTests`); the app unit tests; the reference regression in two
chunks; the script tests alone. Seed 2_506. **Target platform**: iOS 26.5 and 27.x simulators now; devices only after
ImplementationLock-100. **Project type**: one experience module inside the one app.
**Performance (counted work, never timed)**: one feedback plan per new core (at most 5 worlds judged from the report the
play already holds); the lights step 2 + W ≤ 7 fades per drawn frame; while a bloom level moves, the glow mesh is
rebuilt at most once per drawn frame and only when a bloom level crosses a 1/32 step (at most 32 rebuilds per fade, each
at most 2 shells × 7 annuli × 24 sides = 336 quads); the fallback is rebuilt when the won level crosses a tenth (at most
10 per fade); an audition reads the puzzle's legal moves (at most 120 candidates, each one 48-tick separation scan),
once per change of the selected star or accepted ring change of it; the ambient recipe is rebuilt only on a recipe
change, never per frame; the catalog recipe test builds 100 × 4 recipes. **Constraints**: presentation only (no state,
digest or snapshot schema change); fades 0.15 s / 0.45 s; at most 3 half-range crossings per second under Reduce
Flashing; coronas and motes under 1 cycle per second, still under Reduce Motion or Reduce Flashing; the audition 0.6 s;
tests under 10 s.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| I Proven renderer only | PASS — the existing system and glow programs on the ANGLE → Metal path; no GLSL change. |
| II App-neutral API | PASS — game code stays in ExperiencesRound02; VisualCore API unchanged (no baseline change). |
| II-a Preserve the reference | PASS — the reference regression runs in two chunks (7 of 7). |
| III GPU lifecycle | PASS — glow and fallback rebuilt on the render thread; release and memory warning unchanged. |
| IV Host-testable | PASS — feedback plans, lights and recipes are pure Core code with host tests; fixed seed 2_506. |
| V Implementation before devices | PASS — sound, haptics and VoiceOver on devices are `{device}` items. |
| VI Evidence over assertion | PASS — every check recorded with `run-check`; agent results retested by the lead. |
| VII Native, accessible UI | PASS — labels, values, adjustables, Dynamic Type, Increase Contrast, both reductions. |
| VIII Privacy | PASS — ambient audio session, no input; the feedback log stays in the presenter. |
| IX Bounded input | PASS — adjustables clamp to the level's ranges; every action is validated by the kernel. |
| X Provenance | PASS — original code and texts; synthesized sound only. |
| XI One app | PASS — the candidate experience only; no target or bundle. |
| XII One purchase, no ads | PASS — tier free; nothing changes. |
| XIII Code-driven visuals | PASS — generated geometry and shader code; no recorded audio or images. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/ExperiencesRound02/Package.swift              edit  Core (+ tests) + VisualCoreAudioDSP; Experience
                                                             (+ tests) + VisualCoreAudioDSP, VisualCoreAudio (lead)
BinaryGardens/Core/BinaryGardensFeedbackPlan.swift     new   texts, kinds, haptics, triggers, summary (agent B)
BinaryGardens/Core/BinaryGardensLights.swift           new   glow, won and bloom fades, crossing measure (agent C)
BinaryGardens/Core/BinaryGardensSoundRecipe.swift      new   audition and ambient recipes (agent C)
BinaryGardens/Core/BinaryGardensSceneGeometry.swift    edit  glowPart and glowMesh take bloom levels (agent C)
BinaryGardens/CoreTests/BinaryGardensFeedbackPlanTests.swift                          new  (agent B)
BinaryGardens/CoreTests/{BinaryGardensLightsTests, BinaryGardensSoundRecipeTests}.swift  new  (agent C)
BinaryGardens/CoreTests/BinaryGardensSceneGeometryTests.swift                         edit (agent C)
BinaryGardens/Experience/BinaryGardensSound.swift      new   loop and audition players, play rule (lead)
BinaryGardens/Experience/{BinaryGardensPresenter, BinaryGardensSystemScene,
                          BinaryGardensControls}.swift                                edit (lead)
BinaryGardens/ExperienceTests/BinaryGardensAccessibilityTests.swift                   new  (agent D)
BinaryGardens/ExperienceTests/BinaryGardensRenderTests.swift                          edit (lead: settle the won look)
docs/architecture/binary-gardens.md, Packages/ExperiencesRound02/README.md,
docs/automatedtesting.md, README.md                                                   edit (lead)
```

Paths under `BinaryGardens/` are in `Packages/ExperiencesRound02/`. Files are picked up by path; no app file is added,
so `xcodegen generate` is not needed. The invariant test's fixed 10-file kernel list is unchanged.

**Dependency graph**: features 504 and 505 recorded → package dependency → {feedback plan (B); lights, geometry bloom
levels, recipes (C)} → scene, sound player and presenter wiring (lead) → panel (lead) → accessibility tests (D) →
render test settle edit and docs (lead). **Migration**: none (snapshot schema 2 and digest domain v2 of R02-G21-05
unchanged; presentation only). **Rollback**: revert the feature's commits; no stored data or state changes, and the
scene without lights draws the snapshot's levels at once as today. **CI**: the `ci` workflow's round02 half b filter
already includes `BinaryGardens` (no new job); the script tests and the steering validators run on every push; the
simulator suite and the reference regression run locally.

## Parallel work

Agents B (feedback plan) and C (lights, geometry bloom levels, recipes) draft in isolated copies in parallel against
the contract; the lead edits the package, scene, sound player, presenter and panel against their contracts; agent D
writes the simulator accessibility tests with the presenter's exact texts in its brief. Agents build only in their
copies; the lead runs every repository build and test, retests each agent result and records only after every agent
has reported.
