# Implementation Plan: R02-F20 — Bounded swarm and steering simulation

**Branch**: `220-bounded-swarm-and-steering-simulation` (spec directory only; work on `main`) | **Date**: 2026-11-20 |
**Spec**: [spec.md](spec.md)

## Summary

In VisualCoreSimulation, on top of the unchanged `Steering`, `NeighbourSearch`, `SteeringAgent`, `SteeringBounds` and
`SteeringParameters`: a `NeighbourGrid` that returns exactly `NeighbourSearch`'s lists; `MagneticField` (uniform field and
`MagneticPole`s); a `Swarm` (agents, charges, bounds, `SwarmEdges`, steering parameters, speed limit, field) stepped in
bounded fixed steps and `Codable` (schema 1); and a `DensityRaster` of `Double` cells handed to `FieldGrid`. Failures are
`SwarmError` with `r2-f20.*` codes. Research: [research.md](research.md). Data: [data-model.md](data-model.md). API:
[contracts/api.md](contracts/api.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Swift 6. **Primary dependencies**: VisualCoreSimulation (`Steering`, `NeighbourSearch`,
`SteeringAgent`, `SteeringBounds`, `SteeringParameters`, `FieldGrid`, `SeededRandom`), VisualCoreMath (`Vec2`). No new
module, dependency, GPU, GLSL or Objective-C++ code.
**Seeds**: fixtures use `SeededRandom` seeded 2_020.
**Testing**: `swift test --package-path Packages/VisualCore`; ExperiencesCreative on sim-27.2 (Digital Aquarium uses the
existing steering) and VisualCoreRendering on sim-27.2 and sim-26.5 as regression; reference regression in two chunks;
script tests; isolated timing run.
**Performance**: bounded by arithmetic — a grid query visits (2⌈r/c⌉ + 1)² cells; a step is O(n · k) for k neighbours;
the equivalence test against the O(n²) search uses up to 2,000 agents, which stays light.
**Constraints**: additive; existing steering and Digital Aquarium unchanged; every result finite.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| I Proven renderer only | PASS — no rendering change; density goes through `FieldGrid`. |
| II App-neutral API · II-a reference | PASS — generic swarm; `///`; API baseline; reference regression. |
| III GPU lifecycle | PASS — none. |
| IV Host-testable | PASS — pure, host-tested. |
| IX Bounded input | PASS — agent, pole, raster, step, field and speed limits refused by code; forces bounded. |
| X Licensing and provenance | PASS — Reynolds' boids (1987) via the existing steering, uniform grids, the Lorentz force and bilinear splatting are textbook; original code. |
| XI Stable identity | PASS — schema 1 stored swarm; newer refused. |

Post-design re-check: PASS.

## Project Structure

```text
Packages/VisualCore/Sources/VisualCoreSimulation/SwarmError.swift      new  SwarmError (lead)
Packages/VisualCore/Sources/VisualCoreSimulation/MagneticField.swift   new  MagneticPole, MagneticField (lead)
Packages/VisualCore/Sources/VisualCoreSimulation/NeighbourGrid.swift   new  NeighbourGrid (agent A)
Packages/VisualCore/Sources/VisualCoreSimulation/DensityRaster.swift   new  DensityRaster (agent B)
Packages/VisualCore/Sources/VisualCoreSimulation/Swarm.swift           new  SwarmEdges, Swarm, step, Codable (agent C, after A)
Packages/VisualCore/Tests/VisualCoreSimulationTests/MagneticFieldTests.swift (lead), NeighbourGridTests.swift (A),
  DensityRasterTests.swift (B), SwarmTests.swift (C)   new
docs/architecture/swarms.md (new), docs/api/visualcore-public-api.txt, Packages/VisualCore/README.md, docs/catalog/shared-feature-map.json (lead)
```

**Migration**: none of existing data. **Rollback**: revert the commits (additive files only).

## Parallel work

Lead writes the error and field types with their test; agents A and B in parallel; agent C writes the swarm against the
contract once A's grid is in. Lead: docs, API baseline, runs, commits.
