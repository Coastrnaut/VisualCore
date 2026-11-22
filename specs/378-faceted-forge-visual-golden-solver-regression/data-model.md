# Data model: R02-G08-08

| Entity | Fields | Rules |
|---|---|---|
| `FacetedForgeGolden.Frame` | name, level, tier, time, actions | 16 frames: levels 1, 21, 41, 61, 81 × tiers 0 … 2 at time 1 s after the witness's first min(smallest − 1, 2) cuts, plus the hero frame of `scenario-manifest.json` at tier 0 |
| Frame description | pieces [[x, y]] (canonical piece order), preview [x, y], cuts spent, budget, colours {ground, ice, highlight, ruby, amber, lattice, sliver, spent, unspent} rgb | positions rounded to 1/8 px at 1,152 × 768, authored camera, the initial preview choice (`FacetedForgePreviewChoice.initial`); colours 8-bit sRGB; JSON with sorted keys; an off-screen point is recorded as null |
| `golden-frames.json` | schema 1, frames {name: {description, digest}} | rewritten only with FACETED_FORGE_WRITE_GOLDEN=1 |
| Solver regression record | level, witness replay, cuts, smallest, work | all equal to the witness's; smallest = lowerBound(level); work ≤ workBound; per-cut digests and fingerprints equal; won within the budget |
| Memory cycle | footprint after each of 12 cycles, live GPU objects after close and warning | cycles 2 … 12 within 16 MB of cycle 1 when isolated; live objects 0 |
