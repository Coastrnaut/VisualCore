# Implementation Plan: Audio Odyssey — Phase 03 Audio envelope mapping

**Branch**: `056-ao-p03-envelope-mapping` (spec directory only; work on `main`) | **Date**: 2026-11-14 | **Spec**: [spec.md](spec.md)

## Summary

Experience-only slice (no VisualCore change). Core gains `AudioEnvelope` (low, mid, high, transient from 16 band
energies, flux and onset; running-peak normalisation; per-channel smoothing), `EnvelopeChannel`, `WorldMapping`
(per world: primary and light ← channel with sensitivity), `WorldResponse` (generalises `TunnelResponse` to the three
worlds' primary and light outputs) and `JourneyState` schema 3 (continuous `speedTarget` 0.5…7, `easing`,
`calmMotion`, mappings per world). The adapter adds `speed.set`, `easing.select`, `comfort.calm`, `mapping.set`,
`mapping.reset`; the presenter feeds the envelope into the active world's response and applies it (tunnel breathing,
landscape vertical swell, star scale; ambient light); the controls add a speed slider, easing picker, calm-motion
toggle and a mapping editor. Research: [research.md](research.md).

## Technical Context

**Language**: Swift 6. **Dependencies**: unchanged (Core: VisualCoreMath, Simulation, Scenes; Experience adds nothing).
**Storage**: snapshot schema 3 with migration examples for schemas 1 and 2. **Testing**: ExperiencesCreative on
sim-27.2 (Core: envelope, mapping, response, schema 3 and migrations; experience: speed/easing/calm, mapping per world,
source switching keeps the host, manifest); app build and unit; runner iOS 27; script tests; public API unchanged.
**Constraints**: tests < 10 s; iOS 27 only; no NEEDS CLARIFICATION remains.

## Constitution Check

I PASS (host drawing only) · II PASS (no generic machinery added; envelope grouping and mapping are experience domain on
top of VisualCoreAudioDSP features) · II-a PASS (no VisualCore change, regression at X-A07 anyway) · III PASS · IV PASS
(envelope, mapping, response pure and tested) · V PASS (schema 3, migrations from 1 and 2) · VI PASS · VII PASS (slider,
pickers and toggle labelled; calm motion; spoken description) · VIII PASS · IX PASS (bounds, step limits, clamps) · X
PASS · XI–XIII PASS. A07 comfort: easing only lowers acceleration; audio never moves the camera — PASS. Post-design: PASS.

## Project Structure

```text
Packages/ExperiencesCreative/AudioOdyssey/Core/{AudioEnvelope,WorldMapping,WorldResponse}.swift                new
Packages/ExperiencesCreative/AudioOdyssey/Core/{JourneyState,TunnelResponse}.swift                              modify (schema 3; TunnelResponse kept as a typealias or replaced by WorldResponse)
Packages/ExperiencesCreative/AudioOdyssey/CoreTests/{AudioEnvelopeTests,WorldMappingTests,WorldResponseTests}.swift, JourneyStateTests.swift  new/modify
Packages/ExperiencesCreative/AudioOdyssey/Experience/{Adapter/OdysseyCore,Adapter/OdysseyManifest,OdysseyPresenter,OdysseyControls}.swift  modify
Packages/ExperiencesCreative/AudioOdyssey/ExperienceTests/{OdysseyComfortTests,OdysseyMappingTests}.swift       new
Apps/VisualCore/App/ExperienceRegistry.swift (schema-1 and schema-2 examples), scenario-manifest.json            modify
```

**Dependency direction**: unchanged. **Lifecycle**: unchanged (envelope state lives in the presenter, rebuilt on
activate). **Migration**: schema 1/2 → 3: speedChoice → speedTarget (2/4/7), easing standard, calmMotion false,
default mappings. **Rollback**: revert the commits.

## Parallel work

Agent A: Core (envelope, mapping, response, schema 3) + tests. Agent B (after A): experience adapter, presenter,
controls, manifest, tests. Lead: registry examples, runs, ticks, commits.
