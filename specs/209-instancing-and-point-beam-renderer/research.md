# Research: R02-F09

- **R1 Per-instance matrix.** Decision: four vec4 attributes (locations 3–6) at divisor 1 plus a vec4 colour
  (location 7); normals by the matrix's upper 3 × 3 (uniform scale assumed; non-uniform scale is documented as
  approximate). Rationale: GLSL ES 3.00 has no instanced uniform arrays large enough; attributes are standard.
- **R2 Beam strip in view space.** Decision: expand in view space before projection. Rationale: constant width in
  world units, correct at any angle; end-on falls back to an eye-facing square.
- **R3 Falloff.** Decision: exp(−4 r²), r ≤ 1. Rationale: smooth, about 2% at the edge, one formula for beams and
  points. Alternative: smoothstep (rejected: flat core, harsher glow).
- **R4 Ordering.** Decision: stable sort by view-space z, index tie-break, as `DepthMeshPass`. Rationale: one rule
  across the framework.
- **R6 Beam type name (implementation, 2026-11-19).** Decision: the public beam value is `BeamInstance`, not `Beam`.
  Rationale: the ExperiencesCreative regression (`--name experiences`) failed to compile because LightMaze's own public
  `LightMazeCore.Beam` became ambiguous in `MazePresenter.swift` once VisualCoreRendering exported a `Beam`; the name
  `BeamInstance` matches `MeshInstance` and collides with nothing. Alternatives considered: renaming LightMaze's type
  (touches a sealed experience) or qualifying it at the use site (leaves a trap for every later experience).
