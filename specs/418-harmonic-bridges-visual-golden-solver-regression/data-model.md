# Data model: R02-G12-08

| Entity | Fields | Rules |
|---|---|---|
| `HarmonicBridgesGolden.Frame` | name, level, tier, time, actions | 16 frames: levels 1, 21, 41, 61, 81 × tiers 0 … 2 at time 0 after the witness's tunings and before its test, plus the hero frame of `scenario-manifest.json` at tier 0 |
| Frame description | islandTops, stringMidpoints, membranes, pips [[x, y]] (index order), firstGaugeBar [x, y], counts {islands, strings, bridges, filledMarks, hollowMarks, pips, gaugeLit, gaugeTotal}, colours {ground, islandFace, islandEdge, string, membrane, markFilled, markHollow, start, goal, pip, pipUnlit, gaugeLit, gaugeUnlit} rgb | positions rounded to 1/8 px at 1,152 × 768, authored camera; colours 8-bit sRGB; JSON with sorted keys; an off-screen point is recorded as null |
| `golden-frames.json` | schema 1, frames {name: {description, digest}} | rewritten only with HARMONIC_BRIDGES_WRITE_GOLDEN=1 |
| Solver regression record | level, witness replay, tunings, smallerChoices, work | all equal to the witness's; work ≤ workBound; per-action fingerprints and per-step bridge digests equal; won within the budget |
| Memory cycle | footprint after each of 12 cycles, live GPU objects after close and warning | cycles 2 … 12 within 16 MB of cycle 1 when isolated; live objects 0 |
