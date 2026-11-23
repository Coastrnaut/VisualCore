# Implementation Plan: R02-G12-06 — Harmonic Bridges: polish and accessibility

**Branch**: `416-harmonic-bridges-polish-and-accessiblity` (spec directory only; work on `main`) | **Date**:
2026-11-23 | **Spec**: [spec.md](spec.md)

## Summary

Give Harmonic Bridges its polish and accessibility, following Echo Cartographer's R02-G11-06 (feature 406) in the same
package: in the host-tested Core a feedback plan (announcement kind and text, haptic kind) computed from the old and new
core, the refusal words and the summary text; eased light levels (glow, won brightening) with the Reduce Flashing fade
rules and a half-range-crossing measure; the audition and ambient sound recipes; in the shaders a won-light uniform so
the won lift fades instead of switching; in the experience the shared feedback route, the sound (audition and ambient
loop through the shared player), the adjustable string and peg, the summary element, the Sound toggle and Dynamic Type
layout; Reduce Flashing also holds the shown step, rests the strings and draws no wave shells. Research:
[research.md](research.md). Data: [data-model.md](data-model.md). API: [contracts/api.md](contracts/api.md). Quickstart:
[quickstart.md](quickstart.md).

## Technical Context

**Audit (2026-11-23)**: `HarmonicBridgesCore` and `HarmonicBridgesExperience` exist in
`Packages/ExperiencesRound02/Package.swift` and are linked by `project.yml`; Echo Cartographer's targets already depend on
VisualCoreAudioDSP (Core) and VisualCoreAudio (Experience) for the shared ambient player, so Harmonic Bridges gains the
same dependencies; no new target.
**Language/Version**: Swift 6. **Primary dependencies**: the Harmonic Bridges Core of R02-G12-01 … 05, VisualCoreExperience
(`AnnouncementKind`, `HapticKind`), VisualCoreAudioDSP (`AmbientLoopRecipe`), VisualCoreExperienceHost
(`ExperienceFeedback`), VisualCoreAudio (`AmbientLoopPlayer`). No new package, GLSL file, Objective-C++ or VisualCore API.
**Testing**: host `swift test --package-path Packages/ExperiencesRound02`; simulator package tests on sim-27.2; the app
unit tests; regression; script tests alone. Seed 2_416.
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
Packages/ExperiencesRound02/Package.swift                                   edit  Core + VisualCoreAudioDSP; Experience + VisualCoreAudio (lead)
Packages/ExperiencesRound02/HarmonicBridges/Core/HarmonicBridgesFeedbackPlan.swift        new   (agent A)
Packages/ExperiencesRound02/HarmonicBridges/Core/HarmonicBridgesLights.swift              new   (agent B)
Packages/ExperiencesRound02/HarmonicBridges/Core/HarmonicBridgesSoundRecipe.swift         new   (agent B)
Packages/ExperiencesRound02/HarmonicBridges/Core/HarmonicBridgesShaders.swift             edit  u_wonLight (lead)
Packages/ExperiencesRound02/HarmonicBridges/CoreTests/HarmonicBridgesFeedbackPlanTests.swift                            new (agent A)
Packages/ExperiencesRound02/HarmonicBridges/CoreTests/{HarmonicBridgesLightsTests, HarmonicBridgesSoundRecipeTests}.swift new (agent B)
Packages/ExperiencesRound02/HarmonicBridges/CoreTests/HarmonicBridgesShaderSourceTests.swift                            edit (lead)
Packages/ExperiencesRound02/HarmonicBridges/Experience/HarmonicBridgesSound.swift         new   (lead)
Packages/ExperiencesRound02/HarmonicBridges/Experience/{HarmonicBridgesPresenter, HarmonicBridgesControls, HarmonicBridgesBridgeScene}.swift  edit (lead)
Packages/ExperiencesRound02/HarmonicBridges/ExperienceTests/HarmonicBridgesAccessibilityTests.swift                     new (agent C)
docs/architecture/harmonic-bridges.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md       edit (lead)
```

**Dependency graph**: package dependency → {feedback plan, lights, recipes} → shader and presenter wiring → panel →
accessibility tests. **Migration**: none. **Rollback**: revert the commits; no stored data or state changes. **CI**: the
round-two host suite, the script tests and the steering validators run on every push; the simulator suite runs locally.

## Parallel work

Agents A (feedback plan) and B (lights, recipes) work in isolated copies in parallel; the lead edits the package, shader,
sound player and presenter against their contracts; agent C writes the simulator accessibility tests; the lead retests
every result and records only after every agent has reported.
