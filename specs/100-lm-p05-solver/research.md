# Research: A13-P05 (feature 100)

## D1 — Search space
- **Decision**: orientation sets of the turnable tiles (tiles never move); a turn toggles one tile (clarification Q1).
- **Alternatives**: positions as well (rejected: the rules have no moves; the A13-P00 G-SOLVER wording "cells and
  orientations" is narrowed to what the board allows).

## D2 — Order and minimality
- **Decision**: k = 0…n turns, combinations of tile indices in lexicographic order; the first solved set has the
  fewest turns; deterministic.
- **Alternatives**: breadth-first over toggles (same sets, more bookkeeping); depth-first (not minimal).

## D3 — Limit
- **Decision**: 16 turnable tiles (65,536 sets); refuse above; invalid boards refused first.
- **Rationale**: the catalog's largest level has 8; the board cap (144 tiles) would make 2¹⁴⁴ sets, so a limit is
  required; 16 keeps a full search within one short test.

## D4 — QA report
- **Decision**: `ContentQA.results(_:)` per level, `ContentQA.markdown(_:)` for `docs/apps/light-maze/content-qa.md`,
  compared with the committed file by a test and regenerated with `UPDATE_CONTENT_QA=1` (precedent:
  `LicenseAudit.markdown` and `content-licenses.md`).

## D5 — Beam fixture
- **Decision**: a dedicated experience test over all 20 levels × 3 boards (start, recorded, solver answer) comparing
  the scene's core beam lines with the tracer's segments (precedent: `MazeGlowTests` on five levels).
