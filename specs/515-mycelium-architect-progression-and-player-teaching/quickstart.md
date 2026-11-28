# Quickstart: R02-G22-05

1. Host: `swift test --package-path Packages/ExperiencesRound02 --filter MyceliumArchitect` — exact hints win all 100
   levels from the start within the certified count, 200 seeded states give accepted hints, 500 seeded failures are
   explained truly, the tutorial steps, progress, stars, daily (100 consecutive days visit every level) and practice
   rules, the new reason codes and the schema 1 → 2 migration; each test < 10 s.
2. Simulator: `python3 scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package --destination sim-27.2 --action test --only-testing MyceliumArchitectExperienceTests`
   — the tutorial, hints, failure text, stars and modes in the panel.
3. App: `python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27`.
