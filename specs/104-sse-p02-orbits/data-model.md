# Data model: A14-P02 (feature 104)

| Entity | Fields | Rules |
|---|---|---|
| `KeplerOrbit` (VisualCoreMath) | semiMajorAxis, eccentricity, inclination, ascendingNode, argumentOfPeriapsis, meanAnomalyAtEpoch (rad), meanMotion (rad / time unit) | init nil for non-finite values, e ∉ [0, 1), a ≤ 0, n ≤ 0; `period` = 2π/n |
| `OrbitElements` | bodyID, semiMajorAxisAU, eccentricity, inclinationDeg, meanLongitudeDeg, perihelionLongitudeDeg, ascendingNodeDeg, epoch `J2000.0` | eight planets, ids match the catalog; e in [0, 1); a > 0; every value finite; one source record each (quantity `orbital-elements`) |
| `SimulatedDate` | dayOffset (days since J2000.0) | −18,262.5 … 18,627.5; steps {±1, ±30, ±365}; label `yyyy-MM-dd` UTC |
| `OrbitModel` | elements + catalog periods | `position(bodyID:day:) -> Vec3` (AU, heliocentric ecliptic); `distanceAU` |
| `SolarState` (schema 2) | selection 0…8, dayOffset, yawSteps (Int), pitchDegrees 5…85 (multiples of 5), zoomSteps (Int, distance in 4…80) | migrates schema 1 (dayOffset 0, yaw 0, pitch 35, zoom 0); damaged or newer refused |
