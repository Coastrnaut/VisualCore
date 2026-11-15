# Implementation Plan: Tiny Worlds — Phase 04 Three environment packs

**Branch**: `092-tw-p04-packs` (spec directory only; work on `main`) | **Date**: 2026-11-15 | **Spec**: [spec.md](spec.md)

## Summary

Close G-PACKS in the experience (no VisualCore change): `WorldPack` data for the island, asteroid garden and miniature
city (seed, prop list, light, camera limits, default view, author and license), validated at load against the
placement rules; `world.pack [0…2]` replaces the world with a pack and doubles as "reset to pack"; per-preset camera
limits and a clearance check that also covers props; budgets per pack; digest fixtures. Research:
[research.md](research.md). Data: [data-model.md](data-model.md). Contract: [contracts/actions.md](contracts/actions.md).

## Technical Context

**Language**: Swift 6. **Dependencies** (verified): `TinyWorldsCore` (`WorldState` schema 2, `WorldEditing.place`/
`validate`, `WorldLight`, `WorldView`, `CameraPolicy`, `PropCatalog`, `TerrainGenerator`, `ContentCatalog`,
`LicenseAudit`), `VisualCoreScenes` (`HeightField`, `Mesh`), the experience adapter, manifest, presenter and controls of
A12-P01–P03. **Storage**: unchanged (schema 2). **Testing**: core on the host scratch package and sim-27.2; experience on
sim-27.2; app build and unit; runner iOS 27; package check; contract; catalog host; script tests. **Performance**: per
pack ≤ 16 props, ≤ 30,000 vertices, ≤ 18 draws; the clearance check adds ≤ 16 prop tests per view change.
**Constraints**: tests < 10 s; iOS 27 only; no VisualCore change; no NEEDS CLARIFICATION remains.

## Constitution Check

I PASS (host drawing only) · II PASS (packs are data over existing rules) · II-a PASS (no VisualCore change) · III PASS
(packs open by a replayable action) · IV PASS (packs, limits and clearance tested without GPU) · V PASS (schema 2
unchanged) · VI PASS (render on the simulator) · VII PASS (a control for every pack and reset; spoken) · VIII PASS ·
IX PASS (budgets) · X PASS (packs MIT, in the license document) · XI–XIII PASS. Post-design: PASS.

## Project Structure

```text
Packages/ExperiencesCreative/TinyWorlds/Core/WorldPack.swift                                              new
Packages/ExperiencesCreative/TinyWorlds/Core/{CameraPolicy,WorldView,ContentCatalog,LicenseAudit}.swift     modify
  (per-preset limits, prop-aware clearance, pack records)
Packages/ExperiencesCreative/TinyWorlds/CoreTests/{WorldPackTests (new),CameraPolicyTests,WorldViewTests,
  ContentCatalogTests,LicenseAuditTests}.swift                                                            new/modify
Packages/ExperiencesCreative/TinyWorlds/Experience/{Adapter/WorldsCore.swift (world.pack), Adapter/WorldsManifest.swift
  (pack fixtures), WorldsControls.swift (pack picker, Reset to pack), WorldsPresenter.swift (spoken open, direct move
  under Reduce Motion)}                                                                                     modify
Packages/ExperiencesCreative/TinyWorlds/ExperienceTests/{WorldsPackTests (new),WorldsCoreTests,WorldsManifestTests}.swift
  ; scenario-manifest.json, docs/apps/tiny-worlds/content-licenses.md (regenerated)                      new/modify
Catalog/registrations.json (capabilities), docs/apps/tiny-worlds/visualcore-contract.json (G-PACKS closed; M06)      modify
```

**Lifecycle**: `world.pack` validates the pack (placements re-checked on the pack's terrain), replaces preset, seed,
props, selection, light and view, then applies the camera policy with the preset's limits; the presenter rebuilds the
terrain when the digest changes, as before. **Migration**: none (schema 2; per-preset limits clamp restored views).
**Rollback**: revert the commits.

## Parallel work

Agent A: core (`WorldPack`, policy and catalog changes, tests). Agent B (after A): experience action, controls,
manifest and tests. Lead: registration, regeneration, contract, runs, commits.
