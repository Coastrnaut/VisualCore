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
- **R8 Observability.** Decision: every refusal carries an `r2-f11.*` reason code and the offending field; the pure
  library has no app id, seed, tick or tier, so the consuming experience adds them when it reports. Rationale: keeps the
  library pure (constitution IV). Alternatives: passing host context into geometry functions.
- **R9 Default options.** Decision: `SDFMarchOptions.standard` holds the validated defaults, because a throwing
  initialiser cannot be a default argument (analyze finding U1).
- **R10 Struct with a node tree (implementation, 2026-11-19).** Decision: `SDFShape` is a struct holding the read-only
  indirect enum `SDFShape.Node`, built only through validating static makers (`sphere(radius:)` …) and
  `validated(_:)`. Rationale: a Swift enum cannot declare a case and a throwing static function of the same name, and a
  private initialiser keeps every description validated. The contract's call sites are unchanged.
- **R11 Measured march and volume behaviour (implementation, 2026-11-19).** (a) The fast mode re-tries ω = 1.6 after
  each fallback step instead of keeping ω = 1 for the rest of the march: from outside, the first relaxed step always
  fails the overlap test (it passes only at incidence cos θ ≤ (2 − ω)/ω = 0.25), so the fixed fallback made fast mode
  exactly as slow as conservative + 1; per-step reset still never skips a surface (a relaxed step is kept only when
  d(t₁) ≥ 0 and r₀ + d(t₁) ≥ s) and saves 26% of steps on 1,000 grazing rays (52,394 vs 70,979). (b) At the default
  tolerance 1e-7 the hit error along a ray is bounded by tolerance · t / cos θ; 4 of 1,000 box rays at cos θ ≈ 0.32
  reached 1.19e-6, so SC-R02F11-002 checks boxes at tolerance 1e-8. (c) An axis-aligned box (0.7, 0.5, 0.3) in ±1 aliases
  with the cell grid (+2.31% at both 32³ and 64³); the same box turned 0.7 rad about (1, 2, 3) gives −0.077% and
  −0.011%; the sphere −0.268% and −0.027%; SC-R02F11-004 names a generic orientation.
