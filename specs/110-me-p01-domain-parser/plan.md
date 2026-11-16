# Implementation Plan: Molecular Explorer — Phase 01 Atom/bond domain and strict XYZ parser

**Branch**: `110-me-p01-domain-parser` (spec directory only; work on `main`) | **Date**: 2026-11-15 | **Spec**: [spec.md](spec.md)

## Summary

Build G-ELEMENTS, G-DOMAIN and G-PARSER with no VisualCore change: in the core an element catalog of ten elements with
per-value source records and an element audit with a committed `data-sources.md`; atoms, bonds and molecules with caps
and a derived formula; the strict XYZ parser with typed refusals; distance-based bond inference marked inferred; a
curated library of five molecules from PubChem 3D conformer records (bundled as XYZ text plus recorded bonds, parsed by
the same parser); the experience state (molecule index). In the experience a candidate registration with a scenario
manifest whose presenter draws the selected molecule's atoms as lit UV spheres coloured by element, framed by an orbit
camera, with native controls and information lines. Research: [research.md](research.md). Data:
[data-model.md](data-model.md). Contract: [contracts/domain.md](contracts/domain.md).

## Technical Context

**Language**: Swift 6. **Dependencies** (verified at A15-P00 and in the clarification session): `VisualCoreMath`
(`Vec3`, `Mat4`, `OrbitCamera`), `VisualCoreScenes` (`Mesh.uvSphere`, `Mesh`), `VisualCoreRendering` (`MeshRenderer`,
`DepthMeshPass`, `RenderContext`), `VisualCoreExperience` and `VisualCoreExperienceHost` (core and presenter protocols,
`ExperienceShell`, scenario manifest). **Storage**: none (the session state is the host's). **Testing**: core and
experience tests in ExperiencesCreative on sim-27.2; app build and unit; runner iOS 27; packages; contract; script
tests. **Performance**: at most 24 atoms in the library, one sphere mesh per element (at most 32 × 16 segments);
inference bounded at 124,750 pair checks for 500 atoms; one frame per state change. **Constraints**: tests < 10 s; iOS
27 only; no NEEDS CLARIFICATION remains.

## Constitution Check

I PASS (one app; candidate experience) · II PASS (sphere mesh, renderer, depth pass, camera reused; no upstream change
this phase; a bounded line reader assessed for VisualCore and kept app-local, research D3) · II-a N/A (no VisualCore
change) · III PASS (atoms coloured in code; no textures) · IV PASS (catalog, parser, inference, library and state tested
without GPU) · V PASS (state schema 1) · VI PASS · VII PASS (native controls with labels; element symbols spoken with
colour) · VIII PASS (no network, no import yet) · IX PASS (caps on bytes, atoms, bonds, lines) · X PASS · XI–XIII PASS.
A15 rules: data with provenance (element audit, molecule sources), strict bounded parsing, inferred bonds marked,
deterministic GPU-free rules, truthful claims — PASS. Post-design: PASS.

## Project Structure

```text
Packages/ExperiencesCreative/MolecularExplorer/Core/{Elements,SourceRecord,ElementAudit,Molecule,XYZParser,
  BondInference,MoleculeLibrary,MoleculeState}.swift                                                         new domain
Packages/ExperiencesCreative/MolecularExplorer/CoreTests/{ElementsTests,ElementAuditTests,MoleculeTests,
  XYZParserTests,ParserRegressionTests,BondInferenceTests,MoleculeLibraryTests,MoleculeStateTests}.swift     new
Packages/ExperiencesCreative/MolecularExplorer/Experience/{Adapter/MoleculeCore.swift,Adapter/MoleculeManifest.swift,
  MoleculePresenter.swift,MoleculeControls.swift,MolecularExplorerExperience.swift}                         new
Packages/ExperiencesCreative/MolecularExplorer/ExperienceTests/{MoleculeCoreTests,MoleculeManifestTests,
  MoleculeSessionTests,MoleculeRenderTests,MoleculeTestSupport}.swift; MolecularExplorer/scenario-manifest.json new
Packages/ExperiencesCreative/Package.swift, Catalog/registrations.json (+ the VisualCore test fixture copy),
  Apps/VisualCore/App/ExperienceRegistry.swift (candidate), project.yml (dependency), scripts/test_scripts.py
  (products list), RealCatalogTests (registrations), AppModelTests (synthetic candidate id moves from a15 to a16)  modify
docs/apps/molecular-explorer/{data-sources.md (generated), visualcore-contract.json (G-ELEMENTS, G-DOMAIN, G-PARSER
  closed by A15-P01), README}                                                                                 new/modify
```

**Dependency direction** (targets `MolecularExplorerCore`, `MolecularExplorerExperience`, their test targets and the
product `MolecularExplorerExperience`, as `scripts/check_experience_packages.py` requires; the adapter type is
`MoleculeCore` so it does not shadow the module): Experience → Core → Foundation only; the experience → scenes,
rendering, host, UI; nothing in VisualCore depends on the experience.

**Lifecycle**: the core holds `MoleculeState` (molecule index); actions apply at their step; the host's steps change
nothing else. The presenter owns one `MeshRenderer` per element sphere it needs, all created once when the host's
context is current, rebuilt after a context recreation and released together in teardown (mesh renderers share a cached
program; lesson of A14), and draws through `DepthMeshPass` with an `OrbitCamera` framed on the molecule's bounding
sphere; it reads the state and never writes it. **Migration**: none (new schema 1). **Rollback**: revert the commits.

## Parallel work

Agent A: Core and CoreTests (contracts/domain.md). Agent B: Experience target and tests after A lands. Lead:
Package.swift, registrations, registry, project.yml, xcodegen, library generation from the PubChem records, manifest
regeneration, data-sources document, contract, runs, commits.
