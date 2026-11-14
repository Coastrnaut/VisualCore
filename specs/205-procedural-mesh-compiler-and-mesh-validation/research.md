# Research: R02-F05 (feature 205)

## 0. Audit (section 13 disposition: extend; verified 2026-11-13)

- `Packages/VisualCore/Sources/VisualCoreScenes/MeshGenerators.swift`: `public struct Mesh: Sendable, Equatable`
  (`positions: [Vec3]`, `normals: [Vec3]`, `uvs: [Vec2]`, `indices: [UInt32]`, `triangleCount`,
  `interleavedPositionNormal()`), `plane(subdivisions:)`, `cube()`, `uvSphere(segments:rings:radius:)`, clamped ranges
  `subdivisionRange`, `segmentRange`, `ringRange`; triangles counter-clockwise from outside.
- `Packages/VisualCoreRendering/Sources/VisualCoreRendering/MeshRenderer.swift`: draws a `Mesh` (position + normal,
  32-bit indices) with Lambert lighting through `OrbitCamera`; rebuilds buffers after a context recreation.
- `Packages/VisualCore/Sources/VisualCoreMath/StableHash.swift`: `StableHash.sha256(_:) -> [UInt8]`, pure Swift.
- Users today: `MeshTests`, `MeshRendererTests`, `ShaderValidationTests`, Showcase `AnimatedGeometryScene`.

## 1. Decisions (clarifications binding)

- **D1 Welding:** quantize each component to a key by `(value / tolerance).rounded()` with the clarified relative
  tolerance; a dictionary from the key tuple to the first index; insertion order defines indices (deterministic).
  Alternative: sort-and-merge (rejected: order depends on sort stability of equal keys).
- **D2 Normals:** area-weighted by the face's cross product and angle-weighted by the corner angle; crease splitting by
  grouping a vertex's incident faces whose normals lie within the crease angle of each other (union over adjacency
  around the vertex). Flat normals duplicate vertices per face.
- **D3 Tube frames:** double-reflection rotation-minimizing frames (Wang et al. 2008); closed loops spread the residual
  twist angle linearly along arc length.
- **D4 Revolution:** profile points with radius ≤ tolerance become one pole vertex; segments clamped to `segmentRange`.
- **D5 Extrusion:** caps by ear clipping of the simple outline (counter-clockwise outline required; a clockwise outline
  is reversed; a self-intersecting outline is refused as invalid input).
- **D6 Bevelled box:** a rounded box made from a subdivided cube whose points are pushed to the inner box plus a
  sphere of the bevel radius (radius clamped to half the smallest side; 1…16 segments).
- **D7 Validation order:** topology uses a position-welded vertex map (clarified tolerance) so crease and seam splits
  do not count as holes; arrays and counts → indices → triangles (finite, degenerate) → edges (manifold, winding,
  boundary) → vertices (normals, uvs) → volume (closed only); first 100 problems, rest counted.
- **D8 Digest:** see the clarification; −0 normalized to +0 so equal meshes hash equally.
- **D9 Budget:** `MeshBudget(maxVertices: 262_144, maxIndices: 1_572_864)` default; checked before allocation from the
  shape's exact counts.

## 2. Analysis record (`/speckit-analyze`, 2026-11-13)

- C1 (HIGH) fixed: topology by welded position (FR-R02F05-030, D7). I1 (HIGH) fixed: generator digests recorded in
  T-R02F05-011 after the digest exists, generators proven unchanged by `git diff`. U1 (MEDIUM) fixed: ≥ 1% coverage.

## 3. Implementation record

- SC-R02F05-006 restated (2026-11-13): a release (`-c release`) test build of Packages/VisualCore fails in an unrelated
  existing target (`VisualCoreExperienceTests/RendererRecordTests` needs `@testable` symbols), so the < 1 s release
  figure cannot be measured with the package's tests; the bound is set on the debug build, which is slower (4.1 s at
  262,144 vertices). Shapes clamp resolution to at most 257 × 257 samples, so the budget-sized mesh is built through
  `MeshBuilder`.
- Smooth normals on a 32 × 16 sphere are radial within 0.015, not 1e-6 (area- and angle-weighted face normals of a
  coarse sphere are not exactly radial); the test uses 0.015 and checks seam copies to 1e-12.
- A cube smoothed at 100° keeps 24 vertices (their texture coordinates differ) and shares 8 diagonal normals.
