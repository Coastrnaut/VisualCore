# Quickstart: R02-G02-06

1. `swift test --package-path Packages/ExperiencesRound02 --filter 'LissajousLabyrinthFeedbackPlanTests|LissajousLabyrinthLightsTests|LissajousLabyrinthSoundRecipeTests'`
   — exact texts and haptics for scripted sequences; at most 3 half-range crossings per second and fades ≥ 0.4 s under
   Reduce Flashing for a scripted win and adversarial flicker; recipes equal for equal dials and stage.
2. Simulator: `python3 scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme
   ExperiencesRound02-Package --destination sim-27.2 --action test` — recorded announcements and haptics through the
   presenter; level 1 won through the steppers' accessibility operations and Apply; the sound state table; labels and
   values of every control; the panel at the largest accessibility text size.
3. App unit tests, regression and `python3 scripts/test_scripts.py` (alone).
