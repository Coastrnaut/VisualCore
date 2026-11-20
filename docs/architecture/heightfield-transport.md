# Heightfield transport and conservation

Feature 217 (R02-F17). Spec: [specs/217-fluid-heightfield-transport-and-conservation](../../specs/217-fluid-heightfield-transport-and-conservation/spec.md).

## The rule

Water, dye and rock are counted in whole quanta, and every change moves whole quanta: nothing appears from nothing,
nothing vanishes, and the same inputs give the same landscape on every device. Each quantity's grid total equals its
ledger account (added − removed − drained) exactly, after every step.

## Model (VisualCoreSimulation)

- `Heightfield`: terrain, water, suspended sediment and up to four dye channels per cell as `Int64` quanta (65,536 per
  height unit, cell size 1, at most 2⁴⁰ per cell and per grid total), four `Double` pipe fluxes per cell (up, right,
  down, left), walled or open edges, on grids of 4 … 1,024 per side and at most 262,144 cells.
- `step(by:)` runs the virtual-pipe shallow-water law (O'Brien and Hodgins 1995; Mei, Decaudin and Hu 2007) in
  sub-steps of at most the stability limit min(maxSubstep, 0.25 / √(g · depth)), at most 64 per frame step; past that
  the rest of the frame time is dropped and reported in the `HeightfieldStepReport`.
- In a sub-step every cell sends whole quanta from its start-of-sub-step water, scaled down when it would send more
  than it holds; dye and sediment leave in the same proportion (full-width integer arithmetic), and a
  cell that sends all its water sends the rounding remainder too, so no dry cell keeps dye or sediment; open borders drain into
  the ledger. Results do not depend on the order cells are visited.
- Erosion (off unless `parameters.erosion`): rock and sediment exchange whole quanta within a cell against the capacity
  C = K_c · |v| · max(slope, 0.01) · depth, never below the floor 0.
- Edits (`add`, `remove` for terrain, water and dye) are the only other way amounts change, and each is ledgered;
  sediment changes only by erosion and flow.

## Drawing

`fieldGrid()` returns a four-channel `FieldGrid` (terrain, water depth, sediment, total dye, in height units) and
`dyeField()` one channel per dye, for the existing field passes; no rendering code changes. Exact conservation is a CPU
contract: GPU float sums cannot conserve exactly.

## Stored form

`Heightfield` is `Codable` as JSON schema 1 with sorted keys and reopens to continue bit-identically. A newer schema is
refused; wrong array sizes, amounts out of range, fluxes out of range or an unbalanced ledger are refused as damaged.

## Failures

`HeightfieldError` reason codes: `r2-f17.grid-size`, `r2-f17.cell-range`, `r2-f17.amount-limit`, `r2-f17.invalid-time`,
`r2-f17.invalid-parameter`, `r2-f17.dye-channel`, `r2-f17.newer-schema`, `r2-f17.malformed`; the experience that reports
one adds its id, seed and tick.

## Limits

A game-grade shallow-water approximation: conservation is exact, motion is plausible, not physically accurate. No
three-dimensional fluid.

## Sources

The virtual-pipe model (O'Brien and Hodgins, 1995) and its erosion extension (Mei, Decaudin and Hu, 2007) are published
methods, re-implemented here. All code is original to VisualCore.
