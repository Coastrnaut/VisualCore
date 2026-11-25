# Quickstart: R02-G18-04

1. Host: `swift test --package-path Packages/ExperiencesRound02 --filter ApsidesWorkshop` — picker, sky-plane steps and
   crank tick against an independent computation, 500 seeded gestures, orbit bounds and fit, the tuning preview, all 100
   levels won through the panel; each test < 10 s.
2. Simulator: `python3 scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme
   ExperiencesRound02-Package --destination sim-27.2 --action test --only-testing ApsidesWorkshopExperienceTests` —
   touches through the pointer entry tune the knob and the size by dragging, turn the crank, orbit and reset.
3. App: `python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27`.
4. Device (after ImplementationLock-100 only): touch feel and latency on D1–D3.
