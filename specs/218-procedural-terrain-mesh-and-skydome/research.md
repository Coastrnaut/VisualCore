# Research: R02-F18

- **R1 Chunked levels of detail with edge stitching.** Decision: a fixed P × P grid of pieces, power-of-two sampling per
  level, a one-level neighbour rule and odd edge points set to the mean of their even neighbours where the neighbour is
  coarser. Rationale: simple, deterministic, exactly crack-free because the even points are bit-identical (power-of-two
  spacing) and the odd points lie on the coarse edge. Alternatives: skirts (hide cracks instead of removing them),
  geomorphing (needs a time parameter), ROAM or CLOD (heavier, order-dependent).
- **R2 Reusing `HeightField`.** Decision: each piece samples through `HeightField(columns:rows:cellSize:originX:originZ:height:)`
  so heights and normals come from the existing type; x = origin + i · s · 2^ℓ is the same double for equal points of
  neighbouring levels because doubling is exact.
- **R3 Budget.** Decision: coarsen the farthest coarsenable piece first until within budget; refuse when even the
  coarsest tiling exceeds it. Rationale: detail is lost where it matters least, deterministically.
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
