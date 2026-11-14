# Quickstart: A08-P04 evidence (legacy ledger; iOS 27 only)

```bash
python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing OscilloscopeStudioCoreTests OscilloscopeStudioExperienceTests
python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27
python3 scripts/verify_experiences.py --only a08.oscilloscope-studio --runtime 27
python3 scripts/check_experience_packages.py
python3 scripts/check_app_contract.py --app oscilloscope-studio --render
python3 scripts/test_scripts.py
```

Expected: all pass; fixtures for freeze with cursors, zoom steps and a preset; G-SCOPEINTERACT closed by A08-P04.
