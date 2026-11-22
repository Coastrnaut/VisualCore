# Data model: R02-G06-01

| Entity | Fields | Rules |
|---|---|---|
| `ChronoConstellatorShape` | ring, cross, diamond, triangle, square | names in words for accessibility; star i has shape i; a star is described by `ChronoConstellatorLevel.description(ofStar:)` (the level knows its index and the grid) |
| `ChronoConstellatorStar` | loop (cells, 4 … 32, distinct, consecutive and last-first 4-neighbours), phase 0 … L − 1, target (on the loop) | targets pairwise distinct |
| `ChronoConstellatorLevel` | id, seed, difficulty 1 … 5, columns 5 … 12, rows 5 … 10, stars 2 … 5, budget 1 … 20, tick limit 1 … 1,200, tutorial, fingerprint | schema 1; sorted-key JSON |
| `ChronoConstellatorHold` | star, start ≥ 1, length 1 … 60, end = start + length − 1; ordered by star, then start | start + length − 1 ≤ tick limit; a star's holds neither overlap nor touch |
| `ChronoConstellatorTimeline` | phases per star, holds (sorted by star, start), edits in use, fingerprint | edits in use = changed phases + holds ≤ budget |
| `ChronoConstellatorAction` | phase(star, offset), hold(star, start, length), release(star, start), step(ticks 1 … 1,200), rewind | edits only at tick 0 |
| `ChronoConstellatorPlay` | stage, tick, timeline, failure (`collision(star, star, cell)`, `time`), records, undo/redo stacks (snapshots) | records carry previous and next fingerprints |
| `ChronoConstellatorRecord` | schema, level seed, tick, kind (phase, hold, release, step, rewind, undo, redo), action (nil for undo and redo), previous and next fingerprints | appended for every accepted action |
| `ChronoConstellatorRules.Position` | timeline, tick, outcome (playing, won, failed) | moves at tick 0: phases, holds on starts 1 … 32 × lengths 1 … 32, releases, step(tick limit); after tick 0 only rewind |
