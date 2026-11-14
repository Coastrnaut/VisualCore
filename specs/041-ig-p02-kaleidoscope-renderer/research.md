# Research: A05-P02 (feature 041)

## 0. Verified facts (2026-11-13)

- `FullScreenShaderScene(fragment:fragmentName:bundle:)`: binds `u_resolution`, `u_palette[8]`, `u_paletteCount`,
  `u_seed`, `u_time`, and `u_<name>` floats from `parameters`; compile errors go to `errorMessage`.
- `vc/sdf.glsl` has `vc_sdSphere`, `vc_sdBox`, `vc_sdTorus`, `vc_smoothUnion`, `vc_rotate` only.
- `Camera2D` (center, zoom 0.1…100, rotation, `zoom(by:around:)`), `OrbitCamera` (target, distance, yaw, pitch ±89°).
- `ShaderHashParityTests` renders values into a colour target and reads them back for a CPU comparison.

## 1. Decisions

- **D1 GLSL fold:** `vec2 vc_foldDihedral(vec2 p, float n)` uses the same steps as `PointGroup.fold` (angle reduced into
  the 2π/n wedge, then mirrored above π/n); the parity test encodes folded coordinates as colours.
- **D2 Camera bounds:** pure value types in VisualCoreMath; the experience stores camera state and clamps in its actions.
- **D3 Kaleidoscope shader:** distance to the motif polygon (convex SDF) in folded coordinates for each repeat ring;
  coverage via `smoothstep` over one pixel; colour from the palette by ring.
- **D4 Snapshot schema 2:** camera fields added; migration from 1 fills defaults (shared `MigrationChain`).

## 2. Analysis record (`/speckit-analyze`, 2026-11-13)

- C1 (HIGH) fixed: FR-A05-220 no longer lists a framework convex-polygon helper; matches contracts/api.md. Re-run:
  0 critical, 0 high.
