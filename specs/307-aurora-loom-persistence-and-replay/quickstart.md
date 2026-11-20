# Quickstart: R02-G01-07

1. Host: `swift test --package-path Packages/ExperiencesRound02 --filter 'AuroraLoomReconciliationTests|AuroraLoomPersistenceTests|AuroraLoomExperienceCoreTests'`
   — traces, reconciliation, round trips, migrations, edited saves, replay; each test < 10 s.
2. Simulator: the round-two suite on sim-27.2 — replay through the port and the panel.
3. Device (after ImplementationLock-100 only): progress survives a real termination.
