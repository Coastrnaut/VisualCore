# Data model: R02-F12

- **ClipPlane**: `normal: Vec3` (unit, from a finite non-zero input), `offset: Double` (finite); `distance(to p) = n·p −
  offset`; kept side is distance ≤ 0.
- **ConvexSolid**: `vertices: [Vec3]` (≤ 4,096, finite), `faces: [[Int]]` (≤ 1,024, each 3…256 distinct indices, convex,
  CCW from outside), `planes: [ClipPlane]` (one per face, outward); `diagonal` L (> 0); `tolerance` = 1e-9 × L;
  `volume` > 0. Makers: `box(min:max:)` (min < max), `bounded(by planes:in box:)`, `init(mesh:)` (closed, convex).
- **ConvexCutResult**: `kept: ConvexSolid?`, `removed: ConvexSolid?`, `cap: [Vec3]` (empty when the plane misses),
  `keptVolume`, `removedVolume`.
- **VolumeLedger**: `original: Double`, `entries: [Entry]` (≤ 65,536), `Entry { plane: ClipPlane; removed: Double;
  remaining: Double }`, `current: ConvexSolid?`; `cut(by:) throws`, `imbalance` (|original − remaining − Σ removed| /
  original), `isBalanced` (≤ 1e-9).
- **PolygonCleanup**: `clean(_ points: [Vec3], normal: Vec3, tolerance: Double) throws(ConvexSolidError) -> [Vec3]`.
- **ConvexSolidDocument**: schema 1; `solid`, optional `ledger`.
- **ConvexSolidError**: `nonFinite(String)`, `zeroNormal`, `empty`, `notClosed`, `notConvex`, `tooComplex(String)`,
  `degeneratePolygon`, `newerSchema(Int)`, `malformed(String)`; `reasonCode` `r2-f12.*`.
