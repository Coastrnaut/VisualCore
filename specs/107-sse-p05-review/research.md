# Research: A14-P05 (feature 107)

## D1 — Event checks
- **Decision**: Mars oppositions as equal heliocentric longitudes; Earth perihelia as least distance; ±3 days;
  public-domain sources (NASA Mars Exploration Program, US Naval Observatory).
- **Rationale**: well-known dates spread over 2000–2025 test the model's longitudes and Earth's orbit shape independently
  of the elements' source. **Alternatives**: comparison with JPL Horizons vectors (online, beyond the model's claim).

## D2 — Review document
- **Decision**: generated Markdown checked by a test, like `data-sources.md`.

## D3 — Truthful labels
- **Decision**: enumerate 216 states; a substring check on "not to scale".

## D4 — Detail levels
- **Decision**: two levels; both built once; the level changes drawing only.

## As built (2026-11-15)

- **State count:** the labelling check covers 9 × 2 × 3 × 2 × 2 = 216 states (the clarification first said 72, an
  arithmetic slip caught when the test counted 108 enhanced states); 108 enhanced descriptions say "not to scale" and
  108 true-relative ones do not, both in the core test and through the real adapter text (`SolarCoreTests`).
- **Event offsets** (model minus published, days): Mars oppositions 0.25, −0.25, 0.49, −0.30; Earth perihelia 0.51 and
  about −1.4 and −1.1 (the Earth–Moon barycentre and the noon comparison account for about a day); all within ±3.
- **Renderers:** 63 (level 0's 37, plus level 1's 9 bodies, 16 orbits and 1 starfield; rings, Saturn's ring and the
  marker shared), made and released together.
- **Probes at level 1** keep level 0's colour expectations and the 400-star background check; the two-level test
  compares the probe lists, not level-1 pixels.
- **Tiers in tests** are forced with `shell.setQualityTier(_:)`, as in Tiny Worlds; the engine refuses tiers outside
  0 ..< 2, so the clamp above 1 is tested on `SceneMeshes.DetailLevel.index(tier:)`.
- **Registration wording** still described the A14-P01 line-up ("sizes and spacing not to scale"); it now names the
  built features, within the 40-character capability limit.
