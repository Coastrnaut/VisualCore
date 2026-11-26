# Implementation Plan: R02-G19-06 — Microscopic Aurora: polish and accessibility

**Branch**: `486-microscopic-aurora-polish-and-accessiblity` (spec directory only; work on `main`) | **Date**:
2026-11-26 | **Spec**: [spec.md](spec.md)

## Summary

Give Microscopic Aurora its polish and accessibility, following Apsides Workshop's R02-G18-06 (feature 476): a pure
feedback plan (announcement text and kind, haptic) from the old and new adapter core with the texts of clarification
Q1; light levels for the glow and the won look eased by the frame clock (0.15 s, 0.45 s under Reduce Flashing);
code-made sound recipes (the selected well's audition from its strength, its sense and whether it can be placed, an
ambient loop from the stencil coverage); the scene drawing the eased levels (`u_won` and the glow gain already take
them; the fallback dish blends its not-won and won colours); the presenter routing feedback through the shared route
with a feedback log, a Sound toggle, labels and values on every control, an adjustable slot, site and strength and a
summary element. Research: [research.md](research.md). Data: [data-model.md](data-model.md). API:
[contracts/api.md](contracts/api.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Audit (2026-11-26)**: `MicroscopicAuroraCore` and `MicroscopicAuroraExperience` exist in
`Packages/ExperiencesRound02/Package.swift` and are linked by `project.yml`; Apsides Workshop's Core depends on
VisualCoreAudioDSP and its experience on VisualCoreAudioDSP and VisualCoreAudio (iOS) for the shared ambient player;
`MicroscopicAuroraCore` has neither, so the Core and its tests gain VisualCoreAudioDSP and the experience and its tests
gain VisualCoreAudioDSP and VisualCoreAudio (iOS-conditioned); no new target. The shaders already scale the won look by
`u_won` (0 … 1) and the glow by the glow gain under `u_glowLimit`; nothing in the dish moves by time (no pulse), so
Reduce Motion and Reduce Flashing already give a still dish between actions; the fallback dish part takes a won flag
(`dishPart(_:tier:wonLevel:camera:)`, `wonLevel: Bool?`; the won look changes colours only), so the scene blends the
not-won and won parts' colours by the eased level; no shader or geometry change is needed. The panel's selection (slot,
site, strength, sense) lives in the mirror. **Language/Version**: Swift 6. **Primary dependencies**: the Microscopic
Aurora Core of R02-G19-01 … 05, VisualCoreExperience (`AnnouncementKind`, `HapticKind`), VisualCoreAudioDSP
(`AmbientLoopRecipe`), VisualCoreExperienceHost (`ExperienceFeedback`), VisualCoreAudio (`AmbientLoopPlayer`). No new
package, GLSL change, Objective-C++ or VisualCore API. **Testing**: host `swift test --package-path
Packages/ExperiencesRound02`; simulator package tests on sim-27.2; the app unit tests; regression; script tests alone.
Seed 2_486. **Constraints**: presentation only (no state or digest change); fades 0.15 s / 0.45 s; at most 3 half-range
crossings per second under Reduce Flashing; the audition 0.6 s; the loop rebuilt only on recipe changes; tests under
10 s.

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
Packages/ExperiencesRound02/MicroscopicAurora/Core/MicroscopicAuroraFeedbackPlan.swift   new   (agent A)
Packages/ExperiencesRound02/MicroscopicAurora/Core/MicroscopicAuroraLights.swift         new   (agent B)
Packages/ExperiencesRound02/MicroscopicAurora/Core/MicroscopicAuroraSoundRecipe.swift    new   (agent B)
Packages/ExperiencesRound02/MicroscopicAurora/CoreTests/MicroscopicAuroraFeedbackPlanTests.swift                          new (agent A)
Packages/ExperiencesRound02/MicroscopicAurora/CoreTests/{MicroscopicAuroraLightsTests, MicroscopicAuroraSoundRecipeTests}.swift new (agent B)
Packages/ExperiencesRound02/MicroscopicAurora/Experience/MicroscopicAuroraSound.swift    new   (lead)
Packages/ExperiencesRound02/MicroscopicAurora/Experience/{MicroscopicAuroraPresenter, MicroscopicAuroraControls, MicroscopicAuroraDishScene}.swift  edit (lead)
Packages/ExperiencesRound02/MicroscopicAurora/ExperienceTests/MicroscopicAuroraAccessibilityTests.swift                   new (agent C)
docs/architecture/microscopic-aurora.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md       edit (lead)
```

**Dependency graph**: package dependency → {feedback plan, lights, recipes} → scene and presenter wiring → panel →
accessibility tests. **Migration**: none (snapshot schema 2 unchanged). **Rollback**: revert the commits; no stored
data or state changes. **CI**: the round-two host suite, the script tests and the steering validators run on every
push; the simulator suite runs locally.

## Parallel work

Agents A (feedback plan) and B (lights, recipes) work in isolated copies in parallel; the lead edits the package,
scene, sound player and presenter against their contracts; agent C writes the simulator accessibility tests given the
presenter's exact texts; the lead retests every result and records only after every agent has reported.
