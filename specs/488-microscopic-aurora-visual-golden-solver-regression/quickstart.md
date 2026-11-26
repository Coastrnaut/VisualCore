# Quickstart: R02-G19-08

1. Host: `swift test --package-path Packages/ExperiencesRound02 --filter MicroscopicAuroraRegression` — 100 witness
   replays, 100 re-plans to the witness's placements and counterexample sets, twelve alterations named, 16
   golden digests match their pinned descriptions; each test < 10 s.
2. `python3 scripts/microscopic_aurora_regression.py` — host part, then the simulator golden-frame and memory
   classes; one summary line per part; non-zero exit on any failure.
3. Simulator alone: `python3 scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package --destination sim-27.2 --action test --only-testing MicroscopicAuroraExperienceTests`.
4. Memory bound alone: `TEST_RUNNER_MICROSCOPIC_AURORA_MEMORY_ISOLATED=1` with `--only-testing MicroscopicAuroraExperienceTests/MicroscopicAuroraRegressionMemoryTests`.
