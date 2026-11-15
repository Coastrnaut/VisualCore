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
  60·1.25^−zoomSteps with zoomSteps −1…12 (4.12…75; steps beyond refused), always ≥ 3·displayRadius + 0.5.
- **Rationale**: √ mapping keeps Mercury and Neptune both visible in one overview (2.5 vs 21.9).

## D5 — Fixture tolerances
- **Decision**: Earth longitude at J2000 100.38° ± 0.3°; Earth perihelion/aphelion 0.98329 / 1.01671 AU ± 0.2 %; Mars
  1.381–1.666 AU ± 0.5 %; period return < 1e-6 rad; residual < 1e-10 for e ∈ {0, 0.2056, 0.5, 0.9, 0.95} (clarification Q3).

## As built (2026-11-15)

- **Camera clip range:** near 0.5, far 200 (the farthest point is 75 + 22 scene units away), chosen over
  0.1 … 1,000 for depth precision; the smallest distance, 4.12 at zoom step 12 (not 4.03 as first written), keeps
  every body in front of the near plane (largest display radius 0.8, the Sun: 3 × 0.8 + 0.5 = 2.9).
- **Light:** each planet is lit from the Sun: its renderer's light direction points from the planet toward the origin,
  set every frame; the Sun is drawn at ambient 1.
- **Renderers:** 26 (9 bodies, 9 rings, 8 orbit tubes) are made together in one step (in setup, or in draw when any is
  missing) and released together in teardown, because every mesh renderer shares the registry's cached program
  (A14-P01, As built). Meshes are CPU data built once.
- **Ring:** faces the camera (rotated by its pitch and yaw) and is scaled by max(1, distance / 20) so it stays visible
  from the overview.
- **Date range:** −18,262.5 … 18,627.5 days is 1950-01-01 00:00 to 2051-01-01 00:00 UTC (the end of 2050); the spec
  first said 2050-12-31 00:00 and was corrected; the constant did not change.
- **Fixtures:** the five A14-P01 fixture digests were re-pinned for state schema 2 (the digest text is now
  "a14.solar.v2|" with the schema-2 JSON), and the dated fixture `fixture-earth-2025` (day 9,132) was added.
- **Commits:** the controls (`SolarControls.swift`, part of T-A14-208) were committed with T-A14-207 because they read
  the presenter's mirror, which T-A14-207 changed.
