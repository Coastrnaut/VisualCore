# Implementation Plan: Neon Arcade — Phase 03 Visual effects and audio/haptics

**Branch**: `077-na-p03-effects` (spec directory only; work on `main`) | **Date**: 2026-11-14 | **Spec**: [spec.md](spec.md)

## Summary

Close G-SOUNDFX upstream: `SoundEffect` and `SoundEffectSynth` in `VisualCoreAudioDSP` (pure, host-tested) and
`SoundEffectPlayer` in `VisualCoreAudio` (system audio engine, ambient category, 4 voices, stop on interruption and
background; simulator-tested). Close G-TRANSITIONS app-local: `ArcadeScreen` and the flow rules in `NeonArcadeCore`
(`ArcadeFlow`), snapshot schema 3 (`screen`, `sound`, `haptics`; migration 2 → 3), actions `run.start`,
`settings.sound`, `settings.haptics`, the screen rules for `run.pause`/`run.restart`. Effects app-local:
`ArcadeEffects` (core: event → effect plan with per-step caps, the four sound shapes and haptic kinds) and the
presenter's particle bursts (`ParticleSystem` + `ParticleRenderer`), hit ring, tint (or outline under reduced
flashing), wave sweep, title/paused/game-over screens with cross-fades, sound through `SoundEffectPlayer`, haptics
through `ExperienceFeedback`. The high-speed fixture is a core test (`HighSpeedFixtureTests`) plus manifest fixture 12.
Research: [research.md](research.md). Data: [data-model.md](data-model.md). API: [contracts/api.md](contracts/api.md).

## Technical Context

**Language**: Swift 6. **Dependencies**: `VisualCoreAudioDSP` (new synth), `VisualCoreAudio` (new player; AVFAudio is
already linked), `VisualCoreSimulation` (`ParticleSystem`, `HapticKind`, `transitionDuration`), `VisualCoreRendering`
(`ParticleRenderer`, `PrimitiveRenderer`), `VisualCoreExperienceHost` (`ExperienceFeedback`), as before.
**Storage**: snapshot schema 3. **Testing**: host `swift test --package-path Packages/VisualCore --filter
SoundEffectSynthTests`; rendering package on sim-27.2 `--only-testing VisualCoreAudioTests/SoundEffectPlayerTests`;
ExperiencesCreative on sim-27.2; public API; app build and unit; runner iOS 27; package check; contract; script tests.
**Performance**: synth renders ≤ 1 s at 48 kHz (≤ 48,000 samples) per effect, once and cached; ≤ 3 bursts and 2
sounds per step; particle pool 256. **Constraints**: tests < 10 s; iOS 27; reference regression and iOS 26 at X-A10;
no NEEDS CLARIFICATION remains.

## Constitution Check

I PASS (particles and shapes through the host's renderers; no context) · II PASS (generic synth and player in
VisualCore audio; flow, effect plans and sound choices in the experience) · II-a PASS (VisualCore change documented,
API baseline updated; reference regression at X-A10) · III PASS (only `playing` advances; the player stops on
interruption and background) · IV PASS (synth, flow and effect plans tested without GPU or audio hardware) · V PASS
(schema 3 with 2 → 3 migration; schema-1 example still restores through 1 → 2 → 3) · VI PASS (render and player tests
on the simulator) · VII PASS (screens spoken and with native controls; Reduce Motion and reduced flashing honoured) ·
VIII PASS (ambient category, no input, no permission, no network) · IX PASS (voice, burst and particle caps) · X PASS
(sounds and effects are code) · XI–XIII PASS. A10 rules: visuals and sounds are code; readability over effects
(effects below collision shapes); truthful — PASS. Post-design: PASS.

## Project Structure

```text
Packages/VisualCore/Sources/VisualCoreAudioDSP/SoundEffect.swift                                         new
Packages/VisualCore/Tests/VisualCoreAudioDSPTests/SoundEffectSynthTests.swift                            new
Packages/VisualCoreRendering/Sources/VisualCoreAudio/SoundEffectPlayer.swift                             new
Packages/VisualCoreRendering/Tests/VisualCoreAudioTests/SoundEffectPlayerTests.swift                     new
Packages/VisualCore/README.md (sound effects), API baseline                                               modify
Packages/ExperiencesCreative/Package.swift (NeonArcadeExperience + VisualCoreAudio, VisualCoreAudioDSP)  modify
Packages/ExperiencesCreative/NeonArcade/Core/{ArcadeFlow,ArcadeEffects}.swift                            new
Packages/ExperiencesCreative/NeonArcade/CoreTests/{ArcadeFlowTests,ArcadeEffectsTests,
  HighSpeedFixtureTests}.swift                                                                           new
Packages/ExperiencesCreative/NeonArcade/Experience/Adapter/{ArcadeCore,ArcadeManifest}.swift            modify
Packages/ExperiencesCreative/NeonArcade/Experience/{ArcadePresenter,ArcadeControls}.swift               modify
Packages/ExperiencesCreative/NeonArcade/Experience/ArcadeEffectsLayer.swift                              new
Packages/ExperiencesCreative/NeonArcade/ExperienceTests/* (flow, effects, settings, migration)           modify/new
Apps/VisualCore/App/ExperienceRegistry.swift (schema-2 example)                                          modify
docs/apps/neon-arcade/visualcore-contract.json (G-SOUNDFX, G-TRANSITIONS closed; G-COLLISION2D test note) modify
```

**Dependency direction**: NeonArcadeExperience → NeonArcadeCore, VisualCoreAudio, VisualCoreAudioDSP, VisualCore
products; NeonArcadeCore → VisualCoreSimulation, VisualCoreMath (the core names sound shapes as plain values that the
experience maps to `SoundEffect`); nothing in VisualCore depends on the experience. **Lifecycle**: the presenter
creates the player in setup and calls `stopAll()` in teardown and on suspension; particles live in the presenter and
are rebuilt from nothing after a context loss (effects are not saved). **Migration**: snapshot 2 → 3 (schema-1 data
passes 1 → 2 → 3). **Rollback**: revert; VisualCore additions are additive.

## Parallel work

Agent A: VisualCore synth + player + tests. Agent B: core flow, effects and the high-speed fixture + tests. Agent C:
experience (snapshot 3, actions, presenter effects and screens, controls, manifest) after B. Lead: Package.swift,
registry, README, API baseline, contract, regenerations, runs, commits.
