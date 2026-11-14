# Implementation Plan: Audio Odyssey — Phase 02 Streaming procedural tunnel

**Branch**: `055-ao-p02-streaming-tunnel` (spec directory only; work on `main`) | **Date**: 2026-11-14 | **Spec**: [spec.md](spec.md)

## Summary

Close G-SEGMENTSTREAM in `VisualCoreScenes` (`SegmentWindow`, `SlotPool`) and G-RAILDRAW in `VisualCoreRendering`
(`MeshFog`; additive view/projection overloads of `MeshRenderer.draw` and `DepthMeshPass.draw` with linear fog). In the
experience: the tunnel streams through the window with one pooled `MeshRenderer` per slot and is drawn with the rail's
view and projection and fog; `TunnelResponse` (Core, pure) turns two `AudioMapper` outputs into bounded, step-limited
ripple and brightness; the presenter owns an audio source (demo default, microphone with permission, file) and one
`SampleRingBuffer`, analyses with `FeatureExtractor` each frame, and applies the response at draw time. Research:
[research.md](research.md).

## Technical Context

**Language**: Swift 6, GLSL ES 3.0. **Dependencies (new for the experience)**: `VisualCoreAudio`, `VisualCoreAudioDSP`.
**Storage**: snapshot schema 2 (adds `source` to `JourneyState`; schema-1 payloads read as demo). **Testing**: host
`swift test` (SegmentWindow, SlotPool); VisualCoreRendering on sim-27.2 (fog and overload pixel tests, unchanged
orbit-camera pixels); ExperiencesCreative on sim-27.2 (TunnelResponse core tests, experience tests: streaming bound,
fog frame, audio response with demo/tone/silence, source switching with permission doubles, migration of schema 1);
app build and unit; runner iOS 27; public API; script tests. **Constraints**: tests < 10 s; iOS 27 only; reference
regression at X-A07; no NEEDS CLARIFICATION remains.

## Constitution Check

I PASS (one host context; drawing passes extended, not replaced) · II PASS (window, pool, fog and free camera in
VisualCore; mapping table, response bounds and UI in the experience; audio reused) · II-a PASS (regression at X-A07) ·
III PASS (source stopped on teardown, restarted on activate) · IV PASS (window, pool, response host- or sim-tested
without GPU dependence for the logic) · V PASS (schema 2 with schema-1 migration example) · VI PASS · VII PASS (source
buttons labelled; Reduce Motion and Reduce Flashing honoured; spoken description includes source) · VIII PASS
(microphone only with permission, demo without it, nothing recorded) · IX PASS (pool capacity, builds per step, clamps)
· X PASS (generated test audio only) · XI–XIII PASS. A07 rules: comfort (audio never moves the camera), audio privacy,
bounded resources — PASS. Post-design: PASS.

## Project Structure

```text
Packages/VisualCore/Sources/VisualCoreScenes/{SegmentWindow,SlotPool}.swift                                   new
Packages/VisualCore/Tests/VisualCoreScenesTests/{SegmentWindowTests,SlotPoolTests}.swift                      new
Packages/VisualCoreRendering/Sources/VisualCoreRendering/{MeshFog.swift}                                       new
Packages/VisualCoreRendering/Sources/VisualCoreRendering/{MeshRenderer,DepthMeshPass}.swift                    modify (additive)
Packages/VisualCoreRendering/Tests/VisualCoreRenderingTests/MeshFogTests.swift                                new
Packages/ExperiencesCreative/AudioOdyssey/Core/{TunnelResponse,SourceKind}.swift, Core/JourneyState.swift (schema 2) new/modify
Packages/ExperiencesCreative/AudioOdyssey/CoreTests/{TunnelResponseTests}.swift, JourneyStateTests.swift      new/modify
Packages/ExperiencesCreative/AudioOdyssey/Experience/{OdysseyPresenter,OdysseyControls}.swift, Adapter/OdysseyCore.swift,
  Adapter/OdysseyManifest.swift                                                                                modify
Packages/ExperiencesCreative/AudioOdyssey/ExperienceTests/{OdysseyStreamingTests,OdysseyAudioTests}.swift       new
Packages/ExperiencesCreative/Package.swift (audio deps), Apps/VisualCore/App/ExperienceRegistry.swift (schema-1 example),
  Catalog/registrations.json (permissions: microphone), scenario-manifest.json                                 modify
docs/api/visualcore-public-api.txt, Packages/VisualCore/README.md, Packages/VisualCoreRendering/README.md,
  docs/apps/audio-odyssey/visualcore-contract.json (G-SEGMENTSTREAM, G-RAILDRAW closed)                       modify
```

**Dependency direction**: AudioOdysseyExperience → AudioOdysseyCore → VisualCoreMath/Simulation/Scenes/AudioDSP;
experience → VisualCoreAudio, VisualCoreRendering, host; nothing in VisualCore depends on the experience.

**Lifecycle**: the presenter owns the active `AudioSource` (started on activate, stopped on suspend and teardown; the
microphone released), one `SampleRingBuffer`, one `FeatureExtractor`, the `SegmentWindow` and a `SlotPool` of
`MeshRenderer`s created after the context is current and released in teardown. **Migration**: snapshot schema 1 →
2 adds `source = demo`. **Rollback**: revert the commits.

## Parallel work

Agent A: SegmentWindow + SlotPool + tests (VisualCoreScenes). Agent B: MeshFog + overloads + tests
(VisualCoreRendering). Agent C: Core TunnelResponse, SourceKind, JourneyState schema 2 + tests. Then Agent D:
presenter, controls, adapter, manifest, experience tests. Lead: Package.swift, registry, registrations, docs, API
baseline, runs, commits.
