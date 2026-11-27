# Data model: R02-G20-08

| Entity | Fields | Rules |
|---|---|---|
| `MushroomWeatherGolden.Frame` | name, level, tier, time, actions, cycle | 16 frames: levels 1, 21, 41, 61, 81 × tiers 0 … 2 at time 0 after the witness's actions (not the run), shown at the cycle half the cycles run, plus the hero frame at tier 0 |
| Frame description | floor, moon, firstGaugeTrack, firstActionsBar [x, y], caps [[x, y]] (colony order), counts {floor, blocked, mist, sites, pods, grown, vents, open, colonies, inBand, litActions, actions}, moonlight, colours {name: [r, g, b]} | positions rounded to 1/8 pixel at 1,152 × 768 (a point behind the eye is recorded as null); colours 8-bit sRGB; JSON with sorted keys |
| Golden manifest | schema 1, frames {name: {description, digest}} | rewritten only with MUSHROOM_WEATHER_WRITE_GOLDEN=1 |
| Solver regression record | level, witness replay, plan actions, arrangementsByDepth[size − 1], nearestMiss, work | all equal to the witness's; work ≤ workBound; per-action fingerprints and digests equal; won on the final run only |
