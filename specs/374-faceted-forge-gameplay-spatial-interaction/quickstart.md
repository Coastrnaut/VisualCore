# Quickstart: R02-G08-04

1. Host: `swift test --package-path Packages/ExperiencesRound02 --filter FacetedForge` — picker against an independent
   pick, tilt and step, gesture controller on 500 seeded taps and drags, orbit framing, all 100 levels won through
   panel actions.
2. Simulator: `python3 scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package --destination sim-27.2 --action test --only-testing FacetedForgeExperienceTests`
   — touches through the experience's pointer entry change the choice and send the expected cuts.
3. Device (after ImplementationLock-100 only): touch feel and latency on D1–D3.
