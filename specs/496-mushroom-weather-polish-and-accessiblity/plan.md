# Implementation Plan: R02-G20-06 — Mushroom Weather: polish and accessibility

**Branch**: `496-mushroom-weather-polish-and-accessiblity` (spec directory only; work on `main`) | **Date**:
2026-11-26 | **Spec**: [spec.md](spec.md)

## Summary

Give Mushroom Weather its polish and accessibility, following Microscopic Aurora's R02-G19-06 (feature 486): a pure
feedback plan (announcement text and kind, haptic) from the old and new adapter core with the texts of clarification
Q1; light levels for the glow and the won look eased by the frame clock (0.15 s, 0.45 s under Reduce Flashing); the
droplets' and motes' time held at 0 under Reduce Motion or Reduce Flashing (the shaders' motion uniform); code-made
sound recipes (the selected site's audition from its index and whether a pod can go there, an ambient loop from the
colonies staying in band, the moonlight, the actions left and the stage); the scene drawing the eased levels (the won
uniform and the glow gain already take them; the fallback forest blends its not-won and won colours); the presenter
routing feedback through the shared route with a feedback log, a Sound toggle, labels and values on every control, an
adjustable slot, site and moonlight, vent toggles and a summary element. Research: [research.md](research.md). Data:
[data-model.md](data-model.md). API: [contracts/api.md](contracts/api.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Audit (2026-11-26)**: after R02-G20-03 … 05, `MushroomWeatherCore` and `MushroomWeatherExperience` exist in
`Packages/ExperiencesRound02/Package.swift` and are linked by `project.yml`; Microscopic Aurora's Core depends on
VisualCoreAudioDSP and its experience on VisualCoreAudioDSP and VisualCoreAudio (iOS) for the shared ambient player;
`MushroomWeatherCore` has neither, so the Core and its tests gain VisualCoreAudioDSP and the experience and its tests
gain VisualCoreAudioDSP and VisualCoreAudio (iOS-conditioned); no new target. Feature 493's shaders scale the won look
by the won uniform (0 … 1), the glow by the glow gain under the glow limit, and move droplets and motes by the time
uniform times the motion uniform; the fallback forest part takes a won flag, so the scene blends the not-won and won
parts' colours by the eased level; no shader or geometry change is needed. The panel's selection (slot, site) lives in
the mirror. **Language/Version**: Swift 6. **Primary dependencies**: the Mushroom Weather Core of R02-G20-01 … 05,
VisualCoreExperience (`AnnouncementKind`, `HapticKind`), VisualCoreAudioDSP (`AmbientLoopRecipe`),
VisualCoreExperienceHost (`ExperienceFeedback`), VisualCoreAudio (`AmbientLoopPlayer`). No new package, GLSL change,
Objective-C++ or VisualCore API. **Testing**: host `swift test --package-path Packages/ExperiencesRound02`; simulator
package tests on sim-27.2; the app unit tests; regression; script tests alone. Seed 2_496. **Constraints**:
presentation only (no state or digest change); fades 0.15 s / 0.45 s; at most 3 half-range crossings per second under
Reduce Flashing; droplets and motes under 1 cycle per second, still under Reduce Motion or Reduce Flashing; the audition
0.6 s; the loop rebuilt only on recipe changes; tests under 10 s.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| II App-neutral API | PASS — game code stays in ExperiencesRound02; VisualCore unchanged. |
| IV Host-testable | PASS — feedback plans, lights and recipes in the Core with host tests. |
| V Implementation before devices | PASS — sound, haptics and VoiceOver on devices are `{device}` items. |
| VII Determinism | PASS — plans and recipes are pure functions; lights read the frame clock's elapsed time only. |
| VIII Accessibility | PASS — labels, values, adjustable controls, Dynamic Type, Reduce Motion and Reduce Flashing. |
| XIII Code-driven visuals and sound | PASS — synthesized sound, no recorded audio; no shader change. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/ExperiencesRound02/Package.swift                                   edit  Core (+ tests) + VisualCoreAudioDSP; Experience (+ tests) + VisualCoreAudioDSP, VisualCoreAudio (lead)
Packages/ExperiencesRound02/MushroomWeather/Core/MushroomWeatherFeedbackPlan.swift   new   (agent A)
Packages/ExperiencesRound02/MushroomWeather/Core/MushroomWeatherLights.swift         new   (agent B)
Packages/ExperiencesRound02/MushroomWeather/Core/MushroomWeatherSoundRecipe.swift    new   (agent B)
Packages/ExperiencesRound02/MushroomWeather/CoreTests/MushroomWeatherFeedbackPlanTests.swift                        new (agent A)
Packages/ExperiencesRound02/MushroomWeather/CoreTests/{MushroomWeatherLightsTests, MushroomWeatherSoundRecipeTests}.swift new (agent B)
Packages/ExperiencesRound02/MushroomWeather/Experience/MushroomWeatherSound.swift    new   (lead)
Packages/ExperiencesRound02/MushroomWeather/Experience/{MushroomWeatherPresenter, MushroomWeatherControls, MushroomWeatherForestScene}.swift  edit (lead)
Packages/ExperiencesRound02/MushroomWeather/ExperienceTests/MushroomWeatherAccessibilityTests.swift                 new (agent C)
docs/architecture/mushroom-weather.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md       edit (lead)
```

**Dependency graph**: package dependency → {feedback plan, lights, recipes} → scene and presenter wiring → panel →
accessibility tests. **Migration**: none (snapshot schema 2 unchanged). **Rollback**: revert the commits; no stored
data or state changes. **CI**: the round-two host suite, the script tests and the steering validators run on every
push; the simulator suite runs locally.

## Parallel work

Agents A (feedback plan) and B (lights, recipes) work in isolated copies in parallel; the lead edits the package,
scene, sound player and presenter against their contracts; agent C writes the simulator accessibility tests given the
presenter's exact texts; the lead retests every result and records only after every agent has reported.
