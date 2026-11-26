# Data model: R02-G18-08

| Entity | Fields | Rules |
|---|---|---|
| `ApsidesWorkshopGolden.Frame` | name, level, tier, time, actions, tick | 16 frames: levels 1, 21, 41, 61, 81 × tiers 0 … 2 at time 0 after the witness's tunings (not the play), shown at tick T / 2, plus the hero frame at tier 0 |
| Frame description | star, orbiter, periapsis, apoapsis, firstActionsBar [x, y], planets [[x, y]] (index order), counts {sectors, wedges, orbitPoints, planets, gauges, met, litActions, actions}, colours {name: [r, g, b]} | positions rounded to 1/8 pixel at 1,152 × 768 (a point behind the eye is recorded as null); colours 8-bit sRGB; JSON with sorted keys |
| Golden manifest | schema 1, frames {name: {description, digest}} | rewritten only with APSIDES_WORKSHOP_WRITE_GOLDEN=1 |
| Solver regression record | level, witness replay, plan actions, orbitsByDepth[size − 1], work | all equal to the witness's; work ≤ workBound; per-action fingerprints and digests equal; won on the final play only |
