# Contract: review, model statement and levels (feature 107)

Core: `EventFixture.bundled` (7), `EventChecks.evaluate(_:) -> EventResult`, `ScientificReview.modelStatement`,
`ScientificReview.markdown()`. Experience: `SolarCore.qualityTiers == 2`; the presenter draws `tier` 0 or 1 (values
above clamp to 1); controls show "About this model" with the statement as value. Tests: EventChecksTests (each within
±3 days), ScientificReviewTests (committed file equals generated; `UPDATE_SCIENTIFIC_REVIEW=1` rewrites),
TruthfulLabelTests (216 states), SolarQualityTests (profile names and count, both levels draw, same centres and
digest, level 1 uses fewer vertices).
