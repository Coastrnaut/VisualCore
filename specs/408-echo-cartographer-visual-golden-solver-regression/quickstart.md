# Quickstart: R02-G11-08

1. `swift test --package-path Packages/ExperiencesRound02 --filter EchoCartographerRegression` — 100 witnesses replay,
   100 re-plans to the witness's pulses and placements, ten alterations named, 16 golden digests match their pinned
   descriptions.
2. `python3 scripts/echo_cartographer_regression.py` — host part, then the simulator golden-frame and memory classes; one
   summary line per part.
3. Regenerating the baseline on purpose: `ECHO_CARTOGRAPHER_WRITE_GOLDEN=1 swift test --package-path
   Packages/ExperiencesRound02 --filter EchoCartographerRegressionGoldenTests`, then commit the file with the change.
