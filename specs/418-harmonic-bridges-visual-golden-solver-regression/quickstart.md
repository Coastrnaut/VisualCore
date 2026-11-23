# Quickstart: R02-G12-08

1. `swift test --package-path Packages/ExperiencesRound02 --filter HarmonicBridgesRegression` — 100 witnesses replay,
   100 re-plans to the witness's tunings and smaller-choices count, eleven alterations named, 16 golden digests match their pinned
   descriptions.
2. `python3 scripts/harmonic_bridges_regression.py` — host part, then the simulator golden-frame and memory classes; one
   summary line per part.
3. Regenerating the baseline on purpose: `HARMONIC_BRIDGES_WRITE_GOLDEN=1 swift test --package-path
   Packages/ExperiencesRound02 --filter HarmonicBridgesRegressionGoldenTests`, then commit the file with the change.
