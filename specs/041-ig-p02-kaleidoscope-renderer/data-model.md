# Data Model: A05-P02

- **ViewBounds2D**: `zoomRange` (0.5…8 relative), `extent` (half-size of the allowed centre square).
- **OrbitBounds**: `pitchLimit` (80°), `distanceRange` (3…12).
- **Camera state in GeometryCore** (schema 2): `view2D` {centerX, centerY, zoom}; `orbit3D` {yaw, pitch, distance};
  defaults from the preset (2D centre 0, zoom 1; 3D yaw 0, pitch 0.5, distance 6).
- **Actions**: `camera.pan [dx, dy]` (world units), `camera.zoom [factor > 0]`, `camera.orbit [dyaw, dpitch]` (radians),
  `camera.reset []`; non-finite or non-positive factor refused (`action.out-of-range` / rule codes).
