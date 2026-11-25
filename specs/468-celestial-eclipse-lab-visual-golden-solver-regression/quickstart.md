# Quickstart: R02-G17-08

1. Host: `swift test --package-path Packages/ExperiencesRound02 --filter CelestialEclipseLabRegression` — 100 witness
   replays, 100 re-plans to the witness's phase changes and counterexample settings, twelve alterations named, 16
   golden digests match their pinned descriptions; each test < 10 s.
2. `python3 scripts/celestial_eclipse_lab_regression.py` — host part, then the simulator golden-frame and memory
   classes; one summary line per part; non-zero exit on any failure.
3. Simulator alone: `python3 scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package --destination sim-27.2 --action test --only-testing CelestialEclipseLabExperienceTests`.
4. Memory bound alone: `TEST_RUNNER_CELESTIAL_ECLIPSE_LAB_MEMORY_ISOLATED=1` with `--only-testing CelestialEclipseLabExperienceTests/CelestialEclipseLabRegressionMemoryTests`.
