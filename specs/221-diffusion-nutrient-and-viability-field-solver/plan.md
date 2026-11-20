# Implementation Plan: R02-F21 — Diffusion, nutrient and viability field solver

**Branch**: `221-diffusion-nutrient-and-viability-field-solver` (spec directory only; work on `main`) | **Date**: 2026-11-20 |
**Spec**: [spec.md](spec.md)

## Summary

In VisualCoreSimulation, beside the unchanged `FieldGrid`, `Heightfield`, `RouteGraph` and `GridGraph`: a walled
`NutrientField` of 1 … 4 channels of `Int64` quanta with exact, stable explicit diffusion in bounded sub-steps, local
`NutrientSource`s (sources and sinks with fractional carries), per-channel decay, `ViabilityBand`s, a `GrowthNetwork` that
grows into viable neighbours and eats nutrient, a `NutrientLedger` of `NutrientAccount`s and a `NutrientStepReport` per
frame; `Codable` (schema 1); fields and viability handed on as `FieldGrid`s and the network as a `RouteGraph`. Failures are
`NutrientError` with `r2-f21.*` codes. Research: [research.md](research.md). Data: [data-model.md](data-model.md). API:
[contracts/api.md](contracts/api.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Swift 6. **Primary dependencies**: VisualCoreSimulation (`FieldGrid`, `RouteGraph`, `RouteSearch`,
`SeededRandom`). No new module, dependency, GPU, GLSL or Objective-C++ code.
**Seeds**: fixtures use `SeededRandom` seeded 2_021.
**Testing**: `swift test --package-path Packages/VisualCore`; VisualCoreRendering on sim-27.2 and sim-26.5 and
ExperiencesCreative on sim-27.2 as regression; reference regression in two chunks; script tests (run alone); isolated
timing run.
**Performance**: bounded by arithmetic — a frame is at most 256 sub-steps × 4 edges per cell × channels; growth visits
the network's frontier once per frame. Tests use grids of at most 64 × 64 and a few hundred frames.
**Constraints**: additive; existing types unchanged; every amount an exact integer; every report finite.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| I Proven renderer only | PASS — no rendering change; fields go through `FieldGrid`. |
| II App-neutral API · II-a reference | PASS — generic field; `///`; API baseline; reference regression. |
| III GPU lifecycle | PASS — none. |
| IV Host-testable | PASS — pure, host-tested. |
| IX Bounded input | PASS — sizes, channels, rates, sources, frame time, sub-steps and growth limits refused or capped by code. |
| X Licensing and provenance | PASS — the explicit finite-volume diffusion scheme, first-order decay and frontier growth are textbook; original code. |
| XI Stable identity | PASS — schema 1 stored field; newer refused. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/VisualCore/Sources/VisualCoreSimulation/NutrientError.swift          new  NutrientError (lead)
Packages/VisualCore/Sources/VisualCoreSimulation/NutrientTypes.swift          new  NutrientSource, ViabilityBand, NutrientAccount, NutrientLedger, NutrientStepReport (lead)
Packages/VisualCore/Sources/VisualCoreSimulation/GrowthNetwork.swift          new  GrowthNetwork (lead)
Packages/VisualCore/Sources/VisualCoreSimulation/NutrientField.swift          new  NutrientField storage, add/remove, sources, bands, viability, grids (lead)
Packages/VisualCore/Sources/VisualCoreSimulation/NutrientField+Step.swift     new  step: sub-steps, sources, sinks, diffusion, decay (agent A)
Packages/VisualCore/Sources/VisualCoreSimulation/NutrientField+Growth.swift   new  growth phase and network graph (agent B)
Packages/VisualCore/Sources/VisualCoreSimulation/NutrientField+Coding.swift   new  Codable schema 1, encoded, decode (agent C)
Packages/VisualCore/Tests/VisualCoreSimulationTests/NutrientFieldTests.swift (lead), NutrientDiffusionTests.swift (A),
  GrowthNetworkTests.swift (B), NutrientCodingTests.swift (C)   new
docs/architecture/nutrient-fields.md (new), docs/api/visualcore-public-api.txt, Packages/VisualCore/README.md, docs/catalog/shared-feature-map.json (lead)
```

**Migration**: none of existing data. **Rollback**: revert the commits (additive files only).

## Parallel work

Lead writes the error, value types, network type and the field's storage with its test; agents A, B and C then write the
step, growth and coding extensions in parallel (separate files, internal storage shared through the lead's file). Lead:
docs, API baseline, runs, commits.
