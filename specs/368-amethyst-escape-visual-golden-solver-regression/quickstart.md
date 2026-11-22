# Quickstart: R02-G07-08

1. `swift test --package-path Packages/ExperiencesRound02 --filter AmethystEscapeRegression` — 100 witnesses replay,
   100 re-solves to the witness's actions, smallest and depths, twelve alterations named, 16 golden digests match their
   pinned descriptions.
2. `python3 scripts/amethyst_escape_regression.py` — host part, then the simulator golden-frame and memory classes; one
   summary line per part.
3. Regenerating the baseline on purpose: `AMETHYST_ESCAPE_WRITE_GOLDEN=1 swift test --package-path
   Packages/ExperiencesRound02 --filter AmethystEscapeRegressionGoldenTests`, then commit the file with the change.
