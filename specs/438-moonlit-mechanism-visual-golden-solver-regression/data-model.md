# Data model: R02-G14-08

| Entity | Fields | Rules |
|---|---|---|
| `MoonlitMechanismGolden.Frame` | name, level, tier, time, actions | 16 frames: levels 1, 21, 41, 61, 81 × tiers 0 … 2 at time 0 after the witness's actions before its run, plus the hero frame at tier 0 |
| Frame description | castCentres, gearCentres, rimPoints, cardCentres [[x, y]] (index order), firstPip, lamp, firstMovesBar [x, y], counts {gears, cast, targets, missing, stray, forbidden, litCards, alignedPips, litMoves, moves}, colours {name: [r, g, b]} | positions rounded to 1/8 pixel at 1,152 × 768 (a point behind the eye is recorded as null); colours 8-bit sRGB; JSON with sorted keys |
| Golden manifest | schema 1, frames {name: {description, digest}} | rewritten only with MOONLIT_MECHANISM_WRITE_GOLDEN=1 |
| Solver regression record | level, witness replay, plan components, smallerVectors, work | all equal to the witness's; work ≤ workBound; per-action fingerprints and digests equal |
