# Data model: R02-G02-08

| Entity | Fields | Rules |
|---|---|---|
| `LissajousLabyrinthGolden.Frame` | name, level, tier, time, actions | 16 frames: levels 1, 21, 41, 61, 81 × tiers 0 … 2 at time 0, plus the hero frame |
| Frame description | samples [x, y], rings [x, y, rgb], obstacles [x, y, rgb], dials [centre, knob], background rgb | positions rounded to 1/8 px at 1,152 × 768; colours 8-bit sRGB; JSON with sorted keys |
| `golden-frames.json` | schema 1, frames {name: {description, digest}} | rewritten only with LISSAJOUS_LABYRINTH_WRITE_GOLDEN=1 |
| Solver regression record | level, witness replay, shortest, work, winning settings | work ≤ 14,080; shortest equals the witness's |
| Memory cycle | footprint after each of 12 cycles, live renderers after close and warning | cycles 2 … 12 within 16 MB of cycle 1 when isolated; live renderers 0 |
