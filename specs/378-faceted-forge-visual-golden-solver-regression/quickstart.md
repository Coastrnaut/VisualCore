# Quickstart: R02-G08-08

1. `swift test --package-path Packages/ExperiencesRound02 --filter FacetedForgeRegression` — 100 witnesses replay,
   100 re-solves to the witness's cuts and smallest cut count, ten alterations named, 16 golden digests match their
   pinned descriptions.
2. `python3 scripts/faceted_forge_regression.py` — host part, then the simulator golden-frame and memory classes; one
   summary line per part.
3. Regenerating the baseline on purpose: `FACETED_FORGE_WRITE_GOLDEN=1 swift test --package-path
   Packages/ExperiencesRound02 --filter FacetedForgeRegressionGoldenTests`, then commit the file with the change.
