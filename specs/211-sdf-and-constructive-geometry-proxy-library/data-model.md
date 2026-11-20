# Data model: R02-F11

- **SDFShape** (indirect enum, Sendable, Equatable): `plane(normal: Vec3, offset: Double)` (normal normalised, non-zero),
  `sphere(radius:)`, `box(halfExtents: Vec3)`, `roundedBox(halfExtents: Vec3, radius:)` (radius ≤ min half extent),
  `capsule(a: Vec3, b: Vec3, radius:)`, `torus(major:, minor:)` (minor < major), `union([SDFShape])`,
  `intersection([SDFShape])`, `subtraction(SDFShape, SDFShape)`, `smoothUnion(SDFShape, SDFShape, radius:)`,
  `translated(SDFShape, by: Vec3)`, `rotated(SDFShape, by: Quat)`, `scaled(SDFShape, by: Double)`. Built through
  validating static makers that throw `SDFError`; at most 256 nodes, depth 32; union/intersection take 1…32 children.
- **SDFMarchOptions**: `mode` (`conservative` | `fast`), `maxSteps` 1…4,096 (128), `maxDistance` > 0 (100),
  `tolerance` > 0 (1e-7).
- **SDFMarchResult**: `outcome` (`hit` | `miss` | `budgetExhausted`), `distance`, `point`, `normal`, `steps`,
  `startedInside`.
- **SDFVolumeSample**: `boundsMin`, `boundsMax` (min < max per axis), `resolution` 1…256, `insideCount`, `volume`,
  `digest` (UInt64 FNV-1a).
- **SDFDocument**: `schema` 1, `shape`; JSON with `kind` tags.
- **SDFError**: `nonFinite(String)`, `nonPositive(String)`, `zeroDirection(String)`, `notUnitRotation`,
  `tooManyNodes(Int)`, `tooDeep(Int)`, `unknownKind(String)`, `newerSchema(Int)`, `malformed(String)`; `reasonCode`
  `r2-f11.*`.
