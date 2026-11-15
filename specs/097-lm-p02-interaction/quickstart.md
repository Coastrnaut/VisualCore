# Quickstart: A13-P02 evidence (legacy ledger; iOS 27 only)

```bash
python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing LightMazeCoreTests LightMazeExperienceTests
python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27
python3 scripts/verify_experiences.py --only a13.light-maze --runtime 27
python3 scripts/check_experience_packages.py
python3 scripts/check_app_contract.py --app light-maze --render
python3 scripts/test_scripts.py
```

Expected: all pass; the contract records G-SNAP and G-BEAMS closed by A13-P02.
