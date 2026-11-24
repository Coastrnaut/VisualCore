# Data model: R02-G16-01

| Entity | Fields | Rules |
|---|---|---|
| `StarlitCartoucheVector` | x, y, z (Int) | lattice positions, each coordinate −8 … 8 |
| `StarlitCartoucheGlyphPoint` | x, y (Int) | 0 … 4 each; distinct per star |
| `StarlitCartoucheStar` | orbit (1 … 4 vectors), glyph point, window open, close | 0 ≤ open ≤ close ≤ 64 (independent of the deadline) |
| `StarlitCartoucheCorridor` | a < b (star indices), travel 1 … 3 | undirected; at most 24; no duplicates |
| `StarlitCartoucheHazard` | corridor index, from ≤ to (beats) | at most 8 |
| `StarlitCartoucheLevel` | id, seed, difficulty 1 … 5, stars (4 … 12), range 1 … 12, corridors, hazards, start, beacon, deadline 1 … 64, symbol (1 … 12 corridor indices, distinct), budget 1 … 16, tutorial, fingerprint | start's window contains 0; schema 1; sorted-key JSON |
| `StarlitCartoucheLeg` | from, to, corridor, wait, depart t₀, arrive t₁ | computed for an action |
| `StarlitCartoucheRouteReport` | star, beat, drawn, missing, stray, mismatch, clearance (nil = clear) | exact; never decides by itself |
| `StarlitCartoucheAction` | leg(star, wait 0 … 8) | spends 1 action |
| `StarlitCartoucheFailure` | departure(star, beat, close), hazard(corridor, hazard, from, to), arrival(star, beat, open, close), deadline(beat, deadline), stroke(corridor), budget(spent) | codes `window`, `hazard`, `window`, `deadline`, `stroke`, `budget` |
| `StarlitCartouchePlay` | stage, star, beat, drawn, legs, actions spent, report, failure, records, undo/redo stacks | records carry previous and next fingerprints |
| `StarlitCartoucheRecord` | schema, level seed, index, kind (leg, undo, redo), action, previous and next fingerprints | appended for every accepted action |
| `StarlitCartoucheRules.Position` | star, beat, drawn, actions spent, outcome (playing, won, failed) | moves: every corridor from the star, waits 0 … 8, flyable ones only |
