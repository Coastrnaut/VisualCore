# Data model: R02-G01-08

| Entity | Fields | Rules |
|---|---|---|
| `AuroraLoomGolden.Frame` | name, level number (1 … 100), host tier (0 … 2), frame time, moves applied (hero: one) | 16 fixed frames |
| `AuroraLoomGolden.Description` | width 96, height 64, ribbon sample points, gate marker points, gate centres (x, y in 1/8 px), colours (r, g, b 0 … 255) | JSON, sorted keys; deterministic |
| Golden manifest (`golden-frames.json`) | schema 1, frames: name → {digest, description} | equal digest, or positions within one 1/8-px quantum and equal colours; rewritten only with `AURORA_LOOM_WRITE_GOLDEN=1` |
| Solver fixture | manifest entry, generated level, certified solution, witness | 100 |
| Alteration | kind (12), level number | each detected and named |
| Memory cycle | index 1 … 12, footprint bytes, live GPU objects after close and after warning | growth ≤ 16 MB over cycle 1; live objects 0 |
