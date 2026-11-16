# Data model: A16-P03 (feature 119)

| Entity | Fields | Rules |
|---|---|---|
| `WaveGPU` | pair (RGBA16F, grid × grid, red uⁿ, green uⁿ⁻¹), step pass, C², 1 − γ | edge cells 0; one step = one CPU iteration |
| `GrayScottGPU` (A16-P02) | pair (RGBA16F, u red, v green), step pass | wrap |
| Float mirror (presenter) | kind, spec, step count, steps since load | load on any non-step change or after 64 steps; step by the iteration delta (≤ 128 per frame) |
| Float support | `FloatRenderSupport.supported`, `forceFloatUnsupported` (test seam) | probed in `setup`; false ⇒ no RD or wave pair |
| `SimulationLegendValues` | kind, minimum, maximum (v or height), alive, dead | from the CPU field; the description says the same numbers |
| `sim.timestep` | Δt, declared 0.05…2.0 | RD ≤ 1.5625; wave c · Δt ≤ 1/√2; family range; automaton refused; keeps field, step, running and speed |
| Rule codes | `a16.invalid-choice`, `a16.unstable`, `a16.unsupported` (new) | a refusal changes nothing |
