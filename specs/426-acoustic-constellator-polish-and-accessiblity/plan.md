# Implementation Plan: R02-G13-06 — Acoustic Constellator: polish and accessibility

**Branch**: `426-acoustic-constellator-polish-and-accessiblity` (spec directory only; work on `main`) | **Date**:
2026-11-23 | **Spec**: [spec.md](spec.md)

## Summary

Give Acoustic Constellator its polish and accessibility, following Harmonic Bridges' R02-G12-06 (feature 416) in the
same package: in the host-tested Core a feedback plan (announcement kind and text, haptic kind) computed from the old and
new core, the refusal words and the summary text; eased light levels (glow, won brightening of the links) with the
Reduce Flashing fade rules and a half-range-crossing measure; the audition and ambient sound recipes; in the shaders a
won-light uniform so the won look fades instead of switching; in the experience the shared feedback route, the sound
(audition and ambient loop through the shared player), the adjustable star and partner, the summary element, the Sound
toggle and Dynamic Type layout; Reduce Flashing also holds the shown tick, stops the pulse and draws no wave shells.
Research: [research.md](research.md). Data: [data-model.md](data-model.md). API: [contracts/api.md](contracts/api.md).
Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Audit (2026-11-23)**: `AcousticConstellatorCore` and `AcousticConstellatorExperience` exist in
`Packages/ExperiencesRound02/Package.swift` and are linked by `project.yml`; Harmonic Bridges' targets depend on
VisualCoreAudioDSP (Core) and VisualCoreAudio (Experience) for the shared ambient player; `AcousticConstellatorCore`
already has VisualCoreAudioDSP, so only the experience target and its tests gain VisualCoreAudioDSP and
VisualCoreAudio; no new target.
**Language/Version**: Swift 6. **Primary dependencies**: the Acoustic Constellator Core of R02-G13-01 … 05, VisualCoreExperience
(`AnnouncementKind`, `HapticKind`), VisualCoreAudioDSP (`AmbientLoopRecipe`), VisualCoreExperienceHost
(`ExperienceFeedback`), VisualCoreAudio (`AmbientLoopPlayer`). No new package, GLSL file, Objective-C++ or VisualCore API.
**Testing**: host `swift test --package-path Packages/ExperiencesRound02`; simulator package tests on sim-27.2; the app
unit tests; regression; script tests alone. Seed 2_426.
**Constraints**: presentation only (no state or digest change); fades 0.15 s / 0.45 s; at most 3 half-range crossings per
second under Reduce Flashing; the audition 0.6 s; the loop rebuilt only on recipe changes; tests under 10 s.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| II App-neutral API | PASS — game code stays in ExperiencesRound02; VisualCore unchanged. |
| IV Host-testable | PASS — feedback plans, lights and recipes in the Core with host tests. |
| V Implementation before devices | PASS — sound, haptics and VoiceOver on devices are `{device}` items. |
| VII Determinism | PASS — plans and recipes are pure functions; lights read presentation time only. |
| VIII Accessibility | PASS — labels, values, adjustable controls, Dynamic Type, Reduce Motion and Reduce Flashing. |
| XIII Code-driven visuals and sound | PASS — synthesized sound, no recorded audio; the shader gains one uniform. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/ExperiencesRound02/Package.swift                                   edit  Experience (+ tests) + VisualCoreAudioDSP, VisualCoreAudio (lead)
Packages/ExperiencesRound02/AcousticConstellator/Core/AcousticConstellatorFeedbackPlan.swift        new   (agent A)
Packages/ExperiencesRound02/AcousticConstellator/Core/AcousticConstellatorLights.swift              new   (agent B)
Packages/ExperiencesRound02/AcousticConstellator/Core/AcousticConstellatorSoundRecipe.swift         new   (agent B)
Packages/ExperiencesRound02/AcousticConstellator/Core/AcousticConstellatorShaders.swift             edit  u_wonLight (lead)
Packages/ExperiencesRound02/AcousticConstellator/Core/AcousticConstellatorSceneGeometry.swift       edit  won level in the fallback parts (lead)
Packages/ExperiencesRound02/AcousticConstellator/CoreTests/AcousticConstellatorFeedbackPlanTests.swift                            new (agent A)
Packages/ExperiencesRound02/AcousticConstellator/CoreTests/{AcousticConstellatorLightsTests, AcousticConstellatorSoundRecipeTests}.swift new (agent B)
Packages/ExperiencesRound02/AcousticConstellator/CoreTests/AcousticConstellatorShaderSourceTests.swift                            edit (lead)
Packages/ExperiencesRound02/AcousticConstellator/Experience/AcousticConstellatorSound.swift         new   (lead)
Packages/ExperiencesRound02/AcousticConstellator/Experience/{AcousticConstellatorPresenter, AcousticConstellatorControls, AcousticConstellatorConstellationScene}.swift  edit (lead)
Packages/ExperiencesRound02/AcousticConstellator/ExperienceTests/AcousticConstellatorAccessibilityTests.swift                     new (agent C)
docs/architecture/acoustic-constellator.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md       edit (lead)
```

**Dependency graph**: package dependency → {feedback plan, lights, recipes} → shader and presenter wiring → panel →
accessibility tests. **Migration**: none. **Rollback**: revert the commits; no stored data or state changes. **CI**: the
round-two host suite, the script tests and the steering validators run on every push; the simulator suite runs locally.

## Parallel work

Agents A (feedback plan) and B (lights, recipes) work in isolated copies in parallel; the lead edits the package, shader,
sound player and presenter against their contracts; agent C writes the simulator accessibility tests; the lead retests
every result and records only after every agent has reported.
