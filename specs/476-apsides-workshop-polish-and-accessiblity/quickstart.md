# Quickstart: R02-G18-06

1. Host: `swift test --package-path Packages/ExperiencesRound02 --filter ApsidesWorkshop` — feedback plans equal the
   clarified texts and kinds, the lights' fade rules and crossing measure, the recipes' purity and loop lengths; each
   test < 10 s.
2. Simulator: `python3 scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package --destination sim-27.2 --action test --only-testing ApsidesWorkshopExperienceTests`
   — labels and values, adjustable pending orbit, level 1 won through accessibility actions (the pending adjustables,
   Set periapsis, Set size and Play), recorded announcements and haptics, Reduce Flashing and Reduce Motion frames, the
   sound state table.
3. App: `python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27`.
4. Device (after ImplementationLock-100 only): sound, haptics and VoiceOver on D1–D3.
