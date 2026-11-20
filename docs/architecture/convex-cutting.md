# Convex solids and cuts

Feature 212 (R02-F12). Spec: [specs/212-convex-solid-clipping-polygon-robustness](../../specs/212-convex-solid-clipping-polygon-robustness/spec.md).

## Representation

A `ConvexSolid` (VisualCoreScenes) is a list of vertices and a list of faces; each face is a convex polygon of 3 to 256
vertex indices wound counter-clockwise seen from outside, with its outward unit plane. Limits: 4,096 vertices, 1,024
faces. A solid is made from a box, from a set of `ClipPlane`s bounded by a box (the box cut by each plane in turn), or
from a closed convex `Mesh`. Building from an arbitrary point cloud is not offered.

## Tolerance

ε = 1e-9 × L, where L is the solid's bounding-box diagonal, so a millimetre gem and a metre block behave alike. A
vertex within ε of a plane is on it; points closer than ε are merged; a corner within ε of the line through its
neighbours is removed; a face with fewer than three corners or an area ≤ 1e-12 × L² is dropped; a part with no volume
beyond the tolerance is reported as empty, never as a sliver.

## Cut

`cut(by:)` keeps the side below the plane (distance ≤ 0) and removes the side above. Every face polygon is clipped
against both sides (Sutherland and Hodgman, "Reentrant polygon clipping", Communications of the ACM 17(1), 1974); the
point where an edge crosses the plane is made once for that edge, so the two faces that share it agree exactly and the
parts stay closed. The points on the plane form the cap, ordered by angle around their centroid; the kept part's cap
faces along the plane normal, the removed part's against it. The result gives both parts (or nil), the cap and both
volumes.

## Volume and ledger

Volume is the divergence theorem over the faces, Σ p0 · (p1 × p2) / 6 over the fan triangles — the same sum
`Mesh.validate` reports. `VolumeLedger` records each cut's plane, removed volume and remaining volume (at most 65,536
entries; the next cut beyond is refused and nothing changes) and holds |original − remaining − Σ removed| ≤ 1e-9 ×
original after every cut.

## Polygons

`PolygonCleanup.clean(_:normal:tolerance:)` removes repeated and collinear points and orients a planar polygon
counter-clockwise about a normal (area vector by Newell's method); fewer than three corners is a degenerate polygon.

## Stored form and failures

`ConvexSolidDocument` writes `{"schema":1,"solid":{"vertices":[…],"faces":[…]},"ledger":{…}}` with sorted keys and
re-validates closedness and convexity when reading; a newer schema or malformed data is refused. Every refusal is a
`ConvexSolidError` with a reason code `r2-f12.*`; the experience that reports it adds its own id, seed and tick.
`mesh()` turns a solid into a `Mesh` that `validate(requireClosed: true)` accepts.

## Sources

- I. E. Sutherland, G. W. Hodgman, "Reentrant polygon clipping", Communications of the ACM 17(1), 1974.
- M. E. Newell's polygon normal (area vector), as described in standard computer-graphics texts.

All code is original to VisualCore.
