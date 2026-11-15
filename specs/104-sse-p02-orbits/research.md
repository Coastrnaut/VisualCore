# Research: A14-P02 (feature 104)

## D1 — Kepler solver
- **Decision**: Newton's method on E − e sin E = M with M normalised to (−π, π]; start E₀ = M for e < 0.8, else π;
  at most 32 steps; stop when |ΔE| < 1e-12 (clarification Q1). Position in the orbital plane x′ = a(cos E − e),
  y′ = a√(1−e²) sin E, rotated by ω, i, Ω (z-x-z) into the reference frame.
- **Rationale**: Newton converges quadratically for e < 0.95 from these starts; π avoids the overshoot near M ≈ 0 at
  high e (Danby). Bounded steps keep the solution finite.
- **Alternatives**: fixed-point iteration (slow at high e); series expansion (inaccurate above e ≈ 0.66).

## D2 — Element source and license
- **Decision**: Standish, "Keplerian Elements for Approximate Positions of the Major Planets", JPL SSD, Table 1
  (J2000.0, valid 1800–2050), recorded as `public-domain` numerical facts with that basis stated in the record. ω = ϖ − Ω;
  M₀ = L − ϖ; n = 2π / catalog sidereal period (rad/day).
- **Alternatives**: JPL Horizons vectors (precision beyond scope, online); Table 2 with secular rates (rejected to keep
  periods consistent with the catalog).

## D3 — Date model
- **Decision**: `dayOffset` (Double days since J2000.0 TT≈UTC; difference below the model's accuracy, stated) in
  −18,262.5 … 18,627.5; steps ±1, ±30, ±365; labels as UTC `yyyy-MM-dd` computed with a Gregorian UTC calendar.
- **Rationale**: integer-valued step sums keep forward-then-back exact in Double.

## D4 — Display mapping and camera
- **Decision**: heliocentric ecliptic (x, y, z) → scene (x, z, −y)·(4√r / r); orbit lines 128 samples, `tube` radius
  0.04, 6 sides, closed; camera target the focused body's scene position, yaw 15° steps, pitch 5…85°, distance
  60·1.25^−zoomSteps clamped to max(4, 3·displayRadius + 0.5)…80.
- **Rationale**: √ mapping keeps Mercury and Neptune both visible in one overview (2.5 vs 21.9).

## D5 — Fixture tolerances
- **Decision**: Earth longitude at J2000 100.38° ± 0.3°; Earth perihelion/aphelion 0.98329 / 1.01671 AU ± 0.2 %; Mars
  1.381–1.666 AU ± 0.5 %; period return < 1e-6 rad; residual < 1e-10 for e ∈ {0, 0.2056, 0.5, 0.9, 0.95} (clarification Q3).
