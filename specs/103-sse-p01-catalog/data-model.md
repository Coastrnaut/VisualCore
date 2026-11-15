# Data model: A14-P01 (feature 103)

| Entity | Fields | Rules |
|---|---|---|
| `Units` | `kmPerAU = 149_597_870.7`, `daysPerJulianYear = 365.25`; `au(fromKm:)`, `km(fromAU:)`, `years(fromDays:)`, `days(fromYears:)` | non-finite or negative → nil |
| `BodyKind` | star, planet | — |
| `CelestialBody` | id (`sun`, `mercury` … `neptune`), name, kind, meanRadiusKm, semiMajorAxisKm?, siderealPeriodDays?, axialTiltDegrees | the Sun has no axis or period; planets have both, positive and finite; ordered by increasing axis |
| `SourceRecord` | bodyID, quantity (`mean-radius`, `semi-major-axis`, `sidereal-period`, `axial-tilt`), source title, publisher, link text, epoch, units, license | every stored value has exactly one record; license ∈ {`public-domain`, `CC0-1.0`} |
| `BodyCatalog` (document schema 1) | bodies, sources | sorted-key JSON; damaged, newer or out-of-range documents refused as a whole; ranges: 1…16 bodies, ids unique, radius 1…1,000,000 km, axis 1e6…1e10 km, period 1…1,000,000 days, tilt 0…180°, every value finite |
| `FactCard` | body, facts [(label, value text, unit, source title)] | every fact has a unit and a source |
| `SolarState` (schema 1) | selected body index 0…8 | damaged or newer refused |
