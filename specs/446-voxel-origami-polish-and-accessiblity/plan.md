# Implementation Plan: R02-G15-06 — Voxel Origami: polish and accessibility

**Branch**: `446-voxel-origami-polish-and-accessiblity` (spec directory only; work on `main`) | **Date**: 2026-11-24 |
**Spec**: [spec.md](spec.md)

## Summary

Give Voxel Origami its polish and accessibility, following Moonlit Mechanism's R02-G14-06 (feature 436): a pure
feedback plan (announcement text and kind, haptic) from the old and new adapter core with the texts of clarification Q1;
light levels for the glow and the won look eased by the frame clock (0.15 s, 0.45 s under Reduce Flashing);
code-made sound recipes (a hinge's audition from its index and whether it can turn, an ambient loop from the cubes in place); the scene drawing the
eased levels (`u_won` and the glow gain already take them; the fallback's cube lift already takes a won level); the presenter
routing feedback through the shared route with a feedback log, a Sound toggle, labels and values on every control, an
adjustable hinge and a summary element. Research: [research.md](research.md). Data:
[data-model.md](data-model.md). API: [contracts/api.md](contracts/api.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Audit (2026-11-24)**: `VoxelOrigamiCore` and `VoxelOrigamiExperience` exist in
`Packages/ExperiencesRound02/Package.swift` and are linked by `project.yml`; Moonlit Mechanism's Core depends on
VisualCoreAudioDSP and its experience on VisualCoreAudioDSP and VisualCoreAudio (iOS) for the shared ambient player;
`VoxelOrigamiCore` has neither, so the Core and its tests gain VisualCoreAudioDSP and the experience and its tests
gain VisualCoreAudioDSP and VisualCoreAudio (iOS-conditioned); no new target. The shaders already scale the won look
by `u_won` (0 … 1) and the glow by `u_glowGain`, and the fallback parts take a `wonLevel`, so no shader or geometry
change is needed.
**Language/Version**: Swift 6. **Primary dependencies**: the Voxel Origami Core of R02-G15-01 … 05, VisualCoreExperience
(`AnnouncementKind`, `HapticKind`), VisualCoreAudioDSP (`AmbientLoopRecipe`), VisualCoreExperienceHost
(`ExperienceFeedback`), VisualCoreAudio (`AmbientLoopPlayer`). No new package, GLSL change, Objective-C++ or VisualCore
API.
**Testing**: host `swift test --package-path Packages/ExperiencesRound02`; simulator package tests on sim-27.2; the app
unit tests; regression; script tests alone. Seed 2_446.
**Constraints**: presentation only (no state or digest change); fades 0.15 s / 0.45 s; at most 3 half-range crossings per
second under Reduce Flashing; the audition 0.6 s; the loop rebuilt only on recipe changes; tests under 10 s.

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
Packages/ExperiencesRound02/VoxelOrigami/Core/VoxelOrigamiFeedbackPlan.swift        new   (agent A)
Packages/ExperiencesRound02/VoxelOrigami/Core/VoxelOrigamiLights.swift              new   (agent B)
Packages/ExperiencesRound02/VoxelOrigami/Core/VoxelOrigamiSoundRecipe.swift         new   (agent B)
Packages/ExperiencesRound02/VoxelOrigami/CoreTests/VoxelOrigamiFeedbackPlanTests.swift                        new (agent A)
Packages/ExperiencesRound02/VoxelOrigami/CoreTests/{VoxelOrigamiLightsTests, VoxelOrigamiSoundRecipeTests}.swift new (agent B)
Packages/ExperiencesRound02/VoxelOrigami/Experience/VoxelOrigamiSound.swift         new   (lead)
Packages/ExperiencesRound02/VoxelOrigami/Experience/{VoxelOrigamiPresenter, VoxelOrigamiControls, VoxelOrigamiVoxelScene}.swift  edit (lead)
Packages/ExperiencesRound02/VoxelOrigami/ExperienceTests/VoxelOrigamiAccessibilityTests.swift                 new (agent C)
docs/architecture/moonlit-mechanism.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md       edit (lead)
```

**Dependency graph**: package dependency → {feedback plan, lights, recipes} → scene and presenter wiring → panel →
accessibility tests. **Migration**: none. **Rollback**: revert the commits; no stored data or state changes. **CI**: the
round-two host suite, the script tests and the steering validators run on every push; the simulator suite runs locally.

## Parallel work

Agents A (feedback plan) and B (lights, recipes) work in isolated copies in parallel; the lead edits the package,
scene, sound player and presenter against their contracts; agent C writes the simulator accessibility tests given the
presenter's exact texts; the lead retests every result and records only after every agent has reported.
