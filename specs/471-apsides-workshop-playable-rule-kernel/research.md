# Research: R02-G18-01

- **R1 Ticks, not seconds.** Decision: the kernel counts whole ticks of one revolution (equal steps of mean anomaly);
  the catalog's 0.008333 s timestep is the presentation clock of later features. Rationale: an exact clock; no floating
  point decides a rule.
- **R2 Integer fixed point for Kepler's equation.** Decision: anomalies, sines, cosines and the ellipse factor
  √(1 − e²) are `Int64` values with 2^30 as one, computed by integer range reduction, an integer polynomial for sine and
  cosine and an integer square root; Newton (at most 8 steps) with a bisection fallback (48 steps on [M − e, M + e]).
  Rationale: the source's law kept exactly as written ("bounded Newton with bisection fallback") while every device gets
  bit-identical positions, so replays, fingerprints and certificates agree everywhere. Alternatives: `Double` with
  tolerance bands (the source allows it, but results could differ across architectures at a boundary and a level could
  win on one device and fail on another); precomputed tables (more data, same arithmetic).
- **R3 Discrete orbit steps.** Decision: size 8 … 48 lattice units, eccentricity in twentieths 0 … 15, direction in
  15° steps 0 … 23. Rationale: the solver's "bounded numeric search over eccentricity/orientation samples" becomes an
  exhaustive search over at most 41 × 16 × 24 = 15,744 orbits; the steps are coarse enough to feel like a knob.
- **R4 Octant sectors.** Decision: 8 sectors of 45°, decided by signs and |x| against |y|, the boundary ray belonging
  to the sector it begins. Rationale: exact integer classification without trigonometry; apsis sectors follow from the
  direction step exactly (⌊d/3⌋), because 15° divides 45°.
- **R5 Triangle quadrature.** Decision: one triangle star → P(t) → P(t + 1) per tick, its doubled area the integer cross
  product, counted for the sector of P(t); shares in tenths of a percent rounded down. Rationale: "area swept via
  quadrature" made exact; by Kepler's second law each tick sweeps nearly the same area, so the share reads as time
  spent.
- **R6 Strict segment contact.** Decision: contact when the planet centre's distance to a tick segment is strictly below
  its radius, decided with integer dot and cross products. Rationale: grazing is safe, as touching discs are in feature
  461; the chord between ticks is the drawn path.
- **R7 Event ticks for the order.** Decision: a sweep's event tick is the first tick in its sector, periapsis 0,
  apoapsis T/2; targets must have non-decreasing event ticks. Rationale: "satisfied in order" and "a sequence of
  prescribed sky sectors" become the orbiter's visiting order from periapsis.
- **R8 Play as the commitment.** Decision: tunings cost actions and keep the level playing; `play` costs nothing and
  ends it; the predicted outcome is reported after every action. Rationale: the orbit decides everything, as the phases
  do in feature 461.
- **R9 Fingerprints as the signed snapshot.** Decision: the play fingerprint (SHA-256 of schema, level fingerprint,
  orbit, actions spent, stage, failure) and records with previous and next fingerprints, as feature 461.
