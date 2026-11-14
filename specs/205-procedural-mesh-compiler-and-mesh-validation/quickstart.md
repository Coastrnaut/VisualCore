# Quickstart: R02-F05 evidence

```bash
swift test --package-path Packages/VisualCore
python3 scripts/xcodebuild_package.py --package Packages/VisualCoreRendering --scheme VisualCoreRendering-Package --destination sim-27.2 --action test
python3 scripts/xcodebuild_package.py --package Packages/VisualCoreRendering --scheme VisualCoreRendering-Package --destination sim-26.5 --action test
python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test
python3 scripts/check_public_api.py --update
python3 scripts/check_documented_api.py --sources Apps/VisualCore
python3 scripts/release_check.py --only reference-engine-xcframework reference-build-projectm-ios-sim reference-clean
python3 scripts/release_check.py --only reference-test-anglerendering-ios27 reference-test-anglerendering-ios26 projectm-reference-ios27 projectm-reference-ios26
python3 scripts/test_scripts.py
```

Expected: all PASS; every shape valid at 3 resolutions with analytic volumes within 1%; 12 of 12 planted defects
reported; committed digests equal on host and both simulators; existing mesh outputs unchanged; reference 7 of 7.
