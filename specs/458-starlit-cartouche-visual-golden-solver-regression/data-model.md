# Data model: R02-G16-08

| Entity | Fields | Rules |
|---|---|---|
| `StarlitCartoucheGolden.Frame` | name, level, tier, time, actions | 16 frames: levels 1, 21, 41, 61, 81 × tiers 0 … 2 at time 0 after the witness's legs but the last with the default choice, plus the hero frame at tier 0 |
| Frame description | stars, strokes [[x, y]] (index order), ship, beacon, firstActionsBar [x, y], counts {stars, corridors, hazards, activeHazards, symbol, drawn, litActions, actions}, colours {name: [r, g, b]} | positions rounded to 1/8 pixel at 1,152 × 768 (a point behind the eye is recorded as null); colours 8-bit sRGB; JSON with sorted keys |
| Golden manifest | schema 1, frames {name: {description, digest}} | rewritten only with STARLIT_CARTOUCHE_WRITE_GOLDEN=1 |
| Solver regression record | level, witness replay, plan legs, statesByDepth[size − 1], work | all equal to the witness's; work ≤ workBound; per-action fingerprints and digests equal; won on the last leg only |
