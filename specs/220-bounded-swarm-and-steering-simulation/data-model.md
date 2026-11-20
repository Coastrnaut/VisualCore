# Data model: R02-F20

| Entity | Fields | Rules |
|---|---|---|
| NeighbourGrid | cell size, buckets | cell size finite > 0; ≤ 65,536 agents; cell index clamped to ±2^40; non-finite agents skipped |
| MagneticPole | position, strength s, softening ε | finite; abs(s) ≤ 1,000; ε ≥ 1e-6 |
| MagneticField | uniform B, poles | finite; abs(B) ≤ 100; ≤ 64 poles |
| SwarmEdges | walled, wrapping | |
| Swarm | agents (SteeringAgent), charges, bounds, edges, parameters (SteeringParameters), speedLimit, field | ≤ 65,536 agents; charges count = agents count, each finite with abs(q) ≤ 100; bounds valid; agents finite; parameters: neighbourRadius finite > 0, neighbourLimit ≥ 1, others finite ≥ 0; speedLimit finite > 0; JSON schema 1; decode re-validates (`.malformed`) |
| DensityRaster | width, height, bounds, cells (Double) | width, height 1 … 1,024; ≤ 1,048,576 cells; bounds valid |
| SwarmError | agentLimit, bounds, step, parameter, field, rasterSize, newerSchema, malformed | `reasonCode` `r2-f20.*` |
