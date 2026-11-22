# Data model: R02-G08-01

| Entity | Fields | Rules |
|---|---|---|
| `FacetedForgeFraction` | numerator, denominator (Int64) | reduced, denominator > 0; checked +, −, ×, ÷; ordered; written "n/d" |
| `FacetedForgeDirection` | index 0 … 12, vector (x, y, z in −1 … 1) | named "x", "y", "z", "x+y", "x−y", "x+z", "x−z", "y+z", "y−z", "x+y+z", "x+y−z", "x−y+z", "−x+y+z" |
| `FacetedForgeHalfSpace` | direction, sign (+1 or −1), depth (−24 … 24) | the points p with sign·(n·p) ≤ sign·depth |
| `FacetedForgePiece` | half-spaces (sorted, duplicates removed) | derived: corners (exact points), faces (planes with ≥ 3 corners, corners ordered), edges, face count, volume |
| `FacetedForgeTargetPiece` | share (fraction of the crystal), faces (4 … 26) | shares sum to 1; at least two entries |
| `FacetedForgeLevel` | id, seed, difficulty 1 … 5, crystal (4 … 14 half-spaces), budget 1 … 12, sliver (fraction 0 < s < 1/2), target, tutorial, fingerprint | crystal bounded inside −6 … 6 with an interior; schema 1; sorted-key JSON |
| `FacetedForgeAction` | cut(piece, direction, depth) | piece 0 … count − 1 in canonical order; each accepted one spends one cut |
| `FacetedForgePlay` | stage, pieces (canonical order), cuts, failure (`sliver(piece, cut)`, `budget`), records, undo/redo stacks | records carry previous and next fingerprints |
| `FacetedForgeRecord` | schema, level seed, cut, kind (cut, undo, redo), action (nil for undo and redo), previous and next fingerprints | appended for every accepted action |
| `FacetedForgeRules.Position` | pieces, cuts, outcome (playing, won, failed) | moves: every non-degenerate cut of every piece, pieces in order, directions 0 … 12, depths ascending |
