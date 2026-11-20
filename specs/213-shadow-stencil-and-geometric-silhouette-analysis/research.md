# Research: R02-F13

- **R1 Planar projection.** Decision: the closed forms of clarification Q2 on the CPU and the equivalent 4 × 4 planar
  projection matrix for the GPU: for plane (n, h) and homogeneous light l = (L, 1) or (d, 0), M = (n·l − h·w)I − l nᵀ
  with the plane as (n, −h) (Blinn, "Me and my (fake) shadow", IEEE CG&A 1988). Rationale: one formula, exact, cheap.
  Alternatives: shadow maps (readback-free but approximate and costly), shadow volumes with stencil (needs a stencil
  buffer the host lacks).
- **R2 Slab clipping.** Decision: clip each triangle to n · p ≥ h (above the ground) and, for a point light, to n · p ≤
  n · L − δ with δ = 1e-9 × scale, before projecting. Rationale: prevents flipped and infinite polygons. Alternatives:
  discarding whole triangles (loses partial shadows).
- **R3 Hull.** Decision: Andrew's monotone chain (1979) on projected 2D points, collinear points dropped, CCW. Rationale:
  O(n log n), deterministic with lexicographic sort.
- **R4 Rasteriser.** Decision: scanline at each row centre; crossings of each polygon's edges with the half-open rule;
  cells whose centre x lies inside an odd span are set; union by OR. Rationale: exact cell-centre coverage, no double
  counting at shared edges, O(rows × edges). Alternatives: per-cell point-in-polygon (O(cells × edges)).
- **R5 Single darkening.** Decision: coverage pass writes 1 into a pooled `.rgba8` target (the registry default; R8 is not guaranteed renderable) without blending, then one
  full-screen composite multiplies by (1 − darkness × coverage) with premultiplied blending. Rationale: overlaps are
  idempotent, exactly what a stencil test gives. Alternatives: GL_MAX blending directly onto the scene (changes colour
  semantics of other draws).
- **R6 Stored mask.** Decision: JSON schema 1 with region, width, height and base64 of the little-endian words; decoding
  checks the word count and zero padding bits. Rationale: compact and deterministic.
- **R7 Measured mask convergence (implementation, 2026-11-19).** Cell-centre sampling of one polygon does not halve its
  error at every refinement: over 10 seeded polygons the mean error went 0.00412 → 0.00258 (ratio 0.63) by edge luck;
  over 100 seeded polygons it went 0.003877 → 0.001116 (ratio 0.29), and the worst single error at 256² was 0.26% (limit
  1%). SC-R02F13-002 states the halving for the mean over 100 polygons. The subscript is `mask[x, y]` (no labels).
- **R8 Renderer as built (implementation, 2026-11-19).** The planar projection matrix is divided by its scale P · l
  (trace / 3) before drawing: for a directional light P · l = n · d < 0, so the unscaled matrix gives a negative w and
  the shadow is clipped away; the projected point is unchanged. The renderer exposes `public let mesh` like
  `MeshRenderer`. A coverage target that cannot be made (tested with a 0 × 0 viewport) throws, draws nothing and leaves
  the previous framebuffer bound. Measured on iOS 27.2: 3,708 compared pixels, 195 covered, 0 mismatches against the
  CPU coverage; 440 overlapping-shadow pixels all at the single-shadow value (0/255).
