# Quickstart: R02-G14-04

1. Host: `swift test --package-path Packages/ExperiencesRound02 --filter MoonlitMechanism` — picker against an
   independent pick, 500 seeded gestures, orbit bounds and fit, all 100 levels won through the panel; each test < 10 s.
2. Simulator: `python3 scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package --destination sim-27.2 --action test --only-testing MoonlitMechanismExperienceTests`
   — touches through the pointer entry turn, step the lamp, choose, re-seat, show a key frame, run, orbit and reset.
3. App: `python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27`.
4. Device (after ImplementationLock-100 only): touch feel and latency on D1–D3.
