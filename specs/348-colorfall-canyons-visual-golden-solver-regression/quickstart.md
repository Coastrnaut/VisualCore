# Quickstart: R02-G05-08

1. `swift test --package-path Packages/ExperiencesRound02 --filter ColorfallCanyonsRegression` — 100 witnesses replay,
   100 re-solves to the witness's edit set, twelve alterations named, 16 golden digests match their pinned descriptions.
2. `python3 scripts/colorfall_canyons_regression.py` — host part, then the simulator golden-frame and memory classes;
   one summary line per part.
3. Regenerating the baseline on purpose: `COLORFALL_CANYONS_WRITE_GOLDEN=1 swift test --package-path
   Packages/ExperiencesRound02 --filter ColorfallCanyonsRegressionGoldenTests`, then commit the file with the change.
