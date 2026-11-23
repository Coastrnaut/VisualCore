# Data model: R02-G11-08

| Entity | Fields | Rules |
|---|---|---|
| `EchoCartographerGolden.Frame` | name, level, tier, time, actions | 16 frames: levels 1, 21, 41, 61, 81 × tiers 0 … 2 at time 0 after the witness's first min(pulses − 1, 2) pulses (at least one) and one marker on the first known-open cell that is not the entry, plus the hero frame of `scenario-manifest.json` at tier 0 |
| Frame description | floors, walls, markers, pillars [[x, y]] (cell order), entry [x, y], firstGaugeBar [x, y], counts {open, walls, markers, located, rays, gaugeLit, gaugeTotal}, colours {ground, floor, entry, marker, wallFace, wallEdge, pillar, ray, gaugeLit, gaugeUnlit} rgb | positions rounded to 1/8 px at 1,152 × 768, authored camera; colours 8-bit sRGB; JSON with sorted keys; an off-screen point is recorded as null |
| `golden-frames.json` | schema 1, frames {name: {description, digest}} | rewritten only with ECHO_CARTOGRAPHER_WRITE_GOLDEN=1 |
| Solver regression record | level, witness replay, pulses, placements, work | all equal to the witness's; work ≤ workBound; per-pulse echo digests and per-action fingerprints equal; won within the energy |
| Memory cycle | footprint after each of 12 cycles, live GPU objects after close and warning | cycles 2 … 12 within 16 MB of cycle 1 when isolated; live objects 0 |
