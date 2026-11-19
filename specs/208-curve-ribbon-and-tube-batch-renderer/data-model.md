# Data Model: R02-F08

- **ParametricCurve** (protocol): `segmentCount: Int`, `isClosed: Bool`, `position(segment:t:) -> Vec3`,
  `derivative(segment:t:) -> Vec3`, t in 0…1.
- **CubicBezierChain**: open: 3n + 1 control points (n ≥ 1); closed: 3n control points; all finite.
- **CatmullRomSpline**: ≥ 2 distinct points open (end points duplicated as phantom points), ≥ 3 closed; alpha 0.5.
- **CurveSamples**: `positions`, `tangents` (unit), `arcLengths` (cumulative, first 0), `isClosed`; count ≤ 65,536.
- **CurveFrame**: `position`, `tangent`, `normal`, `binormal` (= tangent × normal), orthonormal.
- **RibbonWidth**: `.constant(Double)` or `.perSample([Double])`; finite, > 0; per-sample count equals the samples'.
- **Errors**: `MeshError.invalidInput` (too few points, non-finite, bad tolerance, bad width) and `MeshError.budget`.
- **Ribbon mesh**: an open surface; triangles wound counter-clockwise seen from the side the frame normal points to
  (the mesh convention of R02-F05); boundary edges are the two long sides (and the ends of an open curve); validates
  with no problem other than being open.
