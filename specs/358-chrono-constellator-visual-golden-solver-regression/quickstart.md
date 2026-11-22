# Quickstart: R02-G06-08

1. `swift test --package-path Packages/ExperiencesRound02 --filter ChronoConstellatorRegression` — 100 witnesses replay,
   100 re-solves to the witness's phase changes and counts, twelve alterations named, 16 golden digests match their
   pinned descriptions.
2. `python3 scripts/chrono_constellator_regression.py` — host part, then the simulator golden-frame and memory classes;
   one summary line per part.
3. Regenerating the baseline on purpose: `CHRONO_CONSTELLATOR_WRITE_GOLDEN=1 swift test --package-path
   Packages/ExperiencesRound02 --filter ChronoConstellatorRegressionGoldenTests`, then commit the file with the change.
