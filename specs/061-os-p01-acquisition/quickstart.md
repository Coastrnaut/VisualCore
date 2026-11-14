# Quickstart: A08-P01 evidence (legacy ledger; iOS 27 only)

```bash
swift test --package-path Packages/VisualCore --filter "TestSignalTests|StereoSampleBufferTests|ScopeTriggerTests"
python3 scripts/xcodebuild_package.py --package Packages/VisualCoreRendering --scheme VisualCoreRendering-Package --destination sim-27.2 --action test --only-testing VisualCoreAudioTests
python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing OscilloscopeStudioCoreTests
python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing OscilloscopeStudioExperienceTests
python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27
python3 scripts/verify_experiences.py --only a08.oscilloscope-studio --runtime 27
python3 scripts/check_experience_packages.py
python3 scripts/check_public_api.py
python3 scripts/check_app_contract.py --app oscilloscope-studio --render
python3 scripts/test_scripts.py
```

Expected: all pass; nine standard and five fixture scenarios pass; the API baseline lists the new types; the contract
records G-DEMOWAVES, G-TRIGGER and G-STEREO (test-signal and file paths) closed by A08-P01.
