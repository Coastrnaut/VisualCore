# Research: R02-F08

- **R1 Curve families.** Decision: cubic Bézier chains and centripetal Catmull-Rom (alpha 0.5, Barry–Goldman). Rationale:
  Bézier for authored shapes, centripetal Catmull-Rom for curves through points without cusps or self-loops. Alternative:
  B-splines (rejected for this slice: not interpolating).
- **R2 Adaptive sampling.** Decision: recursive midpoint subdivision with a 5-point chord-distance test, depth 20, at
  least one split per segment unless collinear. Rationale: deterministic and tight for cubics.
- **R3 Frames.** Decision: double reflection (Wang et al. 2008), as the existing internal `pathFrames`, made public on
  samples with scale-aware collapse and reversal rules. Rationale: proven in R02-F05's tube tests.
- **R4 Texture coordinates.** Decision: v = arc length / repeat length; closed curves round the repeat count so seams
  meet. Rationale: constant pattern size, continuous seams.
- **R5 Batching.** Decision: merge into one mesh; no instancing. Rationale: the existing renderer draws one mesh per
  call, and curve content changes rarely.
