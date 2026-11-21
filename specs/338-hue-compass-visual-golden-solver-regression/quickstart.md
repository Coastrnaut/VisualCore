# Quickstart: R02-G04-08

1. `swift test --package-path Packages/ExperiencesRound02 --filter HueCompassRegression` — 100 witnesses replay,
   100 re-solves within 4,657 work, fourteen alterations named, 16 golden digests match their pinned descriptions.
2. `python3 scripts/hue_compass_regression.py` — host part, then the simulator golden-frame and memory classes;
   one summary line per part.
3. Regenerating the baseline on purpose: `HUE_COMPASS_WRITE_GOLDEN=1 swift test --package-path
   Packages/ExperiencesRound02 --filter HueCompassRegressionGoldenTests`, then commit the file with the change.
