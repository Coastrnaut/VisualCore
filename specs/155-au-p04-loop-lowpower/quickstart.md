# Quickstart: A21-P04 (feature 155)

```bash
swift test --package-path Packages/VisualCore --filter VisualCoreAudioDSPTests
python3 scripts/xcodebuild_package.py --package Packages/VisualCoreRendering --scheme VisualCoreRendering-Package --destination sim-27.2 --action test --only-testing VisualCoreAudioTests
python3 scripts/check_public_api.py
python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing AuroraCoreTests AuroraExperienceTests
python3 scripts/release_check.py --only reference-engine-xcframework reference-build-projectm-ios-sim reference-clean
python3 scripts/release_check.py --only reference-test-anglerendering-ios27 reference-test-anglerendering-ios26 projectm-reference-ios27 projectm-reference-ios26
```

Every check is recorded with `python3 Tools/python/desktop_runbook.py run-check --stage A21-P04 --timeout 595 --name <n> -- <command>`.
