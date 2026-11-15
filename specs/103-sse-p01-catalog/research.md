# Research: A14-P01 (feature 103)

## D1 — Data source and license
- **Decision**: NASA NSSDCA Planetary Fact Sheet (public domain, US government work) for the planets; IAU 2015 B3
  nominal solar radius for the Sun; epoch J2000.0; allowed licenses `public-domain`, `CC0-1.0` (clarification Q1).
- **Alternatives**: JPL Horizons ephemerides (rejected: precision beyond the model's scope, online service).

## D2 — Units
- **Decision**: store km, days and degrees; derive AU through the IAU 2012 exact constant 149,597,870.7 km and Julian
  years through 365.25 days; refuse non-finite or negative magnitudes.

## D3 — Citation audit
- **Decision**: one `SourceRecord` per (body, quantity) value; `CitationAudit.problems` refuses missing source, epoch or
  units and unsupported licenses; `CitationAudit.markdown` generates `docs/apps/solar-system-explorer/data-sources.md`,
  compared with the committed file by a test (precedent: Light Maze `LicenseAudit`, `content-licenses.md`).

## D4 — Drawing in this phase
- **Decision**: static visibility-enhanced line-up of lit UV spheres (clarification Q4) through `DepthMeshPass` and a
  fixed `OrbitCamera`; procedural two-band colours per body; "Sizes and spacing not to scale" in the legend and canvas
  description. Orbits, real layout and scale switching come in A14-P02–P03.

## D5 — State and actions
- **Decision**: schema 1 selected index; actions `body.select`, `body.next`, `body.previous`; refusal
  `a14.invalid-choice`; five fixtures (Mercury, Earth, Jupiter, Saturn, Neptune).
