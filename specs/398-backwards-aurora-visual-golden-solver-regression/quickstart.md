# Quickstart: R02-G10-08

1. `swift test --package-path Packages/ExperiencesRound02 --filter BackwardsAuroraRegression` — 100 witnesses replay,
   100 re-solves to the witness's reversals and smallest reversal count, ten alterations named, 16 golden digests match their
   pinned descriptions.
2. `python3 scripts/backwards_aurora_regression.py` — host part, then the simulator golden-frame and memory classes; one
   summary line per part.
3. Regenerating the baseline on purpose: `BACKWARDS_AURORA_WRITE_GOLDEN=1 swift test --package-path
   Packages/ExperiencesRound02 --filter BackwardsAuroraRegressionGoldenTests`, then commit the file with the change.
