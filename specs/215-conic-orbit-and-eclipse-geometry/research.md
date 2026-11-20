# Research: R02-F15

- **R1 Reuse the elliptic solver.** Decision: `KeplerSolver.eccentricAnomaly` calls `KeplerOrbit.eccentricAnomaly`, then
  polishes with at most 8 Newton steps while |E − e·sin E − M| > 1e-12. Rationale: Section 13 — no duplicate solver;
  the polish guarantees the residual SC even near e → 1. Alternatives: a second elliptic solver (duplicate).
- **R2 Hyperbolic start.** Decision: H₀ = sign(M)·ln(2|M|/e + 1.8), Newton ≤ 64 steps. Rationale: standard start that
  is close for large |M| (H ≈ ln(2M/e)) and moderate near 0; Newton on the convex e·sinh H − H converges monotonically.
- **R3 Parabola by Barker's equation.** Decision: closed form (cube roots) with W = (3/2)·n·(t − tₚ), n = √(μ/(2q³)),
  used for |e − 1| ≤ 1e-9. Rationale: exact and branch-free; Newton degenerates there.
- **R4 State from true anomaly.** Decision: p = q(1 + e); r = p/(1 + e·cos ν); perifocal position r(cos ν, sin ν) and
  velocity √(μ/p)(−sin ν, e + cos ν), rotated by ω, i, Ω exactly as `KeplerOrbit`. Rationale: one formula for all
  conics; energy −μ/(2a) (0 for the parabola) and angular momentum √(μp) are invariants for the tests.
- **R5 Drift-free stepping.** Decision: time(k) = t₀ + Double(k)·Δt, never summed. Rationale: identical for stepping
  and jumping; error does not grow with k.
- **R6 Passages exactly once.** Decision: candidate times tₚ + Double(j)·P (apoapsis j + ½) are computed by the same
  expression for every span and kept when tₐ ≤ t < t_b. Rationale: adjacent half-open spans partition time, so a fixed
  computed value falls in exactly one.
- **R7 Lens area.** Decision: A = r₁²·acos(c₁) + r₂²·acos(c₂) − ½√((−d+r₁+r₂)(d+r₁−r₂)(d−r₁+r₂)(d+r₁+r₂)) with
  cosines clamped to [−1, 1]; 0 when d ≥ r₁ + r₂; π·min(r)² when d ≤ |r₁ − r₂|. Test oracle: integration of the
  chord length over the smaller disk with x = r·cos φ (smooth), 1,024 intervals (Simpson on smooth pieces; kept light beside the timed R02-F05 test).
- **R8 Sky projection.** Decision: angular radius asin(R/d); separation atan2(|a × b|, a · b) (accurate at small
  angles); overlap of disks with those radii at that distance; the horizon dip acos(R_g/h) for the ground sphere.
  Rationale: the disk model the consumers draw; standard small-angle sky approximation.
