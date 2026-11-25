# Quickstart: R02-G16-08

1. Host: `swift test --package-path Packages/ExperiencesRound02 --filter StarlitCartoucheRegression` — 100 witness
   replays, 100 re-plans to the witness's legs and counterexample states, thirteen alterations named, 16 golden digests
   match their pinned descriptions; each test < 10 s.
2. `python3 scripts/starlit_cartouche_regression.py` — host part, then the simulator golden-frame and memory classes;
   one summary line per part; non-zero exit on any failure.
3. Simulator alone: `python3 scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package --destination sim-27.2 --action test --only-testing StarlitCartoucheExperienceTests`.
4. Memory bound alone: `TEST_RUNNER_STARLIT_CARTOUCHE_MEMORY_ISOLATED=1` with `--only-testing StarlitCartoucheExperienceTests/StarlitCartoucheRegressionMemoryTests`.
