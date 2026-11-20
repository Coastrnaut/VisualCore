# Data model: R02-F15

| Entity | Fields | Rules |
|---|---|---|
| ConicOrbit | periapsisDistance q, eccentricity e, inclination, ascendingNode, argumentOfPeriapsis, timeOfPeriapsis tₚ, gravitationalParameter μ | all finite; q > 0, e ≥ 0, μ > 0; kind parabolic when abs(e − 1) ≤ 1e-9; stored JSON schema 1, sorted keys |
| ConicKind | elliptic, parabolic, hyperbolic | from e |
| OrbitState | position, velocity (Vec3), trueAnomaly, radius | finite for finite t; non-finite t treated as tₚ |
| PhaseStepper | startTime t₀, step Δt, tick k | Δt finite > 0; 0 ≤ k ≤ 1,000,000,000 |
| Passage | kind (periapsis, apoapsis), index j, time | listed in [tₐ, t_b), time order, ≤ 1,000,000 |
| EclipseBody | center (Vec3), radius | radius finite > 0 |
| EclipseVerdict | sourceAngularRadius, occluderAngularRadius, separation, coveredFraction, eclipseClass | fraction in [0, 1]; hidden reports 1 |
| EclipseClass | none, partial, annular, total, hidden | thresholds of Clarifications Q4 |
| OrbitError | invalidElements, invalidStep, tickLimit, invalidDisk, observerInside, spanLimit, newerSchema, malformed | `reasonCode` `r2-f15.*` |
