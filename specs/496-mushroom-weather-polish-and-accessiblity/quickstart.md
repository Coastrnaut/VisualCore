# Quickstart: R02-G20-06

1. Host: `swift test --package-path Packages/ExperiencesRound02 --filter MushroomWeather` — feedback plans equal the
   clarified texts and kinds, the lights' fade rules and crossing measure, the recipes' purity and loop lengths; each
   test < 10 s.
2. Simulator: `python3 scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package --destination sim-27.2 --action test --only-testing MushroomWeatherExperienceTests`
   — labels and values, adjustable slot, site and moonlight, vent toggles, level 1 won through accessibility actions
   (the adjustables, the vent toggles, Place and Run), recorded announcements and haptics, Reduce Flashing and Reduce
   Motion frames, the sound state table.
3. App: `python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27`.
4. Device (after ImplementationLock-100 only): sound, haptics and VoiceOver on D1–D3.
