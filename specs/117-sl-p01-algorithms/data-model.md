# Data model: A16-P01 (feature 117)

| Entity | Fields | Rules |
|---|---|---|
| `SimulationKind` | automaton, reactionDiffusion, wave | — |
| `BoundaryMode` | wrap, fixedZero | automata and reaction-diffusion wrap; wave fixedZero |
| `SimulationSpec` (schema 1) | kind, gridSize, timeStep, boundary, seed, parameters [name: value], algorithmVersion 1 | gridSize ∈ {16, 32, 64, 128, 256} (64 only in this phase's experience); values within their definitions; Δt within the family's stability bound; finite |
| `ParameterDefinition` (VisualCoreParameters) | name, title, unit, minimum, maximum, default | automaton: rule preset index 0…2; Gray-Scott: F 0…0.1, k 0…0.1, Δt 0.1…1.5625; wave: c 0.1…2, Δt 0.05…1, γ 0…0.05, C = cΔt ≤ 0.7071 |
| `SimulationScheduler` | running, speedIndex 0…4 (0.25, 0.5, 1, 2, 4), stepCount, accumulator | ≤ 16 iterations per host step; remainder beyond the cap dropped |
| `SimulationState` (schema 1) | spec, scheduler, field channels as base64 of storage bits | ≤ 1,048,576 bytes; refusals damaged, newer-version, out-of-range |
