# Research: A16-P01 (feature 117)

- **D1 Rules** (clarifications 1–3): Moore B/S automata with wrap; Gray-Scott explicit Euler with the five-point stencil
  and the bound Δt ≤ 1/(4 max D); leapfrog wave with C ≤ 1/√2 and its conserved discrete energy.
  *Alternatives*: a nine-point stencil (rejected for this phase: the five-point bound is simpler to state and check).
- **D2 Storage** : `FieldGrid` with `StoragePrecision` (`unorm8` for automata, `float16` for the others); the CPU field
  is the truth for this phase.
- **D3 Scheduler** (clarification 4): iterations per host step from a base rate and a speed factor, capped at 16, no
  carried burst.
- **D4 State** (clarification 5): the field travels in the snapshot (no replay of thousands of steps).
- **D5 Drawing**: colour-mapped RGBA8 upload into a `RenderTarget` and one `FieldPass` to the framebuffer with
  `texelFetch` (cells stay crisp; the registry's LINEAR sampling is not used for lookup).
  *Alternatives*: drawing quads per cell with `PrimitiveRenderer` (rejected: 4,096 items per frame).
