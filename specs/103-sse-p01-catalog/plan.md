# Implementation Plan: Solar System Explorer — Phase 01 Scientific catalog, units and citation audit

**Branch**: `103-sse-p01-catalog` (spec directory only; work on `main`) | **Date**: 2026-11-15 | **Spec**: [spec.md](spec.md)

## Summary

Build G-CATALOG with no VisualCore change: in the core a validated catalog of the Sun and eight planets with sourced
values (NASA Planetary Fact Sheet, public domain; IAU nominal solar radius), explicit units (km ↔ AU, days ↔ Julian
years), source records, a citation audit with a committed `data-sources.md`, and the state of the experience (selected
body); in the experience a candidate registration with a scenario manifest whose presenter draws a static,
visibility-enhanced line-up of lit UV spheres with procedural colours and shows the selected body's fact card through
native controls. Research: [research.md](research.md). Data: [data-model.md](data-model.md). Contract:
[contracts/catalog.md](contracts/catalog.md).

## Technical Context

**Language**: Swift 6. **Dependencies** (verified in the clarification session): `VisualCoreMath` (`Vec3`, `Mat4`,
`OrbitCamera`), `VisualCoreScenes` (`MeshGenerators.uvSphere`, `Mesh`), `VisualCoreRendering` (`MeshRenderer`,
`DepthMeshPass`, `RenderContext`), `VisualCoreExperience` and `VisualCoreExperienceHost` (core and presenter protocols,
`ExperienceShell`, scenario manifest), `VisualCoreSimulation`, `VisualCoreUI`. **Storage**: none (the session state is
the host's). **Testing**: core host tests (`swift test` copy) and ExperiencesCreative on sim-27.2; app build and unit;
runner iOS 27; packages; contract; script tests. **Performance**: nine spheres of at most 32 × 16 segments; one frame
per state change. **Constraints**: tests < 10 s; iOS 27 only; no NEEDS CLARIFICATION remains.

## Constitution Check

I PASS (one app; candidate experience) · II PASS (mesh, renderer, camera reused; no upstream change needed this phase)
· II-a N/A (no VisualCore change) · III PASS (procedural colours, no textures) · IV PASS (catalog, units, audit and state
tested without GPU) · V PASS (state schema 1; catalog document versioned) · VI PASS · VII PASS (native controls with
labels; not-to-scale legend) · VIII PASS (no network, no data collection) · IX PASS (nine bodies, bounded meshes) · X PASS
· XI–XIII PASS. A14 rules: data with provenance (citation audit), truthful claims (not-to-scale label), deterministic
GPU-free rules — PASS. Post-design: PASS.

## Project Structure

```text
Packages/ExperiencesCreative/SolarSystemExplorer/Core/{Units,BodyCatalog,SourceRecords,CitationAudit,
  SolarState}.swift                                                                                         new domain
Packages/ExperiencesCreative/SolarSystemExplorer/CoreTests/{UnitsTests,BodyCatalogTests,CatalogFixtureTests,
  CitationAuditTests,SolarStateTests}.swift                                                                 new
Packages/ExperiencesCreative/SolarSystemExplorer/Experience/{Adapter/SolarCore.swift,Adapter/SolarManifest.swift,
  SolarPresenter.swift,SolarControls.swift,SolarSystemExplorerExperience.swift}                             new
Packages/ExperiencesCreative/SolarSystemExplorer/ExperienceTests/{SolarCoreTests,SolarManifestTests,
  SolarSessionTests,SolarRenderTests,SolarTestSupport}.swift; SolarSystemExplorer/scenario-manifest.json      new
Packages/ExperiencesCreative/Package.swift, Catalog/registrations.json, Apps/VisualCore/App/ExperienceRegistry.swift
  (candidate), project.yml (dependency), scripts/test_scripts.py (products list), RealCatalogTests (registrations),
  AppModelTests (synthetic candidate id moves past a14)                                                     modify
docs/apps/solar-system-explorer/{data-sources.md (generated), visualcore-contract.json (G-CATALOG closed by A14-P01;
  rows M06, M09, M11, M15, M20), README}                                                                    new/modify
```

**Dependency direction** (targets `SolarSystemExplorerCore`, `SolarSystemExplorerExperience`, their test targets and the
product `SolarSystemExplorerExperience`, as `scripts/check_experience_packages.py` requires; the adapter type is
`SolarCore` so it does not shadow the module): Experience → Core → Foundation only; the experience → scenes, rendering,
host, UI; nothing in VisualCore depends on the experience.

**Lifecycle**: the core holds `SolarState` (selected body index); actions apply at their step; the host's steps change
nothing else. The presenter owns one `MeshRenderer` per body mesh (created when the host's context is current, rebuilt
after a context recreation, released in teardown) and draws through `DepthMeshPass` with a fixed `OrbitCamera`; it reads
the state and never writes it. **Migration**: none (new schema 1). **Rollback**: revert the commits.

## Parallel work

Agent A: Core and CoreTests (contracts/catalog.md). Agent B: Experience target and tests after A lands. Lead:
Package.swift, registrations, registry, project.yml, xcodegen, manifest regeneration, data-sources document, contract,
runs, commits.
