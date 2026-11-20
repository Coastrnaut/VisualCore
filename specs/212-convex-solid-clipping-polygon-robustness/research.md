# Research: R02-F12

- **R1 Representation.** Decision: vertices plus faces as index polygons, wound CCW from outside, each with an outward
  unit normal and offset. Rationale: a cut clips each face polygon and adds one cap; triangles would multiply slivers.
  Alternatives: half-edge structure (heavier, not needed for convex solids); half-space list only (no vertices to draw).
- **R2 Cut.** Decision: classify vertices by signed distance d = n·p − h with ε = 1e-9 × L (|d| ≤ ε → on); clip every
  face polygon against the half-space (Sutherland–Hodgman, 1974) keeping on-plane vertices on both sides and creating
  intersection points on crossing edges; merge points within ε; collect the on-plane points into the cap, order them by
  angle around their centroid in the plane basis, wind the kept part's cap with normal +n and the removed part's with
  −n; drop degenerate faces. Rationale: exact for convex solids, deterministic ordering. Alternatives: BSP (overkill).
- **R3 Volume.** Decision: divergence theorem: V = Σ faces (1/3)(n · c) A over fan triangles, computed as Σ p0·(p1×p2)/6
  per fan triangle, matching `Mesh.validate`. Rationale: consistent with the existing validation.
- **R4 Convexity check.** Decision: a mesh is convex when every vertex is on or below every face plane (d ≤ ε);
  coplanar adjacent triangles of the mesh are merged into polygon faces by normal (within 1e-9) and offset (within ε).
- **R5 Determinism.** Decision: no hashing of unordered collections in results; vertices in first-seen order; caps
  sorted by angle with ties by index. Rationale: identical results across runs and devices.
- **R6 Stored form.** Decision: JSON schema 1 of vertices and faces plus the ledger; decoding re-validates convexity and
  closedness. Rationale: as R02-F11.
