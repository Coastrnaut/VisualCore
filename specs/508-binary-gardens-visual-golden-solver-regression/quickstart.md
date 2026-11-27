# Quickstart: R02-G21-08

0. Prerequisites: `python3 scripts/migration_ledger.py status` shows R02-G21-04, 05, 06 and 07 recorded. Only then is
   the golden manifest written, once, and checked again without the switch:

   ```bash
   BINARY_GARDENS_WRITE_GOLDEN=1 swift test --package-path Packages/ExperiencesRound02 \
     --filter BinaryGardensRegressionGoldenTests
   swift test --package-path Packages/ExperiencesRound02 --filter BinaryGardensRegressionGoldenTests
   ```

1. Host: `swift test --package-path Packages/ExperiencesRound02 --filter BinaryGardensRegression` — 100 level checks,
   100 witness replays with their prefixes, 100 re-plans to the witness's actions, counterexample arrangements and
   nearest misses, thirteen alterations named on levels 1, 41 and 81, 17 golden digests match their pinned
   descriptions; each test < 10 s.
2. `python3 scripts/binary_gardens_regression.py` — host part, then the simulator golden-frame and memory classes;
   one summary line per part and an overall line; non-zero exit on any failure (`--dry-run`, `--skip-simulator`).
3. Simulator alone:

   ```bash
   python3 scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 \
     --scheme ExperiencesRound02-Package --destination sim-27.2 --action test \
     --only-testing BinaryGardensExperienceTests/BinaryGardensRegressionGoldenFrameTests
   ```

4. Memory bound alone: the same command with `TEST_RUNNER_BINARY_GARDENS_MEMORY_ISOLATED=1` in the environment and
   `--only-testing BinaryGardensExperienceTests/BinaryGardensRegressionMemoryTests`.
5. Script tests, alone (no run-check or tick meanwhile): `python3 scripts/test_scripts.py`.
