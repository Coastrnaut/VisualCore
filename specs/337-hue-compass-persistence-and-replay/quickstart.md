# Quickstart: R02-G04-07

1. `swift test --package-path Packages/ExperiencesRound02 --filter 'HueCompassReconciliationTests|HueCompassPersistenceTests|HueCompassExperienceCoreTests'`
   — 500 round trips with equal digests; schema 1 and 2 payloads migrate with progress kept; honest results survive and
   edited ones are dropped and counted; every certified trace replays to a win; replay never changes progress.
2. Simulator: `python3 scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme
   ExperiencesRound02-Package --destination sim-27.2 --action test --only-testing HueCompassExperienceTests` — replay
   start, step and stop through the panel's port; the dropped announcement once.
3. App unit tests, regression and `python3 scripts/test_scripts.py` (alone).
