# Implementation Plan: Molecular Explorer — Phase 04 Curated molecule content and persistence

**Branch**: `113-me-p04-library` (spec directory only; work on `main`) | **Date**: 2026-11-16 | **Spec**: [spec.md](spec.md)

## Summary

Build G-LIBRARY with no VisualCore change: in the core two small versioned documents — `RecentMolecules` (at most 8
ids, newest first) and `MoleculeSettings` (label mode) — with codecs that refuse damaged, oversized, newer and
out-of-range bytes, and a bond-inference determinism fixture; in the experience two stores over `ExperienceStorage`
following Solar System Explorer's `ViewStore` (load never writes; refused files stay byte-identical; in-memory without
storage), the recent list updated on every molecule change, the label mode applied by the overlay, and controls: a
Library section with attributions, a Recent menu and a Labels picker. Research: [research.md](research.md). Data:
[data-model.md](data-model.md). Contract: [contracts/library.md](contracts/library.md).

## Technical Context

**Language**: Swift 6. **Dependencies** (verified in the clarification session): `VisualCoreExperience`
(`ExperienceStorage.write(_:to:)` atomic, `read(_:)`, `exists(_:)`, `remove(_:)`, `StorageError`). **Storage**:
`recent.json` (≤ 2,048 bytes) and `settings.json` (≤ 1,024 bytes) in the experience's folder. **Testing**: core and
experience tests in ExperiencesCreative on sim-27.2 (temporary storage folders); app build and unit; runner iOS 27;
packages; contract; documented API; script tests. **Performance**: two tiny documents read once at open, written on
change. **Constraints**: tests < 10 s; iOS 27 only; no NEEDS CLARIFICATION remains.

## Constitution Check

I PASS · II PASS (storage and the ViewStore pattern reused; no upstream change) · II-a N/A · III PASS · IV PASS
(documents and codecs tested without GPU) · V PASS (both documents versioned, schema 1, newer refused) · VI PASS · VII
PASS (Library, Recent and Labels controls with labels and values) · VIII PASS (local only, nothing sent) · IX PASS
(caps on entries and bytes) · X PASS · XI–XIII PASS. A15 rules: offline-first and private (own folder only), data with
provenance (attributions shown), deterministic rules — PASS. Post-design: PASS.

## Project Structure

```text
Packages/ExperiencesCreative/MolecularExplorer/Core/{RecentMolecules,MoleculeSettings}.swift                     new
Packages/ExperiencesCreative/MolecularExplorer/CoreTests/{RecentMoleculesTests,MoleculeSettingsTests,
  InferenceDeterminismTests}.swift                                                                               new
Packages/ExperiencesCreative/MolecularExplorer/Experience/{RecentStore,SettingsStore}.swift                      new
Packages/ExperiencesCreative/MolecularExplorer/Experience/{MoleculePresenter.swift, MoleculeControls.swift,
  MoleculeOverlay.swift, MolecularExplorerExperience.swift}                                                      modify
Packages/ExperiencesCreative/MolecularExplorer/ExperienceTests/{RecentStoreTests,SettingsStoreTests,
  MoleculeLibraryUITests}.swift (unit tests of the stores and controls words)                                     new
docs/apps/molecular-explorer/visualcore-contract.json (G-LIBRARY closed)                                         modify
```

**Dependency direction**: Experience → Core → VisualCoreMath and Foundation; the stores → `VisualCoreExperience`
storage; nothing in VisualCore depends on the experience.

**Lifecycle**: the presenter loads both documents once when created with storage (`make(id:storage:…)`), records the
current molecule into the recent list on every molecule change it observes (including the first state) and writes it,
writes settings when the Labels picker changes, and never touches the engine state. **Migration**: none (new schema-1
documents; the engine state stays schema 3). **Rollback**: revert the commits; the two files are then ignored.

## Parallel work

Agent A: core documents and core tests. Agent B: stores, presenter, controls and experience tests after A. Lead:
contract, runs, commits.
