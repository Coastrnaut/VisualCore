# Quickstart: R02-F17

1. `swift test --package-path Packages/VisualCore --filter "Heightfield"` — expect all pass: ledgers balance exactly after
   every step of 50 seeded terrains × 500 steps; a 32 × 32 basin settles within 0.05 height units in 4,000 sub-steps;
   extreme inputs stay finite and clamped; dye and rock conserved; a slope erodes at its top and deposits at its foot;
   stored states round-trip byte for byte and continue bit-identically.
2. `swift test --package-path Packages/VisualCore` — every existing test unchanged and passing.
3. `python3 scripts/check_public_api.py` after `--update` — the new declarations only.
4. Regression: ExperiencesCreative (sim-27.2), VisualCoreRendering (sim-27.2, sim-26.5), the reference regression in two
   chunks and `python3 scripts/test_scripts.py`.
