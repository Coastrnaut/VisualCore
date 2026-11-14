# Quickstart: A06-P01 evidence (legacy ledger; iOS 27 only)

```bash
swift test --package-path Packages/VisualCore --filter "SampleRingBufferTests|DemoSignalTests|SpectrumAnalyzerTests"
python3 scripts/xcodebuild_package.py --package Packages/VisualCoreRendering --scheme VisualCoreRendering-Package --destination sim-27.2 --action test
python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test
python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27
python3 scripts/verify_experiences.py --only a06.visualcore-music-lab --runtime 27
python3 scripts/check_experience_packages.py
python3 scripts/check_public_api.py
python3 scripts/test_scripts.py
```
