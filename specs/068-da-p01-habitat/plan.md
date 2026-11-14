# Implementation Plan: Digital Aquarium — Phase 01 Habitat model and content license audit

**Branch**: `068-da-p01-habitat` (spec directory only; work on `main`) | **Date**: 2026-11-14 | **Spec**: [spec.md](spec.md)

## Summary

Close G-HABITAT (app-local). Create the experience `a09.digital-aquarium` in
`Packages/ExperiencesCreative/DigitalAquarium`: Core (`HabitatDocument` schema 1 with `FishAgent`, `PlantPlacement`,
`SwimBounds`; `SpeciesCatalog` with two fish species, two plant kinds and two starter habitats, every item carrying
author and license; validating JSON decoder with named refusal reasons; `LicenseAudit`; `AquariumSimulation` — the
seeded fixed-step bounded wander), Experience (adapter `AquariumCore`, manifest, presenter drawing water, gravel,
plants and fish as polygons through `PrimitiveRenderer`, controls), registered as a candidate with nine standard
scenarios and five fixtures. Generated `docs/apps/digital-aquarium/content-licenses.md`. No VisualCore change.
Research: [research.md](research.md).

## Technical Context

**Language**: Swift 6. **Dependencies**: `VisualCoreSimulation` (`SeededRandom`, its saved `State`), `VisualCoreMath`
(`Vec2`, `Camera2D`), `VisualCoreScenes` (`SceneNode`, `Primitive.polygon`/`.rect`/`.polyline`), `VisualCoreRendering`
(`PrimitiveRenderer`), `VisualCoreExperience`, `VisualCoreExperienceHost`, `VisualCoreUI`. **Storage**: experience
snapshot (schema 1); no files written. **Testing**: ExperiencesCreative on sim-27.2 (DigitalAquarium core: document,
catalog, audit, simulation; adapter, manifest, session, render); app build and unit; runner iOS 27; experience package
check; contract; script tests. **Performance**: 36 shapes per frame at most; 10,000-step runs measured on the
simulator (no wall-clock assert). **Constraints**: tests < 10 s; iOS 27 only; reference regression at X-A09; no NEEDS
CLARIFICATION remains.

## Constitution Check

I PASS (draws through the host's `PrimitiveRenderer`, no context) · II PASS (reuses seeded random, scenes, renderer,
storage; habitat, catalog and wander are experience domain; steering stays for VisualCore in A09-P02) · II-a PASS
(no VisualCore change; regression at X-A09) · III PASS (simulation advances only by host steps; suspension stops it) ·
IV PASS (document, catalog, audit and simulation tested without GPU) · V PASS (snapshot schema 1 with migration chain)
· VI PASS (render tests on the simulator) · VII PASS (controls for every action; spoken canvas) · VIII PASS (no
permission, no network) · IX PASS (fish ≤ 24, plants ≤ 12, shapes ≤ 36 + background) · X PASS (all content original,
MIT, recorded) · XI–XIII PASS. A09 rules: visuals as code, truthful (descriptive names, no care claims), licenses —
PASS. Post-design: PASS.

## Project Structure

```text
Packages/ExperiencesCreative/DigitalAquarium/Core/{HabitatDocument,SpeciesCatalog,CatalogDecoder,LicenseAudit,
  AquariumSimulation}.swift                                                                                     new domain
Packages/ExperiencesCreative/DigitalAquarium/CoreTests/{HabitatDocumentTests,SpeciesCatalogTests,LicenseAuditTests,
  AquariumSimulationTests}.swift                                                                                new
Packages/ExperiencesCreative/DigitalAquarium/Experience/{Adapter/AquariumCore.swift,Adapter/AquariumManifest.swift,
  AquariumPresenter.swift,AquariumControls.swift,DigitalAquariumExperience.swift}                               new
Packages/ExperiencesCreative/DigitalAquarium/ExperienceTests/{AquariumCoreTests,AquariumManifestTests,
  AquariumSessionTests,AquariumRenderTests,AquariumTestSupport}.swift; DigitalAquarium/scenario-manifest.json    new
Packages/ExperiencesCreative/Package.swift, Catalog/registrations.json, Apps/VisualCore/App/ExperienceRegistry.swift
  (candidate), project.yml (dependency), scripts/test_scripts.py (products list), RealCatalogTests (registrations),
  AppModelTests (synthetic candidate becomes a10)                                                               modify
docs/apps/digital-aquarium/{content-licenses.md (generated), visualcore-contract.json (G-HABITAT closed)}       new/modify
```

**Dependency direction** (targets `DigitalAquariumCore`, `DigitalAquariumExperience`, their test targets and the
product `DigitalAquariumExperience`, as `scripts/check_experience_packages.py` requires; the adapter type is
`AquariumCore` so it does not shadow the module): DigitalAquariumExperience → DigitalAquariumCore → VisualCoreSimulation,
VisualCoreMath; the experience → scenes, rendering, host, UI; nothing in VisualCore depends on the experience.

**Lifecycle**: the core holds the habitat document and the generator; `update(step:)` advances the simulation one fixed
step (1/60 s, `stepDuration`) unless paused; the host steps only while running, so suspension never fast-forwards. The
presenter owns one `PrimitiveRenderer` created when the host's context is current and released in teardown; it
rebuilds the node tree from the document each frame. **Migration**: none (new schema 1). **Rollback**: revert the
commits.

## Parallel work

Agent A: Core + CoreTests (against contracts/api.md). Agent B: Experience target (adapter, manifest, presenter,
controls) + tests after A lands. Lead: Package.swift, registrations, registry, project.yml, xcodegen, manifest
regeneration, license document, contract, runs, commits.
