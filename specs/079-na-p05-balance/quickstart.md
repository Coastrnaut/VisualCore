# Quickstart: A10-P05 evidence (legacy ledger; iOS 27 only)

```bash
python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing NeonArcadeCoreTests NeonArcadeExperienceTests
python3 scripts/build_catalog.py
python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27
python3 scripts/verify_experiences.py --only a10.neon-arcade --runtime 27
python3 scripts/check_experience_packages.py
python3 scripts/check_app_contract.py --app neon-arcade --render
python3 scripts/check_distinctiveness.py
python3 scripts/test_scripts.py
```

Expected: all pass; three levels declared consistently; balance targets met; G-GLOWCAPS closed by A10-P05.
