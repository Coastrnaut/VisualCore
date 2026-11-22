# Data model: R02-G07-08

| Entity | Fields | Rules |
|---|---|---|
| `AmethystEscapeGolden.Frame` | name, level, tier, time, actions | 16 frames: levels 1, 21, 41, 61, 81 × tiers 0 … 2 at time 0 after the witness's first min(smallest − 1, 3) actions, plus the hero frame of `scenario-manifest.json` at tier 0 |
| Frame description | pearl [x, y], exit [x, y], wedge tops [x, y] (wedge order), moves, move bar length, colours {backdrop, amethyst, highlight, platinum, blocked, pearl, exit, amber} rgb | positions rounded to 1/8 px at 1,152 × 768, authored camera; length rounded to 1/1,024; colours 8-bit sRGB; JSON with sorted keys; an off-screen point is recorded as null |
| `golden-frames.json` | schema 1, frames {name: {description, digest}} | rewritten only with AMETHYST_ESCAPE_WRITE_GOLDEN=1 |
| Solver regression record | level, witness replay, actions, smallest, depths, work | all equal to the witness's; work ≤ stateCount(level); per-move digests and fingerprints equal; won within the budget |
| Memory cycle | footprint after each of 12 cycles, live GPU objects after close and warning | cycles 2 … 12 within 16 MB of cycle 1 when isolated; live objects 0 |
