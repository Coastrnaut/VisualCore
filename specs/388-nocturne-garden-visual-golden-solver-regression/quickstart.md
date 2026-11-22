# Quickstart: R02-G09-08

1. `swift test --package-path Packages/ExperiencesRound02 --filter NocturneGardenRegression` — 100 witnesses replay,
   100 re-solves to the witness's moves and smallest move count, ten alterations named, 16 golden digests match their
   pinned descriptions.
2. `python3 scripts/nocturne_garden_regression.py` — host part, then the simulator golden-frame and memory classes; one
   summary line per part.
3. Regenerating the baseline on purpose: `NOCTURNE_GARDEN_WRITE_GOLDEN=1 swift test --package-path
   Packages/ExperiencesRound02 --filter NocturneGardenRegressionGoldenTests`, then commit the file with the change.
