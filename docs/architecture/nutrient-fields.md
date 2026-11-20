# Nutrient fields

Feature 221 (R02-F21). Spec: [specs/221-diffusion-nutrient-and-viability-field-solver](../../specs/221-diffusion-nutrient-and-viability-field-solver/spec.md).

## The rule

Nutrient spreads, fades and feeds a growing network without ever going negative, oscillating or drifting: every quantum
added, removed, faded or eaten is counted, each channel's total equals its account exactly after every frame, and the
same start gives the same field on every device. The existing `FieldGrid`, heightfield and route solvers are unchanged.

## Parts (VisualCoreSimulation)

- `NutrientField`: a walled grid of 2 … 512 cells per side (at most 262,144 cells) with 1 … 4 channels of `Int64` quanta
  (65,536 per unit); a cell and a channel's total hold at most 2⁴⁰ quanta. Each channel has a diffusion rate D
  (0 … 1,000 cells² per second) and a decay rate λ (0 … 100 per second).
- `step(by:)` cuts a frame to 0.25 s and splits it into n = max(1, ⌈8 · t · Dmax⌉) ≤ 256 sub-steps, so r = D · h ≤ 1/8;
  time that does not fit is dropped and reported. Each sub-step runs the sources and sinks, then diffusion (every edge
  between 4-neighbours carries ⌊r · (a − b)⌋ quanta from the fuller cell, all from the sub-step's start), then decay
  (⌊a · (1 − e^(−λ h))⌋ per cell). A cell sends at most half its excess, so the largest value never rises and the smallest
  never falls.
- `NutrientSource`: a source or sink of one channel at one cell, in units per second, with a fractional carry so that it
  moves exactly ⌊rate · unit · elapsed⌋ quanta over time; sources stop at the limits (capped) and sinks at empty cells
  (short), both reported.
- `ViabilityBand`: 1 inside [low, high], a linear ramp to 0 beside it; a cell's viability is the least over the banded
  channels.
- `GrowthNetwork`: grows once per frame into viable 4-neighbours that hold at least its cost of food, most food first
  then by index, within a per-frame and a total limit; each new cell links to its lowest-index network neighbour and
  eats the cost. `networkGraph()` hands the network to the route solvers as a `RouteGraph`.
- `NutrientLedger` of `NutrientAccount`s (added, removed, faded, eaten) and a `NutrientStepReport` per frame.
- `fieldGrid(channel:)` and `viabilityGrid()` hand one-channel `FieldGrid`s to the existing passes. `Codable` JSON
  schema 1; `decode` re-checks every rule and the balance.

## Failures

`NutrientError` reason codes: `r2-f21.grid-size`, `r2-f21.channel`, `r2-f21.cell-range`, `r2-f21.amount-limit`,
`r2-f21.parameter`, `r2-f21.time`, `r2-f21.source-limit`, `r2-f21.growth`, `r2-f21.newer-schema`, `r2-f21.malformed`;
the experience that reports one adds its id, seed and tick.

## Limits

Two-dimensional and walled; nutrients are a visual device, not a biological model; the solver runs on the CPU. The frame
cost of a large field with growth is measured on D1–D3 in the device campaign.

## Sources

Explicit finite-volume diffusion with its stability bound, first-order decay and frontier growth are published methods,
re-implemented here. All code is original to VisualCore.
