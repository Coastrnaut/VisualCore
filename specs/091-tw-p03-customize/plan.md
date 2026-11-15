# Implementation Plan: Tiny Worlds — Phase 03 World customization and persistence

**Branch**: `091-tw-p03-customize` (spec directory only; work on `main`) | **Date**: 2026-11-15 | **Spec**: [spec.md](spec.md)

## Summary

Close G-PROPS, G-LIGHT and G-WORLDDOC in the experience (no VisualCore change): a licensed procedural prop catalog
(tree, rock, house, lantern; one coloured mesh each with a picking box), placement, selection, move, rotate and delete
as replayable actions with the clarified rules, the world light (azimuth, elevation, ambient) applied to every
renderer, `WorldState` schema 2 with props and light (migration 1 → 2), and four saved-world slots with atomic
documents and 160 × 120 PNG thumbnails drawn off screen. Research: [research.md](research.md). Data:
[data-model.md](data-model.md). Contract: [contracts/actions.md](contracts/actions.md).

## Technical Context

**Language**: Swift 6. **Dependencies** (all verified): `VisualCoreScenes` (`MeshShapes.revolution`, `extrusion`,
`bevelledBox`, `MeshGenerators.uvSphere`, `Mesh.validate()`, `MeshBudget`, `HeightField`), `VisualCoreMath` (`Vec3`,
`Vec4`, `Ray3`, `OrbitCamera.ray`), `VisualCoreRendering` (`MeshRenderer(mesh:colors:registry:)` with `lightDirection`,
`ambient`; `DepthMeshPass`; `StillImageEncoder`), `VisualCoreExperienceHost` (`ExperienceSession.renderStill`),
`VisualCoreExperience` (`ExperienceStorage.write` atomic, `MigrationChain`). **Storage**: `world-<slot>.json` (≤ 64 KB)
and `world-<slot>.png` (≤ 64 KB) in the experience's storage; snapshot schema 2. **Testing**: core on the host
scratch package and on sim-27.2; experience on sim-27.2; app build and unit; runner iOS 27; package check; contract;
script tests. **Performance**: ≤ 24 props × ≤ 2,000 vertices; one renderer per prop kind reused with a model matrix per
placed prop; thumbnail once per save. **Constraints**: tests < 10 s; iOS 27 only; no VisualCore change, so no
reference regression is owed for this phase; no NEEDS CLARIFICATION remains.

## Constitution Check

I PASS (host drawing only; thumbnails through the session's still renderer) · II PASS (reuses shapes, colour stream,
rays, storage, stills; content and rules app-local) · II-a PASS (no VisualCore change) · III PASS (edits only by
actions; saving outside the engine) · IV PASS (catalog, placement, light and documents tested without GPU) · V PASS
(schema 2 with migration; older schema restores) · VI PASS (render tests on the simulator) · VII PASS (control
alternatives, spoken refusals) · VIII PASS (local files only) · IX PASS (caps on props, vertices, file sizes) · X PASS
(props and palettes MIT, recorded in the license document) · XI–XIII PASS. Post-design: PASS.

## Project Structure

```text
Packages/ExperiencesCreative/TinyWorlds/Core/{PropCatalog,WorldEditing,WorldLight,WorldDocument}.swift            new
Packages/ExperiencesCreative/TinyWorlds/Core/{WorldState,ContentCatalog,LicenseAudit}.swift                        modify
  (schema 2; prop palettes and prop records in the catalog and audit)
Packages/ExperiencesCreative/TinyWorlds/CoreTests/{PropCatalogTests,WorldEditingTests,WorldLightTests,
  WorldDocumentTests}.swift; WorldStateTests, LicenseAuditTests, ContentCatalogTests                              new/modify
Packages/ExperiencesCreative/TinyWorlds/Experience/{WorldStore.swift (new), Adapter/WorldsCore.swift (actions, schema
  2, migration, examples), Adapter/WorldsManifest.swift (prop fixtures), WorldsPresenter.swift (prop renderers, light,
  tap selection, thumbnails), WorldsControls.swift (prop, light and slot controls), WorldsGestures.swift}            new/modify
Packages/ExperiencesCreative/TinyWorlds/ExperienceTests/{WorldStoreTests (new), WorldsEditingTests (new),
  WorldsCoreTests, WorldsRenderTests, WorldsManifestTests}.swift; scenario-manifest.json (regenerated)               new/modify
Apps/VisualCore/App/ExperienceRegistry.swift (schema-1 example for the migration), Catalog/registrations.json
  (capabilities), docs/apps/tiny-worlds/{content-licenses.md (regenerated), visualcore-contract.json (G-PROPS,
  G-LIGHT, G-WORLDDOC closed by A12-P03)}                                                                          modify
```

**Dependency direction** unchanged. **Lifecycle**: actions change the document; the presenter keeps one renderer per
prop kind (created on first use, rebuilt after context recreation, released in teardown) and draws each placed prop
with its model matrix through the `DepthMeshPass`; the light is read from the state each frame; saving, opening and
clearing slots run in `WorldStore` on the main actor through `ExperienceStorage`; a thumbnail is drawn with
`renderStill(160, 120)` after the document is written. **Migration**: snapshot 1 → 2 (no props, default light); the
saved-world file has its own schema 2. **Rollback**: revert the commits; files written by this phase are ignored by
older builds (unknown names).

## Parallel work

Agent A: core catalog, editing, light, document and their tests. Agent B (after A): experience store, adapter,
presenter, controls, gestures and tests. Lead: catalog and license document, registration example, manifest
regeneration, contract, runs, commits.
