# Data model: R02-G04-01

| Entity | Fields | Rules |
|---|---|---|
| `HueCompassWheel` | 96 bearings, 24 bands, boundary table | constants |
| `HueCompassLevel` | id, seed, band 1 … 5, offset 0 … 23, fog 96 × (0 … 9), target 0 … 95, bearing tolerance 0 … 4, band tolerance 0 … 2, allowance 2 … 24, start bearing 0 … 95, tutorial, fingerprint | schema 1; start bearing not within tolerance of the target |
| `HueCompassAction` | turn(steps −48 … 48, ≠ 0), probe, select(bearing 0 … 95, band 0 … 23) | |
| `HueCompassClue` | bearing, hue gap 0 … 12, depth 0 … 423 | depth = Σ densities strictly inside the shorter arc (47 × 9 max) |
| `HueCompassPlay` | stage, bearing, spent, clues, records, undo/redo stacks (turns), failure (`selection`, `probes`) | records carry previous and next fingerprints |
