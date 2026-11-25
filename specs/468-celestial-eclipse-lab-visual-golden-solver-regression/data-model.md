# Data model: R02-G17-08

| Entity | Fields | Rules |
|---|---|---|
| `CelestialEclipseLabGolden.Frame` | name, level, tier, time, actions, tick | 16 frames: levels 1, 21, 41, 61, 81 × tiers 0 … 2 at time 0 after the witness's phase changes (not the run) with the default chosen body, shown at the first tick with an eclipse under way (0 if none), plus the hero frame at tier 0 |
| Frame description | bodies, lenses, halos [[x, y]] (index order), playhead, firstActionsBar [x, y], counts {bodies, rings, lenses, halos, targets, matched, litActions, actions}, colours {name: [r, g, b]} | positions rounded to 1/8 pixel at 1,152 × 768 (a point behind the eye is recorded as null); colours 8-bit sRGB; JSON with sorted keys |
| Golden manifest | schema 1, frames {name: {description, digest}} | rewritten only with CELESTIAL_ECLIPSE_LAB_WRITE_GOLDEN=1 |
| Solver regression record | level, witness replay, plan actions, settingsByDepth[size − 1], work | all equal to the witness's; work ≤ workBound; per-action fingerprints and digests equal; won on the final run only |
