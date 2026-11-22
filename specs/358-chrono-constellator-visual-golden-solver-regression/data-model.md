# Data model: R02-G06-08

| Entity | Fields | Rules |
|---|---|---|
| `ChronoConstellatorGolden.Frame` | name, level, tier, time, actions | 16 frames: levels 1, 21, 41, 61, 81 × tiers 0 … 2 at time 0 after the witness's phase changes and min(win tick, 6) ticks, plus the hero frame of `scenario-manifest.json` at tier 0 |
| Frame description | stars [x, y], targets [x, y], loop cells [x, y] (distinct cells, ascending index), tick, tick mark length, colours {field, grid, silver, star, rose, amber} rgb | positions rounded to 1/8 px at 1,152 × 768, authored orbit; length rounded to 1/1,024 cell; colours 8-bit sRGB; JSON with sorted keys; an off-screen point is recorded as null |
| `golden-frames.json` | schema 1, frames {name: {description, digest}} | rewritten only with CHRONO_CONSTELLATOR_WRITE_GOLDEN=1 |
| Solver regression record | level, witness replay, phase changes, lower bound, window, windows, blocked, work | all equal to the witness's; work ≤ tick limit + Σ window ticks; win tick and per-tick digests and fingerprints equal |
| Memory cycle | footprint after each of 12 cycles, live GPU objects after close and warning | cycles 2 … 12 within 16 MB of cycle 1 when isolated; live objects 0 |
