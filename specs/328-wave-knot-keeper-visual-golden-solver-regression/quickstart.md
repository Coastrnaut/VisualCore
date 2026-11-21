# Quickstart: R02-G03-08

1. `swift test --package-path Packages/ExperiencesRound02 --filter WaveKnotKeeperRegression` — 100 witnesses replay,
   100 re-solves within 3,661 work, thirteen alterations named, 16 golden digests match their pinned descriptions.
2. `python3 scripts/wave_knot_keeper_regression.py` — host part, then the simulator golden-frame and memory classes;
   one summary line per part.
3. Regenerating the baseline on purpose: `WAVE_KNOT_KEEPER_WRITE_GOLDEN=1 swift test --package-path
   Packages/ExperiencesRound02 --filter WaveKnotKeeperRegressionGoldenTests`, then commit the file with the change.
