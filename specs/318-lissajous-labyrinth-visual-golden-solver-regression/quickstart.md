# Quickstart: R02-G02-08

1. `swift test --package-path Packages/ExperiencesRound02 --filter LissajousLabyrinthRegression` — 100 witnesses replay,
   100 re-solves within 14,080 work, twelve alterations named, 16 golden digests match their pinned descriptions.
2. `python3 scripts/lissajous_labyrinth_regression.py` — host part, then the simulator golden-frame and memory classes;
   one summary line per part.
3. Regenerating the baseline on purpose: `LISSAJOUS_LABYRINTH_WRITE_GOLDEN=1 swift test --package-path
   Packages/ExperiencesRound02 --filter LissajousLabyrinthRegressionGoldenTests`, then commit the file with the change.
