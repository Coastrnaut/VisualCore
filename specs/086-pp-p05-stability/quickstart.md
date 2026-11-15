# Quickstart: A11-P05 evidence (legacy ledger; iOS 27 only)

```bash
python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing PhysicsPlaygroundCoreTests PhysicsPlaygroundExperienceTests
python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27
python3 scripts/verify_experiences.py --only a11.physics-playground --runtime 27
bash specs/086-pp-p05-stability/scan-claims.sh
python3 scripts/build_catalog.py --check
python3 scripts/check_experience_packages.py
python3 scripts/check_app_contract.py --app physics-playground --render
python3 scripts/check_distinctiveness.py --check
python3 scripts/test_scripts.py
```

Expected: all pass; fixtures 34–38; three levels everywhere; the contract records G-STABILITY closed by A11-P05.
