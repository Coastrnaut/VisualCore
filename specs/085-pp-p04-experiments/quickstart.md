# Quickstart: A11-P04 evidence (legacy ledger; iOS 27 only)

```bash
python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing PhysicsPlaygroundCoreTests PhysicsPlaygroundExperienceTests
python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27
python3 scripts/verify_experiences.py --only a11.physics-playground --runtime 27
python3 scripts/check_experience_packages.py
python3 scripts/check_app_contract.py --app physics-playground --render
python3 scripts/test_scripts.py
```

Expected: all pass; fixtures 27–33; sample files refused byte-identical; the contract records G-EXPERIMENTS closed by
A11-P04.
