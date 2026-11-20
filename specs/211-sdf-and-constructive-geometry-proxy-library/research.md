# Research: R02-F11

- **R1 Home and names.** Decision: VisualCoreScenes, `SDF` prefix. Rationale: R02-F05/F08 precedent; `Primitive` taken;
  the R02-F09 `Beam` collision. Alternatives: a new VisualCoreGeometry module (moves nothing that exists, adds a
  dependency edge for one feature).
- **R2 Distance formulas.** Decision: exact closed forms for plane (n·p − h), sphere, box, rounded box, capsule (segment
  distance − r) and torus; union = min, intersection = max, subtraction = max(a, −b); smooth union = polynomial smooth
  min h = clamp(0.5 + 0.5(b − a)/k, 0, 1), mix(b, a, h) − k h (1 − h), which never exceeds min(a, b). Source: Inigo
  Quilez, "3D distance functions" and "smooth minimum" (MIT). Alternatives: exponential smooth min (costly, no k = 0).
- **R3 Normal.** Decision: central-difference gradient with h = 1e-6 · max(1, |p|), normalised; falls back to (0, 1, 0)
  when the gradient has zero length. Alternatives: tetrahedral 4-tap (cheaper on GPU; used in the shader).
- **R4 March.** Decision: sphere tracing (Hart 1996) with ω = 1 (conservative) or ω = 1.6 with the overlap fallback of
  Keinert, Schäfer, Korndörfer, Ganse, Stamminger, "Enhanced Sphere Tracing" (2014). Hit when d < 1e-7·max(1, t).
  Rationale: provably no skip for a distance bound. Alternatives: fixed-step march (slow, can skip).
- **R5 Volume.** Decision: cell-centre sampling of an n³ grid, n ≤ 256; FNV-1a 64 over packed bits. Rationale:
  deterministic; midpoint rule error O(h) at surfaces, so 32³→64³ at least halves it. Alternatives: Monte Carlo (noisy).
- **R6 Stored form.** Decision: JSON with `schema` 1 and a `kind`-tagged tree; decode validates through the same
  initialisers. Rationale: matches the project's snapshot conventions. Alternatives: binary (unreadable in fixtures).
- **R7 Shader.** Decision: the generator emits `float vc_sdfShape(vec3 p)` from the tree using `vc/sdf.glsl` and the new
  `vc/sdfshape.glsl`; transforms become an inverse rotation matrix literal, a translation and a scale. Parity draws a
  slice (distance image, encoding 0.5 + d/8) and a marched view (hit mask). Alternatives: a uniform-buffer interpreter
  (loops over nodes; slower, more GLSL ES risk).
