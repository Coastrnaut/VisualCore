# Quickstart: R02-G09-05

1. Host: `swift test --package-path Packages/ExperiencesRound02 --filter NocturneGarden` — hints win all 100 levels from
   the start and 200 seeded states, failure texts for 500 seeded failures, progress, stars, daily and practice, schema
   migration; each test < 10 s.
2. Simulator: `python3 scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package --destination sim-27.2 --action test --only-testing NocturneGardenExperienceTests`
   — the tutorial, hints and failure text in the panel, level selection and modes.
