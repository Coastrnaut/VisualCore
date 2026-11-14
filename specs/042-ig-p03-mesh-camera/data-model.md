# Data model: A05-P03

- **GeometryCore.Orbit3D** (schema 3): `yaw` (−π…π), `pitch` (±80°), `distance` (3…12, raised by the bounding-sphere rule),
  `target` (x, y, z; |target| ≤ 1; default origin), `fovDegrees` (30…75; default 60). `camera` → `OrbitCamera(target:,
  distance:, yaw:, pitch:, fovY:)`.
- **Bounding radius**: derived from the built solid (`MeshBounds` |centre| + radius); not stored; recomputed on build.
- **Actions**: `camera.pan [dx, dy]` (3D: target along right/up), `camera.fov [degrees]`, existing `camera.zoom`,
  `camera.orbit`, `camera.reset` (resets target and field of view too).
- **Snapshot**: schema 3; migration 2 → 3 adds target (0,0,0) and fov 60; 1 → 2 unchanged from Phase 02.
- **DepthMeshPass.Item**: `renderer: MeshRenderer`, `model: Mat4`, `color: Vec4`.
