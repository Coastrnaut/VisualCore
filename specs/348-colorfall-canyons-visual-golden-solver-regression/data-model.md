# Data model: R02-G05-08

| Entity | Fields | Rules |
|---|---|---|
| `ColorfallCanyonsGolden.Frame` | name, level, tier, time, actions | 16 frames: levels 1, 21, 41, 61, 81 × tiers 0 … 2 at time 0 after the witness's edits and 12 ticks, plus the hero frame |
| Frame description | cell tops [x, y], emitter tops [x, y], basin centres [x, y], wet sheet tops [x, y] with fluid colours, colours {night, sandstone, rock, pearl, cyan, coral, yellow} rgb | positions rounded to 1/8 px at 1,152 × 768; colours 8-bit sRGB; JSON with sorted keys |
| `golden-frames.json` | schema 1, frames {name: {description, digest}} | rewritten only with COLORFALL_CANYONS_WRITE_GOLDEN=1 |
| Solver regression record | level, witness replay, edit set, smaller | the edit set and `smaller` equal the witness's; win tick equal |
| Memory cycle | footprint after each of 12 cycles, live renderers after close and warning | cycles 2 … 12 within 16 MB of cycle 1 when isolated; live renderers 0 |
