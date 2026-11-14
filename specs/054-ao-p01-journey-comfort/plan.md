# Implementation Plan: Audio Odyssey — Phase 01 Journey/camera comfort contract

**Branch**: `054-ao-p01-journey-comfort` (spec directory only; work on `main`) | **Date**: 2026-11-14 | **Spec**: [spec.md](spec.md)

## Summary

Close G-CAMERARAIL and G-ORIGINREBASE in `VisualCoreMath` (pure, no dependencies): `CameraRail` (closed centripetal
Catmull–Rom, arc-length table, level frame, `orbitCamera(at:)`), `ComfortLimits` (standard, reduced motion),
`RailFlight` (eased speed under the limits, capped time step, sway) and `OriginRebase` (1,024-unit snapping). Create
the experience `a07.audio-odyssey` in `Packages/ExperiencesCreative/AudioOdyssey`: Core (`JourneyWorld`,
`JourneyState` schema 1, `JourneyRail` seeded control points, `WorldPieces` for tunnel, landscape and star corridor),
Experience (adapter `AudioOdysseyCore`, manifest, presenter drawing the 10-piece window through `DepthMeshPass` with
the rail's `OrbitCamera`, controls), registered as a candidate with nine standard scenarios and two fixture
scenarios. Research: [research.md](research.md).

## Technical Context

**Language**: Swift 6. **Dependencies**: `VisualCoreMath`, `VisualCoreSimulation` (`SeededRandom`), `VisualCoreScenes`
(`Mesh`, `MeshBudget`), `VisualCoreRendering` (`DepthMeshPass`, `MeshRenderer`), `VisualCoreExperience`,
`VisualCoreExperienceHost`, `VisualCoreUI`. **Storage**: experience snapshot (`JourneyState` schema 1); no files.
**Testing**: host `swift test` (VisualCoreMath rail/comfort/rebase; AudioOdyssey core: rail generator, pieces,
journey); ExperiencesCreative on sim-27.2 (adapter, manifest, session, render); app build and unit; runner iOS 27;
public API; script tests. **Performance**: piece median < 2 ms on host (measured; no wall-clock assert on CI).
**Constraints**: tests < 10 s; iOS 27 only; reference regression at X-A07; no NEEDS CLARIFICATION remains.

## Constitution Check

I PASS (draws through the host's `DepthMeshPass`, no context) · II PASS (rail, comfort, rebasing in VisualCore; worlds,
copy and UI in the experience) · II-a PASS (regression at X-A07, owner ruling) · III PASS (flight paused on suspend,
resumed on activate) · IV PASS (rail, pieces and journey host-tested) · V PASS (snapshot schema 1) · VI PASS (render
tests on the simulator) · VII PASS (controls for every action; spoken canvas; Reduce Motion) · VIII PASS (no data, no
permission) · IX PASS (piece budget, capped time step, NaN rejected) · X PASS (no assets) · XI–XIII PASS. A07 rules:
comfort (eased, capped, horizon lock, Reduce Motion), bounded resources, no claims — PASS. Post-design: PASS.

## Project Structure

```text
Packages/VisualCore/Sources/VisualCoreMath/{CameraRail,ComfortLimits,RailFlight,OriginRebase}.swift            new
Packages/VisualCore/Tests/VisualCoreMathTests/{CameraRailTests,RailFlightTests,OriginRebaseTests}.swift         new
Packages/ExperiencesCreative/AudioOdyssey/Core/{JourneyWorld,JourneyState,JourneyRail,WorldPieces}.swift       new  domain
Packages/ExperiencesCreative/AudioOdyssey/CoreTests/{JourneyStateTests,JourneyRailTests,WorldPiecesTests}.swift new
Packages/ExperiencesCreative/AudioOdyssey/Experience/{Adapter/AudioOdysseyCore.swift,Adapter/AudioOdysseyManifest.swift,
  AudioOdysseyPresenter.swift,AudioOdysseyControls.swift,AudioOdysseyExperience.swift}                         new
Packages/ExperiencesCreative/AudioOdyssey/ExperienceTests/{AudioOdysseyCoreTests,AudioOdysseyManifestTests,
  AudioOdysseySessionTests,AudioOdysseyRenderTests}.swift, Packages/ExperiencesCreative/AudioOdyssey/scenario-manifest.json  new
Packages/ExperiencesCreative/Package.swift, Catalog/registrations.json, Apps/VisualCore/App/ExperienceRegistry.swift
  (candidate), project.yml (dependency)                                                                         modify
docs/api/visualcore-public-api.txt, Packages/VisualCore/README.md, docs/apps/audio-odyssey/visualcore-contract.json
  (G-CAMERARAIL, G-ORIGINREBASE closed)                                                                         modify
```

**Dependency direction**: AudioOdysseyExperience → AudioOdysseyCore → VisualCoreMath/Simulation/Scenes; experience →
VisualCore host and rendering; nothing in VisualCore depends on the experience.

**Lifecycle**: the presenter owns one `RailFlight`, the `JourneyRail`, a piece cache keyed by (world, index) for the
current window and one `MeshRenderer` per cached piece, created in setup or on first use after the host's context is
current and released in teardown; activate resumes, suspend pauses; the core advances only by host steps.
**Migration**: none (new schema 1). **Rollback**: revert the commits.

## Parallel work

Agent A: VisualCoreMath rail, comfort, flight, rebase + tests. Agent B: AudioOdyssey Core + CoreTests (against
the contract in contracts/api.md). Agent C: Experience target (adapter, manifest, presenter, controls) + tests after A
and B land. Lead: Package.swift, registrations, registry, project.yml, xcodegen, manifest regeneration, docs and API
baseline, runs, commits.
