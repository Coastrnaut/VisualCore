# Quickstart: R02-F21

1. `swift test --package-path Packages/VisualCore --filter "NutrientFieldTests|NutrientDiffusionTests|GrowthNetworkTests|NutrientCodingTests"`
   — 20 seeded fields keep every channel exactly balanced and non-negative over 300 frames; a spot's peak never rises;
   sources, sinks and decay settle; viability bands; two seeded growth runs identical within their limits and routable;
   fields round-trip and continue identically.
2. `swift test --package-path Packages/VisualCore` — every existing test unchanged.
3. `python3 scripts/check_public_api.py` after `--update` — the new declarations only.
4. Regression: VisualCoreRendering (sim-27.2, sim-26.5), ExperiencesCreative (sim-27.2), the reference regression in two
   chunks and `python3 scripts/test_scripts.py` (alone).
