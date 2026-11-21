# Quickstart: R02-G05-06

1. Host: `swift test --package-path Packages/ExperiencesRound02 --filter 'ColorfallCanyonsFeedbackPlan|ColorfallCanyonsLights|ColorfallCanyonsSoundRecipe|ColorfallCanyonsSceneGeometry'`
   — exact announcement and haptic plans, eased lights with the flash-rate measure, recipes, geometry with lights.
2. Simulator: `python3 scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package --destination sim-27.2 --action test --only-testing ColorfallCanyonsExperienceTests`
   — labels and values, announcements and haptics through recording sinks, Reduce Flashing fades, Reduce Motion stills,
   the sound state table, the panel at the largest text size.
3. Device (after ImplementationLock-100 only): sound, haptics and VoiceOver on D1–D3.
