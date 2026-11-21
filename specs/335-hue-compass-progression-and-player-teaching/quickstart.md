# Quickstart: R02-G04-05

1. Host: `swift test --package-path Packages/ExperiencesRound02 --filter HueCompass` — hints win all 100 levels from the
   start, hints on 2,000 seeded states, failure texts, progress, stars, daily and practice rules, schema 1 → 2 migration.
2. Simulator: `python3 scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package --destination sim-27.2 --action test --only-testing HueCompassExperienceTests`
   — tutorial, hint and failure text shown in the panel.
