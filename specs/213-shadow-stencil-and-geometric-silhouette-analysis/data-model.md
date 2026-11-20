# Data model: R02-F13

- **ShadowLight**: `.point(Vec3)` | `.directional(Vec3)` (direction from the light into the scene, normalised from a
  finite non-zero input).
- **ProjectionPlane**: `plane: ClipPlane`; `origin = n · offset`; `u`, `v` (u = normalised(n × e), v = n × u, e the
  world axis least aligned with n, ties x then y); `point(of p2: Vec2) -> Vec3`, `coordinates(of p: Vec3) -> Vec2`.
- **ShadowProjector**: static `project(_ point:light:onto:) throws(ShadowError) -> Vec2?` (nil when the point casts no
  shadow), `projectTriangle(...) -> [Vec2]` (0 or 3…5 corners after slab clipping), `project(mesh:light:onto:) ->
  [[Vec2]]` (≤ 1,048,576 triangles), `outline(of solid: ConvexSolid, light:onto:) -> [Vec2]` (convex, CCW, empty when no
  shadow), `matrix(light:onto:) -> Mat4`.
- **ConvexHull2D**: `hull(_ points: [Vec2]) -> [Vec2]` (CCW, no collinear points), `area(_ polygon: [Vec2]) -> Double`
  (signed, CCW positive).
- **CoverageMask**: `min: Vec2`, `max: Vec2` (min < max), `width`, `height` (1…2,048), `words: [UInt64]` (row-major,
  padding bits zero); `init(min:max:width:height:) throws`, `fill(_ polygon: [Vec2])`, `fill(_ polygons:)`, `subscript(x,
  y) -> Bool`, `count`, `area`, `digest: UInt64`, Codable (schema 1 via `CoverageMaskDocument`).
- **MaskComparison**: `intersection: Int`, `union: Int`, `iou: Double`; `init(_ a:, _ b:) throws(ShadowError)`.
- **ShadowError**: cases of clarification Q5; `reasonCode` `r2-f13.*`.
