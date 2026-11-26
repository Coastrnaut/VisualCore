# Quickstart: R02-G18-08

1. Host: `swift test --package-path Packages/ExperiencesRound02 --filter ApsidesWorkshopRegression` — 100 witness
   replays, 100 re-plans to the witness's tunings and counterexample orbits, twelve alterations named, 16
   golden digests match their pinned descriptions; each test < 10 s.
2. `python3 scripts/apsides_workshop_regression.py` — host part, then the simulator golden-frame and memory
   classes; one summary line per part; non-zero exit on any failure.
3. Simulator alone: `python3 scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package --destination sim-27.2 --action test --only-testing ApsidesWorkshopExperienceTests`.
4. Memory bound alone: `TEST_RUNNER_APSIDES_WORKSHOP_MEMORY_ISOLATED=1` with `--only-testing ApsidesWorkshopExperienceTests/ApsidesWorkshopRegressionMemoryTests`.
