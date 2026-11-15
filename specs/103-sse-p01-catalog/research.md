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

## As built (2026-11-15)

- **Outcome:** `SolarCore.outcome` is `viewing-<body id>` (for example `viewing-earth`); the scenario-manifest
  validator requires an outcome for the completion scenario (`completion: no outcome expected` otherwise), so the
  completion scenario selects Earth and expects `viewing-earth`, and each fixture expects its body (precedent: Tiny
  Worlds' `world-<preset>`). Clarification Q5 named no outcome.
- **Ring renderers:** all `MeshRenderer`s share one cached shader program in the host's `ResourceRegistry`, and
  `MeshRenderer.release()` releases that program for every renderer using it. The first iOS 27 run remade the ring
  renderer per selection, which released the program under the nine body renderers: they drew with the ring's stale
  uniforms at the selected body. The presenter now makes the nine ring renderers once with the bodies and the
  selection only picks one; no renderer is released while others are in use (released together in `teardown`). The
  framework behaviour is recorded for a later VisualCore fix (reference counting of cached programs) and does not
  change this phase's scope.
- **Test canvas:** the render tests use a 240 × 160 point view (720 × 480 pixels on the simulator) so Mercury spans
  several pixels.
