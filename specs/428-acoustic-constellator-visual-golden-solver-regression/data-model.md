# Data model: R02-G13-08

| Entity | Fields | Rules |
|---|---|---|
| `AcousticConstellatorGolden.Frame` | name, level, tier, time, actions | 16 frames: levels 1, 21, 41, 61, 81 × tiers 0 … 2 at time 0 after the witness's links and nudges and before its test, plus the hero frame of `scenario-manifest.json` at tier 0 |
| Frame description | starCentres, linkCheckPoints [[x, y]] (index order), firstCoherenceBar, firstHoldPip, firstMovesBar [x, y], counts {stars, links, tealLinks, guides, coherenceLit, holdLit, movesLit, movesTotal}, colours {sky, star, hand, silver, teal, guide, coherenceLit, coherenceUnlit, thresholdMark, holdLit, holdUnlit, movesLit, movesUnlit} rgb | positions rounded to 1/8 px at 1,152 × 768, authored camera; colours 8-bit sRGB; JSON with sorted keys; an off-screen point is recorded as null |
| `golden-frames.json` | schema 1, frames {name: {description, digest}} | rewritten only with ACOUSTIC_CONSTELLATOR_WRITE_GOLDEN=1 |
| Solver regression record | level, witness replay, links and nudges, smallerSets, work | all equal to the witness's; work ≤ workBound; per-action fingerprints and per-action digests equal; won within the budget |
| Memory cycle | footprint after each of 12 cycles, live GPU objects after close and warning | cycles 2 … 12 within 16 MB of cycle 1 when isolated; live objects 0 |
