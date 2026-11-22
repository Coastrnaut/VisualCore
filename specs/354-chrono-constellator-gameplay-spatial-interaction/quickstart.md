# Quickstart: R02-G06-04

1. Host: `swift test --package-path Packages/ExperiencesRound02 --filter ChronoConstellator` — picker against an
   independent pick, gesture controller on 500 seeded drags, scrubs, presses and taps, orbit framing, all 100 levels won
   through panel actions.
2. Simulator: `python3 scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package --destination sim-27.2 --action test --only-testing ChronoConstellatorExperienceTests`
   — touches through the experience's pointer entry send the expected actions.
3. Device (after ImplementationLock-100 only): touch feel and latency on D1–D3.
