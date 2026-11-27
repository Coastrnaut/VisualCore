# Quickstart: R02-G21-07

1. Host: `swift test --package-path Packages/ExperiencesRound02 --filter BinaryGardens` — 500 snapshot round trips
   (sound on and off, equal digests), 100 schema-1 and schema-2 migrations, 200 honest and edited saves reconciled,
   every certified trace replayed against its witness fingerprints; seed 2_507; each new test < 10 s (asserted locally
   only).
2. Simulator: `python3 scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme
   ExperiencesRound02-Package --destination sim-27.2 --action test --only-testing BinaryGardensExperienceTests` —
   replay through the port, the dropped-results announcement once, the saved sound choice applied on open.
3. App: `python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27`.
4. Device (after ImplementationLock-100): a save survives a real termination on D1–D3.
