# Quickstart: R02-G07-03

1. Host: `swift test --package-path Packages/ExperiencesRound02 --filter AmethystEscape` — adapter conformance,
   geometry bounds, CPU reference, renderer purity; each test < 10 s.
2. Simulator: `python3 scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package --destination sim-27.2 --action test --only-testing AmethystEscapeExperienceTests`
   — offscreen frames vs the CPU reference at three tiers, fallback, resize, Reduce Motion.
3. App: `python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27` — the candidate opens.
4. Device (after ImplementationLock-100 only): frame time per tier on D1–D3.
