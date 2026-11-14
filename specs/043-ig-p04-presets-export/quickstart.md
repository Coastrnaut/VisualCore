# Quickstart: A05-P04 evidence (legacy ledger)

```bash
python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test
python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-26.5 --action test
python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27
python3 scripts/verify_experiences.py --only a05.infinite-geometry --runtime 27
python3 scripts/verify_experiences.py --only a05.infinite-geometry --runtime 26
python3 scripts/check_public_api.py
python3 scripts/test_scripts.py
```

Expected: every command exits 0; GeometryDocumentTests, GeometryLibraryTests, GeometryExportTests and
GeometryGPUStabilityTests appear as passed; the public-API check shows no change (no framework change in this phase, so
the ProjectM reference regression is not required by Principle XIII's VisualCore-change rule).
