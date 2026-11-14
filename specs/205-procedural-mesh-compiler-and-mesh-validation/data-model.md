# Data Model: R02-F05

- **Mesh** (existing, unchanged): `positions [Vec3]`, `normals [Vec3]`, `uvs [Vec2]`, `indices [UInt32]`.
- **MeshBudget**: `maxVertices` (default 262,144), `maxIndices` (default 1,572,864); both ≥ 0 and ≤ UInt32.max.
- **MeshBuilder**: `budget`, `weldTolerance` (default 1e-9 relative), `weldPositionsOnly`, `vertexCount`, `indexCount`,
  vertex arrays, key → index map, indices.
- **MeshError**: `.budget(vertices:indices:budget:)`, `.invalidInput(String)`.
- **MeshProblem**: `kind` (one of: indexOutOfRange, indexCountNotMultipleOfThree, arrayLengthMismatch,
  degenerateTriangle, nonFinitePosition, nonFiniteNormal, nonFiniteUV, nonUnitNormal, uvOutOfRange, nonManifoldEdge,
  inconsistentWinding, boundaryEdge, invertedFaces, budget), `triangle: Int?`, `vertex: Int?`, `edge: (UInt32, UInt32)?`.
- **MeshSummary**: `vertices`, `triangles`, `boundaryEdges`, `isClosed`, `boundsMin`/`boundsMax: Vec3?` (nil for an
  empty mesh; kept as two vectors so the summary is Codable), `volume: Double?` (closed only).
- **MeshReport**: `problems [MeshProblem]` (≤ 100), `moreProblems: Int`, `summary`, `isValid`; `description` (text)
  and `Codable` (structured).
- **MeshBounds**: `.empty` or `.box(min: Vec3, max: Vec3)` with `center`, `radius` (enclosing sphere).
