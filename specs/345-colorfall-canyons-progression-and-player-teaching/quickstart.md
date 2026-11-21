# Quickstart: R02-G05-05

1. Host: `swift test --package-path Packages/ExperiencesRound02 --filter ColorfallCanyons` — hints win every certified
   level from the start and every seeded state that can still win; failure texts name the true basin, colour and
   amounts; progress, stars, daily and practice rules; schema 1 → 2 migration.
2. Simulator: `python3 scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package --destination sim-27.2 --action test`
   — the presenter shows the tutorial, hints and failure text; the panel's Hint and mode controls work.
3. Device: none in this feature.
