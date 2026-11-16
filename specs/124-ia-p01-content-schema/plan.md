# Implementation Plan: Interactive Anatomy — Phase 01 Licensed content inventory and schema

**Branch**: `124-ia-p01-content-schema` (spec directory only; work on `main`) | **Date**: 2026-11-16 | **Spec**: [spec.md](spec.md)

## Summary

Build G-CONTENT: the pure, GPU-free core `InteractiveAnatomyCore`, which holds the right knee's content as versioned
data with a validator.
- **Types:** `AnatomyRegion`, `AnatomicalStructure`, `AnatomyLayer`, `ProceduralMeshDeclaration`, `ContentManifest`,
  `Citation`, `ReviewStatus` and `AnatomyLabel`.
- **Loading and checking:** `AnatomyContent` decodes and validates; `ContentRefusal` holds the typed reasons with
  their sentences.
- **Data:** the bundled resource `Core/Content/knee-right.json` holds 14 structures, about 30 meshes and the
  citations.
- **Tests:** the bundled region validates; every refusal kind is triggered and named; the round trip is exact;
  damaged, newer and oversized data is refused; every label resolves.

No experience target, registration or interface comes in this phase (clarification Q5). Research:
[research.md](research.md). Data: [data-model.md](data-model.md). Contract: [contracts/core.md](contracts/core.md).
Quickstart: [quickstart.md](quickstart.md).

## Technical Context

- **Language:** Swift 6. **Dependencies:** `VisualCoreMath` (`Vec3` for the bounds), Foundation's `JSONDecoder` and
  `JSONEncoder`; nothing else. **Storage:** one bundled JSON resource (≤ 256 KB).
- **Testing:** `InteractiveAnatomyCoreTests` through the package scheme on the iOS 27.2 simulator, and the package and
  script checks.
- **Constraints:** tests under 10 s; no GPU. No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| I, III | PASS: no rendering in this phase |
| II Reuse | PASS: `VisualCoreMath` types; no duplicate of a framework type |
| IV Pure core | PASS: the core imports Foundation and VisualCoreMath only |
| V Persistence | PASS: schema 1 with typed refusals, a size cap and version refusal |
| VI Tests | PASS: one test per refusal kind and the fixture |
| VIII Privacy | PASS: bundled data only |
| X–XIII | PASS: documented API; no VisualCore change |

A17 rules: content provenance and the not-reviewed label (manifest), educational not medical (no clinical
statement), visuals are code (procedural mesh declarations only, no assets): PASS. Post-design: PASS.

## Project Structure

```text
Packages/ExperiencesCreative/Package.swift                                                         modify (2 targets)
Packages/ExperiencesCreative/InteractiveAnatomy/Core/{AnatomyModel,AnatomyContent,ContentRefusal}.swift  new
Packages/ExperiencesCreative/InteractiveAnatomy/Core/Content/knee-right.json                          new (resource)
Packages/ExperiencesCreative/InteractiveAnatomy/CoreTests/{BundledRegionTests,ContentValidationTests,
  ContentCodecTests}.swift                                                                          new
docs/apps/interactive-anatomy/visualcore-contract.json (G-CONTENT closed)                           modify
docs/apps/interactive-anatomy/content-sources.md                                                    new (citations, licenses, review status)
```

**Dependency direction:** the core → VisualCoreMath. **Lifecycle:** decode once and validate; the result is immutable.
**Migration:** none (schema 1 is the first). **Rollback:** revert the commits; nothing else depends on the core yet.

## Parallel work

- **Agent A:** the three source files and the JSON.
- **Agent B:** the three test files, written against the contract.
- **Lead:** `Package.swift`, `content-sources.md`, the contract, the runs and the commits.
