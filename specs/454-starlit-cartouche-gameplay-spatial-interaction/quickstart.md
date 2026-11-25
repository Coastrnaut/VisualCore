# Quickstart: R02-G16-04

1. Host: `swift test --package-path Packages/ExperiencesRound02 --filter StarlitCartouche` — picker and slider against
   an independent computation, 500 seeded gestures, orbit bounds and fit, the launch preview, all 100 levels won
   through the panel; each test < 10 s.
2. Simulator: `python3 scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package --destination sim-27.2 --action test --only-testing StarlitCartoucheExperienceTests`
   — touches through the pointer entry choose, fly by double tap and ship drag, set the wait on the slider, orbit and
   reset.
3. App: `python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27`.
4. Device (after ImplementationLock-100 only): touch feel and latency on D1–D3.
