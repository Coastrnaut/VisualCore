# Quickstart: R02-G01-06

1. Core: `swift test --package-path Packages/ExperiencesRound02 --filter 'AuroraLoomFeedbackPlanTests|AuroraLoomLightsTests|AuroraLoomSoundRecipeTests'`
   — announcement texts and kinds, haptic kinds, fade durations and flash rate, recipe purity; each test < 10 s.
2. Simulator: `python3 scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package --destination sim-27.2 --action test`
   — recorded announcements and haptics through the port; labels and values of every control; the panel at the largest
   text size; the sound rule's state table.
3. Device (after ImplementationLock-100 only): hear the loop, feel the haptics, play level 1 with VoiceOver.
