# Data model: R02-G10-08

| Entity | Fields | Rules |
|---|---|---|
| `BackwardsAuroraGolden.Frame` | name, level, tier, time, actions | 16 frames: levels 1, 21, 41, 61, 81 × tiers 0 … 2 at time 0 after the witness's first min(smallest − 1, 2) reversals, plus the hero frame of `scenario-manifest.json` at tier 0 |
| Frame description | samples [[x, y]] (wave order, ribbon sample points), rings [[x, y]] (checkpoint order, ring centres), kinks, tear (seam or null), reversals spent, budget, colours {ground, band, ribbon, ghost, ring, matched, kink, tear, spent, unspent} rgb | positions rounded to 1/8 px at 1,152 × 768, authored camera; colours 8-bit sRGB; JSON with sorted keys; an off-screen point is recorded as null |
| `golden-frames.json` | schema 1, frames {name: {description, digest}} | rewritten only with BACKWARDS_AURORA_WRITE_GOLDEN=1 |
| Solver regression record | level, witness replay, reversals, smallest, work | all equal to the witness's; smallest = the lower bound's; work ≤ workBound; per-reversal digests and fingerprints equal; won within the budget |
| Memory cycle | footprint after each of 12 cycles, live GPU objects after close and warning | cycles 2 … 12 within 16 MB of cycle 1 when isolated; live objects 0 |
