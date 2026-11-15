# Data model: A14-P05 (feature 107)

| Entity | Fields | Rules |
|---|---|---|
| `EventFixture` | name, kind (`opposition`, `perihelion`), bodyID, published date (UTC, yyyy-MM-dd), toleranceDays 3, source | 7 bundled; dates inside the model range |
| `EventResult` | fixture, model day (days since J2000.0), offset days, passed | offset = model − published; passed when |offset| ≤ 3 |
| `ScientificReview` | modelStatement, markdown() | deterministic, LF, ends with a newline; written to `docs/apps/solar-system-explorer/scientific-review.md` |
| Detail level | 0: spheres 48 × 24, 400 stars, 128 orbit samples; 1: 24 × 12, 200, 64 | `SolarCore.qualityTiers` 2; registration `["level-0", "level-1"]` |
