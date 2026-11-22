# Research: R02-G09-01

- **R1 Integer cells instead of floating-point rasterization.** Decision: shadows are lattice polygons scaled by an
  integer size and stretched by the rational sun factor e/2; a cell is dark when its centre lies inside or on the
  boundary, tested with doubled integer coordinates by the winding number. Rationale: "rasterized into a deterministic
  low-resolution mask" decided alike on every device; the bounds keep every product far inside `Int`. Alternatives:
  floating-point scan conversion (edge cells judged differently), supersampling (slower, no more exact).
- **R2 Six fixed bloom outlines.** Decision: tulip, bell, star, fern, rose and lily as simple polygons with integer
  vertices, foot at the origin, at most 3 × 6 cells at size 1. Rationale: the solver of R02-G09-02 can enumerate every
  placement; outlines are nameable in words; the L-system stems and leaves of the catalog are the drawing of R02-G09-03,
  laid over the same outlines. Alternatives: generated outlines per level (unbounded search, harder to name).
- **R3 A discrete sun.** Decision: four elevations, factor e/2 about each bloom's foot. Rationale: "slide sun elevation"
  becomes one action with four exact outcomes; the solver's branching stays small.
- **R4 Match by cross multiplication.** Decision: match = |M ∩ T| / |M ∪ T| ≥ p / q tested as |M ∩ T|·q ≥ p·|M ∪ T|.
  Rationale: "IoU exceeds requirement" with no rounding; an empty union never wins.
- **R5 Leak, then win, then budget.** Decision: judged after each accepted action in that order; nothing before the first
  bloom. Rationale: a leak beyond the allowance is always a failure; a win on the last move counts.
- **R6 Boundary deviation as the truth metric.** Decision: the symmetric Chebyshev Hausdorff distance between the two
  sets of boundary cells, reported after every action and never deciding. Rationale: the catalog's "contour Hausdorff
  proxy" on the same exact grid; independent of the win rule.
- **R7 Fingerprints as the signed snapshot.** Decision: the play fingerprint (SHA-256 of schema, level fingerprint,
  blooms in canonical order, sun, moves, stage, failure) and records with previous and next fingerprints, as feature 371.
