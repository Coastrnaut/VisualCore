# Data model: R02-G19-08

| Entity | Fields | Rules |
|---|---|---|
| `MicroscopicAuroraGolden.Frame` | name, level, tier, time, actions, tick | 16 frames: levels 1, 21, 41, 61, 81 × tiers 0 … 2 at time 0 after the witness's placements (not the play), shown at the tick half the ticks swum, plus the hero frame at tier 0 |
| Frame description | dish, firstActionsBar [x, y], swimmers [[x, y]], wells [[x, y]], sites [[x, y]] (index order), counts {stencil, lit, stray, sites, wells, swimmers, ribbonPoints, gauges, met, litActions, actions}, colours {name: [r, g, b]} | positions rounded to 1/8 pixel at 1,152 × 768 (a point behind the eye is recorded as null); colours 8-bit sRGB; JSON with sorted keys |
| Golden manifest | schema 1, frames {name: {description, digest}} | rewritten only with MICROSCOPIC_AURORA_WRITE_GOLDEN=1 |
| Solver regression record | level, witness replay, plan actions, setsByDepth[size − 1], nearestMiss, work | all equal to the witness's; work ≤ workBound; per-action fingerprints and digests equal; won on the final play only |
