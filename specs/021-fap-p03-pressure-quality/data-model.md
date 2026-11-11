# Data Model: Fluid Art Playground — Phase 03

## QualityPolicy (VisualCoreDiagnostics)

| Field | Meaning | Bounds |
|---|---|---|
| tierCount | number of tiers, 0 = best | ≥ 1 |
| lowPowerCeiling | best tier allowed in Low Power Mode | 0…tierCount−1 (default 1, or 0 when tierCount is 1) |
| decisionInterval | minimum seconds between changes | > 0 (default 2) |
| calmPeriod | calm seconds before stepping up | > 0 (default 10) |
| tier | current tier | 0…tierCount−1 |
| stepsDown, stepsUp | counters | ≥ 0 |

`decide(thermal: FramePacing.Thermal, lowPower: Bool, now: Double) -> Int` makes a deterministic decision. A
non-finite `now` keeps the current tier.

## BoundaryMode (app Core)

`enum BoundaryMode: String, Codable, CaseIterable { case walls, open }`, with walls as the default.

## FluidConfiguration addition

`boundaryMode: BoundaryMode = .walls`. Viscosity (0…1) and pressureIterations (1…80) are now used.

## FluidSolver (app Core, CPU reference)

- `divergence(velocity:mode:encoding:)` → a scalar grid (R channel).
- `jacobiPressure(divergence:iterations:precision:encoding:)` → pressure; starts at 0.
- `subtractGradient(velocity:pressure:mode:precision:encoding:)` → projected velocity, applying the walls rule.
- `diffuse(velocity:viscosity:dt:iterations: 8, mode:precision:encoding:)`.
- `step(velocity:dye:splats:configuration:pressureIterations:dt:precision:encodings:)` → the full frame in the order of
  clarification 5.
- An access log records each neighbor index read, to prove it stays in the grid.

## FluidQuality (app Core)

- `tiers` = [Full, Reduced, Minimal].
- `parameters(tier:configuration:) -> (iterations: Int, splatCap: Int)`:
  - Full = (it, cap);
  - Reduced = (max(1, it/2), cap);
  - Minimal = (max(1, it/4), max(1, cap/2)).
- `name(tier:)`.
