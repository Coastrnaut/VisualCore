# Implementation Plan: Digital Aquarium — Phase 04 Lighting, particles and accessibility

**Branch**: `071-da-p04-waterfx` (spec directory only; work on `main`) | **Date**: 2026-11-14 | **Spec**: [spec.md](spec.md)

## Summary

Close G-WATERFX and G-HABITATA11Y in the experience, with no VisualCore change. In `DigitalAquariumCore`: catalog
`StarterHabitat.vents` (x positions; two per bundled habitat; validated by `CatalogDecoder`), `WaterEffects` (pure:
bubbles and motes as functions of the step count, depth layers by index with scale and tint), `AquariumWording`
(description pieces and change sentences) and `AquariumAnnouncer` (interval 3 s, VoiceOver gate, latest change wins).
In the experience: a caustics `FullScreenShaderScene` from inline source draws the water and the gravel with the light
pattern (time = step ÷ 60 × 0.4, frozen under Reduce Motion, strength by lighting) and falls back to the Phase 03 clear
and gravel rectangle on `errorMessage`; the presenter orders fish and plants by depth layer, draws bubbles and motes as
circles, uses `AquariumWording` for the description and feeds `AquariumAnnouncer` from state changes into an injected
`AnnouncementSink`. Fixture 11 runs bubbles and motes over 600 steps; a session test restores unknown content.
Research: [research.md](research.md). Data: [data-model.md](data-model.md). API: [contracts/api.md](contracts/api.md).

## Technical Context

**Language**: Swift 6, GLSL ES 3.0 (inline). **Dependencies**: as A09-P03; `FullScreenShaderScene`, `ShaderBundle`
(VisualCoreRendering), `AnnouncementSink`, `SystemAnnouncementSink` (VisualCoreUI; as Oscilloscope Studio uses them) —
all verified in the clarification session. **Storage**: unchanged (no schema change; bubbles, motes, layers and
caustics are derived, never saved). **Testing**: ExperiencesCreative on sim-27.2 (core and experience tests); app build
and unit; runner iOS 27; script tests. **Performance**: ≤ 48 bubbles + 24 motes circles and one full-screen pass per
frame. **Constraints**: tests < 10 s; iOS 27 only; quality levels in A09-P05; no NEEDS CLARIFICATION remains.

## Constitution Check

I PASS (the shader runs through the host's render context and the existing full-screen scene; no second context) · II
PASS (effects, wording and announcer are experience domain over shared VisualCore types) · II-a PASS (no VisualCore
change) · III PASS (effects derive from the step count, so suspension and pause hold them; teardown releases the shader
program) · IV PASS (pure core functions host-testable) · V PASS (no schema change) · VI PASS (render tests on sim-27.2:
layers, caustics change and stillness, fallback) · VII PASS (description and announcements; Reduce Motion) · VIII PASS
(no data, permission or network) · IX PASS (particle caps, shader failure fallback, unknown content refused or
skipped) · X–XIII PASS. A09 rules: procedural content, no flashing — PASS. Post-design: PASS.

## Project Structure

```text
Packages/ExperiencesCreative/DigitalAquarium/Core/SpeciesCatalog.swift (StarterHabitat.vents, bundled vents)  modify
Packages/ExperiencesCreative/DigitalAquarium/Core/CatalogDecoder.swift (vents validated)                      modify
Packages/ExperiencesCreative/DigitalAquarium/Core/WaterEffects.swift                                          new
Packages/ExperiencesCreative/DigitalAquarium/Core/AquariumWording.swift                                       new
Packages/ExperiencesCreative/DigitalAquarium/Core/AquariumAnnouncer.swift                                     new
Packages/ExperiencesCreative/DigitalAquarium/CoreTests/{WaterEffectsTests,AquariumWordingTests,
  AquariumAnnouncerTests,UnknownContentTests}.swift                                                           new
Packages/ExperiencesCreative/DigitalAquarium/Experience/CausticsScene.swift                                   new
Packages/ExperiencesCreative/DigitalAquarium/Experience/AquariumPresenter.swift (layers, bubbles, motes,
  caustics with fallback, wording, announcer)                                                                  modify
Packages/ExperiencesCreative/DigitalAquarium/Experience/DigitalAquariumExperience.swift (sink injection)       modify
Packages/ExperiencesCreative/DigitalAquarium/Experience/Adapter/AquariumManifest.swift (fixture 11)            modify
Packages/ExperiencesCreative/DigitalAquarium/ExperienceTests/{AquariumRenderTests,AquariumSessionTests,
  AquariumManifestTests}.swift                                                                                 modify
Packages/ExperiencesCreative/DigitalAquarium/ExperienceTests/AquariumAnnouncementTests.swift                  new
Packages/ExperiencesCreative/DigitalAquarium/scenario-manifest.json                                           regenerate
docs/apps/digital-aquarium/content-licenses.md (if vents change the generated text)                           regenerate
docs/apps/digital-aquarium/visualcore-contract.{json,md} (G-WATERFX, G-HABITATA11Y closed)                   modify
```

**Dependency direction**: experience → DigitalAquariumCore → VisualCoreMath, VisualCoreSimulation; experience →
VisualCoreRendering (`FullScreenShaderScene`), VisualCoreUI (`AnnouncementSink`); nothing in VisualCore depends on the
aquarium.

**Lifecycle**: the caustics scene is set up with the presenter's `setup`, resized with `resize`, released in
`teardown`; a context loss rebuilds it from the state like every other resource. The announcer's reference state is
reset on teardown and habitat restore; the first frame announces nothing. **Migration**: none. **Rollback**: revert the
commits.

## Build and evidence

See [quickstart.md](quickstart.md); each command runs through
`python3 Tools/python/desktop_runbook.py run-check --stage A09-P04 --timeout 600 --name <check> -- <command>`.

## Parallel work

Agent A: catalog vents, `WaterEffects` and tests; `UnknownContentTests`. Agent B: `AquariumWording`,
`AquariumAnnouncer` and tests. Agent C (after A, B): `CausticsScene`, presenter integration, render and announcement
tests. Lead: experience factory injection, manifest fixture 11, session test, docs, contract, runs, commits.
