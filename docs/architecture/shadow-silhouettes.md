# Shadows and silhouettes

Feature 213 (R02-F13). Spec: [specs/213-shadow-stencil-and-geometric-silhouette-analysis](../../specs/213-shadow-stencil-and-geometric-silhouette-analysis/spec.md).

## The rule

The CPU decides and the GPU portrays. A shadow puzzle's score is computed from geometry on the CPU
(VisualCoreScenes); the drawing on the GPU uses the same projection but is never read back for a decision.

## Projection

A `ProjectionPlane` wraps a `ClipPlane` (n · p = h) with a fixed 2D basis: origin n · h; u = normalised(n × e), where e
is the world axis least aligned with n (ties to x, then y); v = n × u, so u × v = n everywhere. A `ShadowLight` is a
point light (position) or a directional light (direction from the light into the scene).

- Directional: p′ = p − d (n · p − h)/(n · d); refused when |n · d| < 1e-9 (parallel) or n · d ≥ 0 (pointing away).
- Point: p′ = L + (p − L)(h − n · L)/(n · (p − L)); the light must be above the plane.

Before projecting, geometry is clipped to the slab where a shadow is cast: above the plane and, for a point light, below
a plane through the light lowered by 1e-9 × scale, so no flipped or infinite polygon can appear. `ShadowProjector`
projects points, triangles, meshes and convex solids; a convex solid's shadow outline is the convex hull of its
projected geometry (`ConvexHull2D`, Andrew's monotone chain). `matrix(light:onto:)` is the same projection as a 4 × 4
matrix (Blinn 1988) for drawing.

## Masks and IoU

A `CoverageMask` covers a rectangle of the plane basis with 1…2,048 × 1…2,048 cells, packed as bits. A cell is covered
when its centre lies inside a polygon (even–odd), found row by row from edge crossings at the row centre with a
half-open rule, so two polygons sharing an edge never both claim a cell. Many polygons are unioned. `MaskComparison`
gives intersection, union and IoU = |A ∩ B| / |A ∪ B|; two empty masks score 1; masks of different region or size are
refused. A mask's digest is FNV-1a 64 over its words; `CoverageMaskDocument` stores it as schema-1 JSON with the words in
base64.

## Drawing

`PlanarShadowRenderer` draws the mesh flattened by the projection matrix into a pooled coverage target, writing 1
without blending so overlaps are idempotent, then composites a constant darkness onto the framebuffer once. Each
covered pixel darkens exactly once, as a stencil test would give, without the stencil buffer the host does not have.
If the target cannot be made the drawing throws and draws nothing; no decision is affected.

## Failures

`ShadowError` reason codes: `r2-f13.non-finite`, `r2-f13.zero-direction`, `r2-f13.parallel-light`,
`r2-f13.light-on-plane`, `r2-f13.light-below-plane`, `r2-f13.mask-size`, `r2-f13.mismatched-masks`,
`r2-f13.too-many-triangles`, `r2-f13.newer-schema`, `r2-f13.malformed`; the experience that reports one adds its id,
seed and tick.

## Sources

- J. F. Blinn, "Me and my (fake) shadow", IEEE Computer Graphics and Applications 8(1), 1988 (planar projection shadows).
- A. M. Andrew, "Another efficient algorithm for convex hulls in two dimensions", Information Processing Letters 9(5),
  1979.

All code is original to VisualCore.
