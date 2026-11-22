# Quickstart: R02-G09-04

1. Host: `swift test --package-path Packages/ExperiencesRound02 --filter NocturneGarden` — picker, drag preview,
   gesture controller (500 seeded sequences against an independent pick), the panel win of all 100 levels; each test
   < 10 s.
2. Simulator: `python3 scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package --destination sim-27.2 --action test --only-testing NocturneGardenExperienceTests`
   — touches through the experience's pointer entry plant, move, resize, change the sun and orbit.
3. Device (after ImplementationLock-100 only): touch feel and latency on D1–D3.
