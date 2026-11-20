# Bounded swarms

Feature 220 (R02-F20). Spec: [specs/220-bounded-swarm-and-steering-simulation](../../specs/220-bounded-swarm-and-steering-simulation/spec.md).

## The rule

A swarm is stepped in bounded fixed steps from the existing steering forces: the same start gives the same swarm after
any number of steps on every device, every agent stays inside its bounds below its speed limit, and every value stays
finite. The existing `Steering`, `NeighbourSearch`, `SteeringAgent`, `SteeringBounds` and `SteeringParameters` and
Digital Aquarium are unchanged.

## Parts (VisualCoreSimulation)

- `NeighbourGrid` buckets finite agents by integer cell (indices clamped to ±2^40, so far agents never overflow) and
  answers a neighbour query from the cells within ⌈radius / cell⌉ + 1 (the extra ring absorbs rounding), falling back to every occupied cell when that window
  is larger. Distances, the radius test, the nearest-first order with ties by index and the limit are those of
  `NeighbourSearch`, so its lists are equal, not merely similar.
- `MagneticField` holds a uniform field B along z and up to 64 `MagneticPole`s. The uniform field turns a charge's
  velocity by the exact angle −q · B · h per step, so it never changes speed. A pole pulls with
  F = s · q · (c − p) / (|c − p|² + ε²)^{3/2}, never more than |s · q| · 2 / (3√3 · ε²).
- `Swarm` (agents, parallel charges, bounds, `SwarmEdges` walled or wrapping, steering parameters, speed limit, field)
  steps with h in (0, 0.1]: forces from the start-of-step swarm through one grid, v + a · h, the field turn, the speed cap,
  p + v · h, then reflection (walled) or wrap-around (wrapping). Neighbours use plain distance, without wrap-around.
  `Codable` JSON schema 1 with sorted keys; `decode` re-checks every rule.
- `DensityRaster` spreads each finite agent inside its rectangle bilinearly over the four cells around it, folding
  weight past the edge onto edge cells, so the total is the in-area count; `fieldGrid()` hands a one-channel
  `FieldGrid` to the existing field passes for glow.

## Failures

`SwarmError` reason codes: `r2-f20.agent-limit`, `r2-f20.bounds`, `r2-f20.step`, `r2-f20.parameter`, `r2-f20.field`,
`r2-f20.raster-size`, `r2-f20.newer-schema`, `r2-f20.malformed`; the experience that reports one adds its id, seed and
tick. At most 65,536 agents and 1,048,576 raster cells.

## Limits

Two-dimensional (consumers lift it into 3D for drawing); the field is a visual device, not physical
electromagnetism; the step runs on the CPU. The frame cost of a large swarm is measured on D1–D3 in the device campaign.

## Sources

Boids (Reynolds 1987) through the existing steering, uniform grids for neighbour search, the Lorentz force as a
rotation, Plummer softening and bilinear splatting are published methods, re-implemented here. All code is original to
VisualCore.
