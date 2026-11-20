# Implementation Plan: R02-F17 — Fluid-heightfield transport and conservation

**Branch**: `217-fluid-heightfield-transport-and-conservation` (spec directory only; work on `main`) | **Date**:
2026-11-19 | **Spec**: [spec.md](spec.md)

## Summary

In VisualCoreSimulation: a `Heightfield` (terrain, water, sediment and up to four dye channels as integer quanta per cell,
four `Double` pipe fluxes per cell, walled or open edges) stepped by the virtual-pipe shallow-water law in bounded
sub-steps, carrying dye and sediment with the water and, when enabled, exchanging rock and sediment by erosion; every
transfer moves whole quanta, so a `HeightfieldLedger` balances exactly. `HeightfieldParameters` hold the constants,
`HeightfieldStepReport` says what a frame step did, `HeightfieldError` refuses with `r2-f17.*` codes. The state is
`Codable` (schema 1) and hands a `FieldGrid` to the existing field passes for drawing. Research: [research.md](research.md).
Data: [data-model.md](data-model.md). API: [contracts/api.md](contracts/api.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Swift 6. **Primary dependencies**: VisualCoreSimulation (`FieldGrid`, `SeededRandom` for fixtures),
which depends on VisualCoreMath only. No new module or dependency; no GPU, GLSL or Objective-C++ change (the consumers
upload the handed-off `FieldGrid` through the existing passes; exact conservation is a CPU contract because GPU float
sums cannot conserve exactly).
**Seeds**: fixtures use `SeededRandom` seeded 2_017.
**Testing**: `swift test --package-path Packages/VisualCore`; ExperiencesCreative on sim-27.2 and VisualCoreRendering on
sim-27.2 and sim-26.5 as regression (Fluid Art Playground unchanged); reference regression in two chunks; script tests.
**Performance**: bounded by arithmetic — a sub-step is O(cells) with a fixed number of operations per cell, at most 64
sub-steps per frame step; test grids are at most 64 × 64 and a few thousand sub-steps, well under a second each and light
beside the other suites.
**Constraints**: additive; `FieldGrid` and every existing type unchanged; integer transfers only.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| I Proven renderer only | PASS — no rendering change; drawing goes through the existing passes. |
| II App-neutral API · II-a reference | PASS — generic heightfield, no game rules; `///`; API baseline; reference regression. |
| III GPU lifecycle | PASS — none. |
| IV Host-testable | PASS — pure, host-tested. |
| IX Bounded input | PASS — grid, amount, parameter, sub-step and flux limits, each refused or clamped and reported. |
| X Licensing and provenance | PASS — published virtual-pipe and erosion models re-implemented; original code. |
| XI Stable identity | PASS — schema 1 stored form; newer refused. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/VisualCore/Sources/VisualCoreSimulation/HeightfieldError.swift        new  HeightfieldError + reasonCode
Packages/VisualCore/Sources/VisualCoreSimulation/HeightfieldParameters.swift   new  HeightfieldEdges, HeightfieldParameters, HeightfieldLedger, HeightfieldStepReport
Packages/VisualCore/Sources/VisualCoreSimulation/Heightfield.swift             new  Heightfield state, ledgered edits, totals, FieldGrid handoff
Packages/VisualCore/Sources/VisualCoreSimulation/Heightfield+Step.swift        new  bounded sub-steps, pipe flow, dye and sediment transport, erosion
Packages/VisualCore/Sources/VisualCoreSimulation/Heightfield+Coding.swift      new  Codable schema 1, encoded(), decode(_:)
Packages/VisualCore/Tests/VisualCoreSimulationTests/HeightfieldStateTests.swift, HeightfieldFlowTests.swift,
  HeightfieldBoundsTests.swift, HeightfieldDyeTests.swift, HeightfieldErosionTests.swift, HeightfieldCodingTests.swift   new
docs/architecture/heightfield-transport.md (new), docs/api/visualcore-public-api.txt, Packages/VisualCore/README.md, docs/catalog/shared-feature-map.json (lead)
```

**Migration**: none of existing data. **Rollback**: revert the commits (additive files only).

## Parallel work

The model is one coupled step, so the lead writes the five source files. The six test files are independent and are
written in parallel by agents against contracts/api.md and the spec's rules, then run by the lead.
