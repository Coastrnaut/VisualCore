# Data model: R02-G04-08

| Entity | Fields | Rules |
|---|---|---|
| `HueCompassGolden.Frame` | name, level, tier, time, actions | 16 frames: levels 1, 21, 41, 61, 81 × tiers 0 … 2 at time 0 after the witness probes, plus the hero frame |
| Frame description | needle tip [x, y], band samples [x, y] with band colours, probe marks [x, y], selection [x, y]?, ring [x, y]?, colours {night, pearl, sapphire, ember} rgb | positions rounded to 1/8 px at 1,152 × 768; colours 8-bit sRGB; JSON with sorted keys |
| `golden-frames.json` | schema 1, frames {name: {description, digest}} | rewritten only with HUE_COMPASS_WRITE_GOLDEN=1 |
| Solver regression record | level, witness replay, smallest, work | work ≤ 4,657 and equal to the certified work; smallest equals the witness's probe count |
| Memory cycle | footprint after each of 12 cycles, live renderers after close and warning | cycles 2 … 12 within 16 MB of cycle 1 when isolated; live renderers 0 |
