# Research: R02-F18

- **R1 Chunked levels of detail with edge stitching.** Decision: a fixed P × P grid of pieces, power-of-two sampling per
  level, a one-level neighbour rule and odd edge points set to the mean of their even neighbours where the neighbour is
  coarser. Rationale: simple, deterministic, exactly crack-free because the even points are bit-identical (power-of-two
  spacing) and the odd points lie on the coarse edge. Alternatives: skirts (hide cracks instead of removing them),
  geomorphing (needs a time parameter), ROAM or CLOD (heavier, order-dependent).
- **R2 Reusing `HeightField`.** Decision: each piece samples through `HeightField(columns:rows:cellSize:originX:originZ:height:)`
  so heights and normals come from the existing type; every point is sampled and placed at (global grid index) · s, so equal points of
  neighbouring pieces are the same doubles for any s (origin + i · cellSize was not, for s = 0.1).
- **R3 Budget.** Decision: shrink the distance per level in quarter-octave steps, D · 2^(−t/4), until the balanced
  selection fits; refuse when even the coarsest tiling exceeds it. Rationale: each step is an ordinary distance-based
  selection, so detail falls with distance (apart from the one-level refinement) and the result is deterministic.
  Rejected in implementation: coarsening the farthest coarsenable piece first, which left farther pieces finer than
  nearer ones when the budget bound.
- **R4 D8 flow accumulation.** Decision: O'Callaghan and Mark (1984) D8, visiting points from highest to lowest so every
  point's inflow is complete before it passes on; ties fixed by order. Rationale: deterministic, single pass after a sort.
  Log scaling keeps the mask readable across orders of magnitude.
- **R5 Analytic sky.** Decision: a gradient with dusk tint, night scale, sun disc and glow (clarification Q4) evaluated
  per pixel from the view direction, identical in GLSL and Swift (float on the GPU, double on the CPU, compared within 2
  of 255). Rationale: no image, cheap, and testable against a CPU reference. Alternatives: Preetham or Hosek–Wilkie
  physical models (heavier, coefficient tables), sky textures (forbidden).
- **R6 Far-plane full-screen pass.** Decision: one triangle with z = w so depth is 1, depth test LEQUAL, no depth write;
  the direction is inverse(VP) · (ndc, 1) minus the eye. Rationale: draws only where nothing nearer was drawn, at the
  cost of one triangle.
