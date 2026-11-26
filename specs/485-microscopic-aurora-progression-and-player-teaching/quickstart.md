# Quickstart: R02-G19-05

1. Host: `swift test --package-path Packages/ExperiencesRound02 --filter MicroscopicAurora` — hints win all 100 levels
   from the start, 200 seeded states give accepted hints, 500 seeded failures are explained truly, progress, stars,
   daily and practice rules, the schema 1 → 2 migration; each test < 10 s.
2. Simulator: `python3 scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package --destination sim-27.2 --action test --only-testing MicroscopicAuroraExperienceTests`
   — the tutorial, hints, failure text, stars and modes in the panel.
3. App: `python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27`.
