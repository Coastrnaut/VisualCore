# Research: R02-F21

- **R1 Integer quanta.** Decision: `Int64` quanta, 65,536 per unit, cell and grid totals ≤ 2⁴⁰, as the heightfield.
  Rationale: conservation is exact and identical everywhere. Alternatives: `Double` amounts (drift of 1e-16 per move,
  totals only approximately kept).
- **R2 Explicit scheme with a positivity bound.** Decision: per sub-step, each 4-neighbour edge carries ⌊r · (a − b)⌋
  from the fuller cell, r = D · h ≤ 1/8, all fluxes from the sub-step's start. Rationale: a cell sends at most 4 r ≤ ½ of
  its excess over each lower neighbour, so the update is a convex combination before rounding down; the maximum never
  rises, the minimum never falls, nothing goes negative, and integer moves conserve exactly. Alternatives: implicit
  solve (unconditionally stable but needs a linear solve and is not exact in integers).
- **R3 Sub-steps and dropped time.** Decision: frame cut to 0.25 s; n = max(1, ⌈8 · t · Dmax⌉) ≤ 256; time beyond is
  dropped and reported. Rationale: a fixed cap bounds the work of a frame; reporting keeps it observable.
- **R4 Exact source rates.** Decision: each source keeps a `Double` carry; per sub-step it moves ⌊carry + rate · unit · h⌋
  quanta and keeps the fraction. Rationale: over time the moved total follows the rate without drift.
- **R5 Decay.** Decision: ⌊a · (1 − e^(−λ h))⌋ per cell per sub-step. Rationale: never more than the cell holds, exact
  integer bookkeeping; small amounts may linger, which the settle test allows for.
- **R6 Frontier growth.** Decision: rank 4-neighbour candidates by (food descending, index ascending), attach to the
  lowest-index network neighbour, eat a fixed cost from the new cell. Rationale: deterministic, bounded per frame, and a
  tree, so the `RouteGraph` with one undirected edge per link connects every network cell.
- **R7 Hand-offs.** Decision: `fieldGrid(channel:)`, `viabilityGrid()` as one-channel `FieldGrid`s in `FieldGrid`'s order
  (y · width + x, row 0 at the bottom); `networkGraph()` as a `RouteGraph` over every grid cell (index y · width + x, as
  `GridGraph`). Rationale: existing passes and route solvers take them unchanged.
