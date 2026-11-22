# Quickstart: R02-G06-05

1. Host: `swift test --package-path Packages/ExperiencesRound02 --filter ChronoConstellator` — hints win all 100 levels and
   200 seeded states, failure texts on 500 seeded failures, progress, stars, daily and practice rules, schema 2 and its
   migration, the regenerated scenario manifest.
2. Simulator: `python3 scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package --destination sim-27.2 --action test --only-testing ChronoConstellatorExperienceTests`
   — the panel shows the tutorial, hints and failure text; mode and level controls reach the adapter.
