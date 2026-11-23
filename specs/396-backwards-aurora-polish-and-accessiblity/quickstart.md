# Quickstart: R02-G10-06

1. Host: `swift test --package-path Packages/ExperiencesRound02 --filter BackwardsAurora` — feedback plans for scripted
   sequences, light fades and the flicker measure, the sound recipe; each test < 10 s.
2. Simulator: `python3 scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package --destination sim-27.2 --action test --only-testing BackwardsAuroraExperienceTests`
   — every control labelled, level 1 won through accessibility actions with every step announced, Reduce Motion and
   Reduce Flashing frames, the sound loop's state table.
3. Device (after ImplementationLock-100 only): sound, haptics and VoiceOver on D1–D3.
