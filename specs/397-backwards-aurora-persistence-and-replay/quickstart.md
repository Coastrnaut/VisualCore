# Quickstart: R02-G10-07

1. Host: `swift test --package-path Packages/ExperiencesRound02 --filter BackwardsAurora` — 500 snapshot round trips,
   100 schema-1 and schema-2 migrations, 200 honest and edited saves reconciled, every certified trace replayed.
2. Simulator: `python3 scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package --destination sim-27.2 --action test --only-testing BackwardsAuroraExperienceTests`
   — replay through the port, the dropped-results announcement, the saved sound choice applied on open.
3. Device (after ImplementationLock-100): a save survives a real termination on D1–D3.
