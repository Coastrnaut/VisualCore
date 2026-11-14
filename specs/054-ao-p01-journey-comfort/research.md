# Research: A07-P01 (feature 054)

## 0. Verified facts (2026-11-14)

- `VisualCoreMath` has no dependencies and holds `Vec3` (Double), `Mat4`, `Quat`, `Easing`, `OrbitCamera` (yaw,
  pitch, distance, target; `lookAt` with world up; no roll); `SeededRandom` is in `VisualCoreSimulation`.
- `DepthMeshPass.draw(_:camera:context:)` draws `MeshRenderer` items with depth testing through an `OrbitCamera`;
  `Mesh` and `MeshBudget` are in `VisualCoreScenes`.
- Experiences live in `Packages/ExperiencesCreative/<Name>` with Core, CoreTests, Experience (Adapter/), ExperienceTests
  and `scenario-manifest.json`; candidates are listed in `Catalog/registrations.json` and `ExperienceRegistry.candidates`.

## 1. Decisions

- **D1 Curve:** closed centripetal Catmull–Rom (alpha 0.5) with a 64-samples-per-span arc-length table and linear
  interpolation in it. Alternatives: uniform Catmull–Rom (cusps), Bézier fitting (more parameters, no benefit).
- **D2 Frame:** level frame from world up; vertical tangents within 30° refused at construction. Alternative:
  rotation-minimising frames (twist seam at the loop's wrap, roll drift against the horizon-lock rule).
- **D3 Flight:** speed approaches the target with acceleration clamped to the limit (trapezoidal), time step capped at
  0.1 s; sway is a lateral sine of travelled distance (period 40 units) scaled by the limit's sway (zero when reduced).
- **D4 Rebase:** origin = 1,024 × round(position ÷ 1,024) per axis, recomputed when the camera is farther than 1,024
  from it; drawn positions = Float(position − origin).
- **D5 Pieces:** 8 units of rail; window 2 behind and 8 ahead; budgets per clarifications; geometry built in rail
  space from distance and lateral offset so a piece's last ring equals the next piece's first ring exactly.
- **D6 Drawing:** `CameraRail.orbitCamera(at:)` gives the rail pose as an `OrbitCamera` (distance 1, yaw/pitch from
  the direction); `DepthMeshPass` draws the window with one colour per world.
