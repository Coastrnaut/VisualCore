# Implementation Plan: VisualCore Music Lab — Phase 03 Three visual scenes and mapping editor

**Branch**: `049-ml-p03-scenes-mapping` (spec directory only; work on `main`) | **Date**: 2026-11-14 | **Spec**: [spec.md](spec.md)

## Summary

VisualCore gains gap G-AUDIOMAP in `VisualCoreAudioDSP`: `AudioFeatureKind` (level, peak, beat, four regions),
`AudioMapping` (feature, gain 0…4, attack, release, clamp within 0…1; Codable, schema 1, validated) and `AudioMapper`
(normalise → gain → clamp → smooth → map into a `ClosedRange<Double>`). The experience gains `MusicLabScene` (bars,
rings, geometry) with per-scene parameter definitions and default mappings in its Core, state schema 2 (scene,
mappings per scene) with a schema-1 migration, three new actions (`scene.select`, `mapping.set`, `mapping.reset`), three
scene drawers in the presenter (bars and rings with `PrimitiveRenderer`, geometry with `DepthMeshPass` and two
`MeshRenderer`s), a mapping editor in the controls, Reduce Motion handling and the scene in the description. The audio
hot path is marked in the three sources and enforced by `scripts/check_audio_hot_path.py` (with script tests), plus a
bounded footprint run on the simulator. G-SIGNALTEXTURE moves to phase 5 in the contract. Research:
[research.md](research.md); model: [data-model.md](data-model.md); contract: [contracts/api.md](contracts/api.md);
evidence: [quickstart.md](quickstart.md).

## Technical Context

**Language**: Swift 6, Python 3 (check script). **Verified APIs**: `AudioFeatures` (`rmsDB`, `peakDB`, `bandEnergies`,
`beatEnergy`), `FeatureSmoother(attack:release:)`/`update(target:elapsed:)`/`reset()`, `MigrationChain(currentVersion:
steps:)`, `ExperienceControl(id:ranges:)` (≤ 24 values), `PrimitiveRenderer` with `.line`/`.polygon`/`.circle`,
`MeshRenderer(mesh:registry:)`, `DepthMeshPass(registry:)`/`draw(_:camera:context:)`/`release()`,
`Mesh.uvSphere(segments:rings:radius:)`, `Mesh.cube()`, `OrbitCamera`, `ProcessMemory.footprint()`, the registry's
`make(id:storage:reduceMotion:reduceFlashing:)` factory. **Storage**: snapshot schema 2 (JSON). **Testing**: host `swift
test` (mapping); ExperiencesCreative on sim-27.2 (state/migration, core, scenes, editor, hot-path footprint);
VisualCoreRendering VisualCoreAudioTests on sim-27.2 (hot-path footprint); app build/unit; runner iOS 27 with the
regenerated manifest; public API; script tests (hot-path check). **Constraints**: tests < 10 s; no wall-clock asserts;
iOS 27 only at this gate; reference regression at X-A06.

## Constitution Check

I PASS (all three scenes drawn through host renderers; the depth target is the host's `DepthMeshPass`) · II PASS
(mapping in VisualCore; scenes, parameters and editor app-local) · II-a PASS (G-AUDIOMAP built; G-SIGNALTEXTURE re-phased
with reason) · III PASS (renderers created in setup, released in teardown; smoothing reset on scene change) · IV PASS
(mapping and state host-tested) · V PASS (schema 2 with migration and refusal of bad payloads) · VI PASS (scene pixels
probed on the simulator) · VII PASS (editor labels/identifiers; Reduce Motion; spoken scene) · VIII PASS (no new
permission) · IX PASS (bounded mappings, validated decoding; no allocation on the audio hot path) · X PASS (procedural
meshes only) · XI–XIII PASS · A06 PASS.

## Project Structure

```text
Packages/VisualCore/Sources/VisualCoreAudioDSP/{AudioFeatureKind,AudioMapping,AudioMapper}.swift        new
Packages/VisualCore/Tests/VisualCoreAudioDSPTests/{AudioMappingTests,AudioMapperTests}.swift            new
Packages/ExperiencesCreative/VisualCoreMusicLab/Core/{MusicLabScene,SceneParameter}.swift               new (scenes, parameters, default mapping slots)
Packages/ExperiencesCreative/VisualCoreMusicLab/Core/MusicLabState.swift                                 modify (scene, mappings; schema 2 coding)
Packages/ExperiencesCreative/VisualCoreMusicLab/CoreTests/{MusicLabSceneTests,MusicLabStateTests}.swift   new / modify
Packages/ExperiencesCreative/VisualCoreMusicLab/Experience/Adapter/MusicLabCore.swift                     modify (actions, migration 1→2, digest)
Packages/ExperiencesCreative/VisualCoreMusicLab/Experience/{MusicLabScenes.swift}                         new (scene drawers)
Packages/ExperiencesCreative/VisualCoreMusicLab/Experience/{MusicLabPresenter,MusicLabControls,VisualCoreMusicLabExperience}.swift  modify
Packages/ExperiencesCreative/VisualCoreMusicLab/ExperienceTests/MusicLabSceneRenderTests.swift  new; MusicLabCoreTests modify
Packages/VisualCoreRendering/Tests/VisualCoreAudioTests/HotPathFootprintTests.swift                      new (footprint over 1,000 blocks)
Packages/ExperiencesCreative/VisualCoreMusicLab/scenario-manifest.json                                    regenerate
Packages/VisualCoreRendering/Sources/VisualCoreAudio/{DemoAudioSource,FileAudioSource,MicrophoneAudioSource}.swift  modify (markers only; cold tags)
scripts/check_audio_hot_path.py, scripts/tests/test_audio_hot_path.py, scripts/test_scripts.py, .github/workflows/ci.yml  new / modify
docs/api/visualcore-public-api.txt, Packages/VisualCore/README.md, Auto-Creator.md §13, docs/apps/visualcore-music-lab/visualcore-contract.{json,md}  modify
```

**Dependency direction**: experience → VisualCoreAudioDSP (mapping) → nothing new; Core stays audio-free (feature
indices as plain integers); nothing in VisualCore depends on the experience.

**Lifecycle**: the presenter builds the scene renderers in `setup` (primitive renderer exists; two mesh renderers and the
depth pass added), draws only the active scene, resets every mapper on a scene change or source change, releases all in
`teardown`. Mappers run once per frame with `frame.delta`. **Migration**: schema 1 → 2 adds `scene: 0` and the default
mappings. **Rollback**: revert the commits; a schema-2 snapshot is refused by a schema-1 build (newer version), so the
experience starts fresh — acceptable for an unreleased candidate.

## Parallel work

Agent A: VisualCoreAudioDSP mapping + tests. Agent B: hot-path script, its tests, markers in the three sources.
Agent C: Core scenes/parameters + tests. Lead: state schema 2 and core actions/migration, presenter scenes, controls,
experience tests, manifest, docs, runs, commits.
