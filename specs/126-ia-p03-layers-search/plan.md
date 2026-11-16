# Implementation Plan: Interactive Anatomy — Phase 03 Layers, search and descriptions

**Branch**: `126-ia-p03-layers-search` (spec directory only; work on `main`) | **Date**: 2026-11-16 | **Spec**: [spec.md](spec.md)

## Summary

This phase builds G-LAYERS (isolate), G-GHOST, G-SEARCH, G-TEXT and G-VIEW.

- **VisualCore** (additive, in `VisualCoreRendering`):
  - `DepthMeshPass.Item.center` and a two-list `draw(_:translucent:view:projection:fog:context:)`. The translucent
    items are sorted back to front and blended with ONE, ONE_MINUS_SRC_ALPHA, with depth testing on and depth writing
    off.
  - Today's path is unchanged, so its pixels are bit-identical.
  - Docs, tests, the README row and the API baseline come with it.
- **Core:**
  - content version 2 (four synonyms);
  - `AnatomySearch` over `CatalogSearch.fold`;
  - `AnatomyPanel` (text and citations);
  - isolate (`AnatomyIsolate`) and the solid and ghost sets in `AnatomyViewState` schema 2, with a `MigrationChain`
    from 1;
  - `AnatomyViewDocument` (a `DocumentEnvelope` in `view.json`);
  - the generated sources table.
- **Experience:**
  - four isolate actions and the search selection, which is a `structure.select`;
  - the presenter draws solid and ghost lists, falls back to the hide mode, and writes the view file;
  - controls: a search field and results, the panel, the isolate controls and "Show all".

Research: [research.md](research.md). Data: [data-model.md](data-model.md). Contract:
[contracts/layers-search.md](contracts/layers-search.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

- **Language:** Swift 6.
- **New core dependencies** (pure): `VisualCoreExperience` (`CatalogSearch.fold`) and `VisualCorePersistence`
  (`DocumentEnvelope`, `MigrationChain`).
- **VisualCoreRendering:** `DepthMeshPass` and `MeshRenderer`, whose shader output is premultiplied.
- **Storage:** `view.json` in the experience's `ExperienceStorage` (at most 64 KB).
- **Testing:**
  - `VisualCoreRenderingTests` (`DepthMeshPassTests`) on sim-27.2;
  - core and experience tests on sim-27.2;
  - `check_public_api.py`, documented API, app build and unit, the runner on iOS 27, packages, contract and scripts.
- **Constraints:** tests under 10 s. The reference regression waits for X-A17. No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| I | PASS: one renderer; the stage is inside the host's depth pass |
| II | PASS: fold, envelope, migration chain and depth pass are reused |
| II-a | PASS: additive VisualCore change with `///` docs, tests, the API baseline, a README row and bit-identical existing output; the reference regression at X-A17 |
| III | PASS |
| IV | PASS: search, panel, isolate and the document are tested without a GPU |
| V | PASS: schema 2 with a migration from 1; damaged or newer data refused |
| VI | PASS |
| VII | PASS: native search, panel and isolate controls with labels |
| VIII | PASS: local file only |
| IX | PASS: at most 14 results; the file is capped |
| X–XIII | PASS |

A17 rules: cited text with the not-reviewed sentence, visuals are code: PASS. Post-design: PASS.

## Project Structure

```text
Packages/VisualCoreRendering/Sources/VisualCoreRendering/DepthMeshPass.swift (Item.center, translucent draw)  modify
Packages/VisualCoreRendering/Tests/VisualCoreRenderingTests/DepthMeshPassTranslucentTests.swift            new
Packages/VisualCoreRendering/README.md (the DepthMeshPass row); docs/api/visualcore-public-api.txt          modify
Packages/ExperiencesCreative/Package.swift (core + VisualCoreExperience, VisualCorePersistence)             modify
Packages/ExperiencesCreative/InteractiveAnatomy/Core/Content/knee-right.json (content version 2)           modify
Packages/ExperiencesCreative/InteractiveAnatomy/Core/{AnatomySearch,AnatomyPanel,AnatomyIsolate,
  AnatomyViewDocument}.swift; AnatomyViewState.swift (schema 2)                                             new/modify
Packages/ExperiencesCreative/InteractiveAnatomy/CoreTests/{SearchTests,PanelTests,IsolateTests,
  ViewDocumentTests,SourcesDocumentTests}.swift; ViewStateTests updated                                     new/modify
Packages/ExperiencesCreative/InteractiveAnatomy/Experience/{Adapter/AnatomyCore,Adapter/AnatomyManifest,
  AnatomyPresenter,AnatomyControls}.swift                                                                   modify
Packages/ExperiencesCreative/InteractiveAnatomy/ExperienceTests/{AnatomyIsolateRenderTests,
  AnatomySearchSessionTests,AnatomyViewFileTests}.swift; existing tests updated                             new/modify
docs/apps/interactive-anatomy/content-sources.md (generated table); visualcore-contract.json             modify
```

**Dependency direction:**
- The experience → the core → VisualCoreMath, VisualCoreScenes, VisualCoreExperience, VisualCorePersistence and
  Foundation.
- The experience → VisualCoreRendering, which gains no dependency.

**Lifecycle:**
- Actions change the view at their step.
- The presenter splits the visible items into solid and ghost lists from the core's rule, and draws both through one
  pass. A throwing translucent draw switches to the hide mode for the session.
- After each accepted, view-changing action the presenter writes `view.json`. The factory reads it when no snapshot
  is given.

**Migration:** view state 1 → 2 (no isolate), in the snapshot and in the file. **Rollback:** revert the commits. A
schema-2 file is then refused as newer and the opening view is used. The VisualCore addition is reverted with its
baseline line.

## Parallel work

- **Agent V:** the VisualCore stage and its tests.
- **Agent C:** the core files, the content version and the core tests.
- **Agent E, after V and C:** the experience changes and tests.
- **Lead:** Package.swift, the API baseline update, the README, the generated documents, contract, runs, commits.
