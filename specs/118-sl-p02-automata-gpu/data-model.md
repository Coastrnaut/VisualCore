# Data model: A16-P02 (feature 118)

| Entity | Fields | Rules |
|---|---|---|
| `AutomatonGPU` | pair (RGBA8, grid × grid), step pass, rule masks (birth, survival: 9 bits each) | red 255 alive, 0 dead; wrap by index modulo; one step = one CPU iteration |
| `GrayScottGPU` | pair (RGBA16F, u red, v green), step pass, F, k, Δt, Du, Dv | highp arithmetic; fixture only in this phase |
| Mirror state (presenter) | last loaded kind, spec, step count | load on any non-step change; step by the iteration delta (≤ 128 per frame) |
