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
- **R5 Single darkening.** Decision: coverage pass writes 1 into an R8 (or RGBA8) target without blending, then one
  full-screen composite multiplies by (1 − darkness × coverage) with premultiplied blending. Rationale: overlaps are
  idempotent, exactly what a stencil test gives. Alternatives: GL_MAX blending directly onto the scene (changes colour
  semantics of other draws).
- **R6 Stored mask.** Decision: JSON schema 1 with region, width, height and base64 of the little-endian words; decoding
  checks the word count and zero padding bits. Rationale: compact and deterministic.
