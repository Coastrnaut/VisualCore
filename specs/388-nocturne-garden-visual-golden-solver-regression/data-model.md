# Data model: R02-G09-08

| Entity | Fields | Rules |
|---|---|---|
| `NocturneGardenGolden.Frame` | name, level, tier, time, actions | 16 frames: levels 1, 21, 41, 61, 81 × tiers 0 … 2 at time 0 after the witness's first min(smallest − 1, 2) moves, plus the hero frame of `scenario-manifest.json` at tier 0 |
| Frame description | blooms [[x, y]] (canonical bloom order, head centres), lantern [x, y], shadow cells, moves spent, budget, colours {ground, mist, shadow, gold, coral, leak, lantern, spent, unspent} rgb | positions rounded to 1/8 px at 1,152 × 768, authored camera; colours 8-bit sRGB; JSON with sorted keys; an off-screen point is recorded as null |
| `golden-frames.json` | schema 1, frames {name: {description, digest}} | rewritten only with NOCTURNE_GARDEN_WRITE_GOLDEN=1 |
| Solver regression record | level, witness replay, moves, smallest, work | all equal to the witness's; smallest = the lower bound's; work ≤ workBound; per-move digests and fingerprints equal; won within the budget |
| Memory cycle | footprint after each of 12 cycles, live GPU objects after close and warning | cycles 2 … 12 within 16 MB of cycle 1 when isolated; live objects 0 |
