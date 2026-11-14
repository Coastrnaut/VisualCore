# Quickstart: A05-P01 evidence (legacy ledger)

```bash
swift test --package-path Packages/VisualCore --filter SymmetryTests
python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test
python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-26.5 --action test
python3 scripts/check_experience_packages.py
python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27
python3 scripts/verify_experiences.py --only a05.infinite-geometry --runtime 27
python3 scripts/verify_experiences.py --only a05.infinite-geometry --runtime 26
python3 scripts/check_public_api.py
python3 scripts/release_check.py --only reference-engine-xcframework reference-build-projectm-ios-sim reference-clean
python3 scripts/release_check.py --only reference-test-anglerendering-ios27 reference-test-anglerendering-ios26 projectm-reference-ios27 projectm-reference-ios26
python3 scripts/test_scripts.py
```

Expected: all pass; symmetry identity/orbit/fold tests; 4 presets deterministic; 9/9 scenarios on both runtimes.
