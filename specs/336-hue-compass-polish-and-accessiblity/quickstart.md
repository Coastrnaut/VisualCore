# Quickstart: R02-G04-06

1. `swift test --package-path Packages/ExperiencesRound02 --filter 'HueCompassFeedbackPlanTests|HueCompassLightsTests|HueCompassSoundRecipeTests'`
   — exact texts and haptics for scripted sequences; at most 3 half-range crossings per second and fades ≥ 0.4 s under
   Reduce Flashing for a scripted win and adversarial flicker; recipes equal for equal clue and stage.
2. Simulator: `python3 scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme
   ExperiencesRound02-Package --destination sim-27.2 --action test --only-testing HueCompassExperienceTests` — recorded
   announcements and haptics through the presenter; level 1 won through the turn buttons, Probe, the band stepper's
   accessibility operations and Select; the sound state table; labels and values of every control; the panel at the
   largest accessibility text size.
3. App unit tests, regression and `python3 scripts/test_scripts.py` (alone).
