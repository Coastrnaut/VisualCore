# Implementation Plan: Infinite Geometry — Phase 04 Scene editing and export

**Branch**: `043-ig-p04-presets-export` (spec directory only; work on `main`) | **Date**: 2026-11-13 | **Spec**: [spec.md](spec.md)

## Summary

Add a saved-composition library and still export to Infinite Geometry with no framework change (contract rows M17 and
M18 are available). A `GeometryDocument` (version 1) captures the composition; the core gains one all-or-nothing action
`composition.open` that applies a document; `GeometryLibrary` stores documents in the experience's storage following
`ParticleLibrary`; the controls export a PNG through the host's `experienceStillRenderer` and share it as in-memory data
(as Fluid Art does), so no file is left behind. A GPU-stability test cycles presets and saved compositions and compares
the resource ledger. Research: [research.md](research.md).

## Technical Context

**Language**: Swift 6, SwiftUI. **Dependencies**: existing packages (VisualCoreExperience `ExperienceStorage`,
VisualCoreExperienceHost `ExperienceStillRenderer`, VisualCoreRendering `StillImageEncoder`, `ResourceRegistry.stats`).
**Storage**: `composition-<uuid>.json` files in the experience's storage (quota 64 files). **Testing**:
ExperiencesCreative on sim-27.2/26.5 (document round trip and validation, library save/rename/delete/quota/unreadable,
export pixels and size, GPU stability); runner on both; app unit; public-API check proves no framework change; script
tests. **Constraints**: tests < 10 s; no wall-clock assertions on CI; no second context.

## Constitution Check

I PASS (export through the host's offscreen render) · II PASS (no framework change needed; pure document logic in the
experience's adapter) · II-a PASS · III PASS (the host owns the context; controls only call the still renderer) · IV PASS
(document and library host-free logic tested) · V PASS (document versioned; library format field; newer refused) · VI PASS
(pixel equality and ledger stability tests) · VII PASS (buttons for every action; labels and identifiers) · VIII–XIII PASS
(no network; pictures leave only through the share sheet; no ads).

## Project Structure

```text
Packages/ExperiencesCreative/InfiniteGeometry/Experience/Adapter/GeometryDocument.swift   new  document v1, from core, open values, validation
Packages/ExperiencesCreative/InfiniteGeometry/Experience/Adapter/GeometryCore.swift       modify  composition.open (atomic), controls list
Packages/ExperiencesCreative/InfiniteGeometry/Experience/GeometryLibrary.swift            new  library (ParticleLibrary pattern)
Packages/ExperiencesCreative/InfiniteGeometry/Experience/GeometryExport.swift             new  export size, still render, PNG, Transferable
Packages/ExperiencesCreative/InfiniteGeometry/Experience/GeometryControls.swift           modify  library and export sections
Packages/ExperiencesCreative/InfiniteGeometry/Experience/InfiniteGeometryExperience.swift modify  library from storage passed to the controls
Packages/ExperiencesCreative/InfiniteGeometry/ExperienceTests/{GeometryDocumentTests,GeometryLibraryTests,GeometryExportTests,GeometryGPUStabilityTests}.swift  new
Packages/ExperiencesCreative/InfiniteGeometry/scenario-manifest.json                      regenerate (controls grow)
docs/apps/infinite-geometry/visualcore-contract.md                                         modify  M17/M18 consumers
```

**Dependency direction**: InfiniteGeometryExperience → VisualCoreExperience / VisualCoreExperienceHost /
VisualCoreRendering; nothing new in VisualCore.

**Lifecycle**: the library is created with the experience (`make`) from its storage and loads its entries once; writes
are atomic. Export renders synchronously on the main thread through the still renderer (the session's context), keeps
the PNG only in memory for the share sheet, and never changes the core.

**Migration**: no snapshot change (schema stays 3). Library files carry `format` 1 and document `version` 1.

**Rollback**: revert the commits; saved-composition files written meanwhile are ignored by older builds (no reader).

## Parallel work

Agent A: GeometryDocument + `composition.open` + GeometryDocumentTests. Agent B: GeometryLibrary + GeometryLibraryTests
(against the document API in contracts/api.md). Agent C: GeometryExport + controls + experience wiring +
GeometryExportTests + GeometryGPUStabilityTests. Lead: contract doc, manifest regeneration, runs, commits.
