# Implementation Plan: Light Maze — Phase 04 Hints, accessibility and visual polish

**Branch**: `099-lm-p04-feedback` (spec directory only; work on `main`) | **Date**: 2026-11-15 | **Spec**: [spec.md](spec.md)

## Summary

Close G-FEEDBACK in the experience, with no VisualCore change: in the core, a pure hint (first turnable tile that
differs from the level's recorded solution), the board description (summary and full text, at most 4,000 characters)
and the success-cue rules (border brightness over time under Reduce Motion and Reduce Flashing; the words); in the
experience, the engine action `hint.show`, Hint and Describe controls, the success cue (border with tick, sound through
a sink over `SoundEffectPlayer`, `success` haptic through `ExperienceFeedback`, words), the Reduce Motion and Reduce
Flashing flags passed from `make`, the nine state signs checked by `stateSignProblems` and contrasts by
`contrastRatio`, and a raised unlit-target colour. Research: [research.md](research.md). Data:
[data-model.md](data-model.md). Contract: [contracts/feedback.md](contracts/feedback.md).

## Technical Context

**Language**: Swift 6. **Dependencies** (verified in code, clarification session): `VisualCoreSimulation`
(`HapticKind.success`, `StateSign`, `stateSignProblems(_:)`, `transitionDuration(_:reduceMotion:)`),
`VisualCoreAudioDSP` (`SoundEffect`, `SoundWaveform`), `VisualCoreAudio` (`SoundEffectPlayer`, ambient session),
`VisualCoreExperienceHost` (`ExperienceFeedback.haptic(_:)`), `VisualCoreUI`
(`AccessibilitySettingsSection.contrastRatio(_:_:)`, tests only), the A13-P01–P03 core and experience.
**Storage**: none new; state schema stays 2 (a hint changes only the selection). **Testing**: ExperiencesCreative on
sim-27.2; app build and unit; runner iOS 27; packages; contract; script tests. **Performance**: the description is
built on request only; the cue adds one border node and one tick polyline; one sound and one haptic per solve.
**Constraints**: tests < 10 s; iOS 27 only; no NEEDS CLARIFICATION remains.

## Constitution Check

I PASS (one app; experience module only) · II PASS (framework planners, sound and feedback reused; nothing upstream)
· II-a N/A · III PASS (code-made sound and shapes) · IV PASS (hint, description and cue rules tested without GPU)
· V PASS (state schema unchanged; manifest fixtures re-pinned only where the hint fixture is added) · VI PASS
· VII PASS (Hint and Describe controls with labels; colour plus sign; Reduce Motion and Reduce Flashing honoured;
no flashing) · VIII PASS (no network, no new data) · IX PASS (bounded description; one cue per solve) · X PASS
· XI–XIII PASS. A13 rules: deterministic rules (the hint is a pure function of level and orientations), offline —
PASS. Post-design: PASS.

## Project Structure

```text
Packages/ExperiencesCreative/LightMaze/Core/Hint.swift                                                     new
Packages/ExperiencesCreative/LightMaze/Core/BoardDescription.swift                                         new
Packages/ExperiencesCreative/LightMaze/Core/SuccessCue.swift                                               new
Packages/ExperiencesCreative/LightMaze/CoreTests/{HintTests,BoardDescriptionTests,SuccessCueTests}.swift   new
Packages/ExperiencesCreative/LightMaze/Experience/MazeSound.swift (sink protocol + SoundEffectPlayer sink)   new
Packages/ExperiencesCreative/LightMaze/Experience/MazeStyle.swift (nine state signs and colours)             new
Packages/ExperiencesCreative/LightMaze/Experience/{Adapter/MazeCore,Adapter/MazeManifest,MazePresenter,MazeControls,
  LightMazeExperience}.swift                                                                                modify
Packages/ExperiencesCreative/LightMaze/ExperienceTests/{MazeHintTests,MazeFeedbackTests,MazeStyleTests}.swift new
Packages/ExperiencesCreative/LightMaze/ExperienceTests/{MazeCoreTests,MazeManifestTests,MazeTestSupport}.swift modify
Packages/ExperiencesCreative/LightMaze/scenario-manifest.json                                               regenerate
docs/apps/light-maze/visualcore-contract.json (G-FEEDBACK closed by A13-P04; rows M09, M10, M17)            modify
```

**Dependency direction**: unchanged — LightMazeCore depends on VisualCoreMath only (the cue rules are plain Swift);
LightMazeExperience adds VisualCoreAudio and VisualCoreAudioDSP to its existing VisualCore dependencies if not already
present (Package.swift checked at implementation; ExperiencesCreative already links them for Neon Arcade).
**Lifecycle**: `make(id:storage:reduceMotion:reduceFlashing:)` passes the flags into the presenter; the presenter
detects the solve transition in `draw` (as A13-P03), then plays the cue once: words to the spoken list and message
(posted while VoiceOver runs), sound to the sink, `success` haptic through the feedback route, and starts the border
clock (frame time); `suspended()` stops the sink and ends the brightening; a resumed solved board keeps the static
border. **Migration**: none (state schema 2 kept). **Rollback**: revert the commits; no data format changed.

## Parallel work

Agent A: core (`Hint`, `BoardDescription`, `SuccessCue`, core tests). Agent B: experience styles (`MazeStyle`,
`MazeStyleTests`, colours). Lead (after A): adapter `hint.show`, presenter cue and controls, sound sink, manifest,
experience tests, contract, runs, commits.
