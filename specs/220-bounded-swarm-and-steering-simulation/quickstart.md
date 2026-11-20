# Quickstart: R02-F20

1. `swift test --package-path Packages/VisualCore --filter "MagneticFieldTests|NeighbourGridTests|DensityRasterTests|SwarmTests"`
   — grid neighbours equal `NeighbourSearch` for 50 seeded swarms; seeded runs bit-identical and bounded; a charge in a
   uniform field keeps its speed and closes its orbit; pole forces within their bound; density totals equal in-area
   counts; swarms round-trip and continue identically.
2. `swift test --package-path Packages/VisualCore` — every existing test unchanged (including `Steering` and
   `NeighbourSearch` tests).
3. `python3 scripts/check_public_api.py` after `--update` — the new declarations only.
4. Regression: ExperiencesCreative (sim-27.2, Digital Aquarium), VisualCoreRendering (sim-27.2, sim-26.5), the reference
   regression in two chunks and `python3 scripts/test_scripts.py`.
