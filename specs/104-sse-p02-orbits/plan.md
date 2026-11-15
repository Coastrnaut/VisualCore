# Implementation Plan: Solar System Explorer — Phase 02 Approximate orbit computation with fixtures

**Branch**: `104-sse-p02-orbits` (spec directory only; work on `main`) | **Date**: 2026-11-15 | **Spec**: [spec.md](spec.md)

## Summary

Build G-ORBIT: in VisualCore's math module a generic `KeplerOrbit` (classical elements, bounded Newton solution of
Kepler's equation, position in the reference frame) with host tests, `///` documentation, a README section and an API
baseline update (the seven-step reference regression runs at X-A14); in the experience core the J2000.0 mean elements
of the eight planets with source records (Standish, JPL; `public-domain`), a bounded simulated date, heliocentric
positions and `SolarState` schema 2 (date and camera, migration from schema 1); in the experience an orbit view (Sun,
planets, 128-sample orbit tubes through the labelled mapping 4·√r), date steps, focus and camera controls and a
schema-2 scenario manifest. Research: [research.md](research.md). Data: [data-model.md](data-model.md). Contracts:
[contracts/kepler-orbit.md](contracts/kepler-orbit.md), [contracts/orbit-view.md](contracts/orbit-view.md).

## Technical Context

**Language**: Swift 6. **Dependencies** (verified in code during clarification): `VisualCoreMath` (`Vec3` in Double,
`OrbitCamera` with distance 0.01…1,000,000 and pitch ±89°), `VisualCoreScenes` (`MeshGenerators.uvSphere`,
`MeshShapes.tube(path:radius:sides:caps:closed:budget:)` throwing `MeshError`), `VisualCoreRendering` (`MeshRenderer`,
`DepthMeshPass`), `VisualCoreExperience`, `VisualCoreExperienceHost`, `VisualCoreUI`. **Storage**: none (session state
in the host). **Testing**: VisualCore host `swift test --package-path Packages/VisualCore --filter KeplerOrbitTests`;
ExperiencesCreative on sim-27.2 (`SolarSystemExplorerCoreTests`, `SolarSystemExplorerExperienceTests`); app build and
unit; runner iOS 27; packages, contract, documented API and public API checks. **Performance**: nine Kepler solutions
per state change (≤ 32 Newton steps each); eight orbit tubes of 128 × 6 built once; one frame per state change.
**Constraints**: tests < 10 s, no wall-clock asserts; iOS 27 only at this gate; reference regression and iOS 26 at
X-A14 (owner ruling 2026-11-14). No NEEDS CLARIFICATION remains.

## Constitution Check

I PASS (one app; candidate experience) · II PASS (camera, meshes, renderer reused) · II-a PASS (additive generic
VisualCore type, documented, tested, baseline updated, nothing existing changes; reference regression at X-A14) · III
PASS (procedural geometry; no textures) · IV PASS (Kepler, elements, dates, positions and state tested without GPU) · V
PASS (state schema 2 with tested migration from 1; catalog document version unchanged, orbit elements a separate
versioned table) · VI PASS · VII PASS (native labelled controls with values; "not to scale" label) · VIII PASS (no
network, no data collection) · IX PASS (bounded iterations and meshes) · X PASS · XI–XIII PASS. A14 rules: provenance for
every element (citation audit extended), truthful "approximate, not to scale" claims, deterministic GPU-free rules —
PASS. Post-design: PASS.

## Project Structure

```text
Packages/VisualCore/Sources/VisualCoreMath/KeplerOrbit.swift                                               new
Packages/VisualCore/Tests/VisualCoreMathTests/KeplerOrbitTests.swift                                       new
Packages/VisualCore/README.md (Kepler orbit section), API baseline (check_public_api.py --update)          modify
Packages/ExperiencesCreative/SolarSystemExplorer/Core/{OrbitElements,SimulatedDate,OrbitModel}.swift       new
Packages/ExperiencesCreative/SolarSystemExplorer/Core/{SolarState,SourceRecords,CitationAudit}.swift       modify
Packages/ExperiencesCreative/SolarSystemExplorer/CoreTests/{OrbitElementsTests,SimulatedDateTests,
  OrbitFixtureTests,SolarStateSchema2Tests}.swift; existing tests adjusted for schema 2 and new records      new/modify
Packages/ExperiencesCreative/SolarSystemExplorer/Experience/{Adapter/SolarCore,Adapter/SolarManifest,
  SolarPresenter,SolarControls}.swift; OrbitLayout.swift (display mapping, camera framing)                 modify/new
Packages/ExperiencesCreative/SolarSystemExplorer/ExperienceTests/{OrbitLayoutTests,SolarOrbitRenderTests}.swift;
  existing core, manifest, session and render tests adjusted                                               new/modify
Packages/ExperiencesCreative/SolarSystemExplorer/scenario-manifest.json (regenerated, schema 2)            modify
docs/apps/solar-system-explorer/{data-sources.md (regenerated), visualcore-contract.json (G-ORBIT closed;
  rows M05, M07, M12), visualcore-contract.md (rendered), README}                                         modify
```

**Dependency direction**: `SolarSystemExplorerCore` → `VisualCoreMath` (new dependency, for `KeplerOrbit`) and
Foundation; Experience → Core, scenes, rendering, host, UI; VisualCoreMath depends on nothing new; nothing in VisualCore
depends on the experience. If the core target does not yet list `VisualCoreMath`, Package.swift gains it.

**Lifecycle**: the core holds `SolarState` schema 2 (selection, dayOffset, yawSteps, pitchDegrees, zoomSteps); actions
apply at their step; positions are a pure function of the date. The presenter creates every renderer once when the
context is current (nine bodies, nine rings, eight orbit tubes), rebuilds them all after a context recreation and
releases them together in teardown — never one at a time, since mesh renderers share a cached program (A14-P01
research, As built). Per frame it reads the state, computes the nine display positions, sets the camera from the
state and the focused body's position, and draws; it never writes state. **Migration**: schema 1 → 2 with dayOffset 0
and the overview camera; documents newer than 2 refused. **Rollback**: revert the commits; the VisualCore addition is
additive, so reverting it touches nothing else.

## Parallel work

Agent A: `KeplerOrbit.swift` and its tests (contracts/kepler-orbit.md). Agent B: core `OrbitElements`,
`SimulatedDate`, `OrbitModel` and core tests (data-model.md). Agent C (after A and B land): experience layout,
presenter, controls and tests (contracts/orbit-view.md). Lead: README, API baseline, Package.swift, `SolarState`
schema 2, source records, manifest regeneration, contract, runs, commits.

## Evidence

Each check through `python3 Tools/python/desktop_runbook.py run-check --stage A14-P02 --timeout 600 --name <n> -- <cmd>`:
`visualcore-kepler` (swift test filter), `visualcore-api` (check_public_api, check_documented_api), `package`
(ExperiencesCreative SSE tests on sim-27.2), `app-unit`, `verify27`, `packages`, `contract`, `scripts`, `docs`.
