# Quickstart: A12-P03 evidence (legacy ledger)

```bash
python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing TinyWorldsCoreTests TinyWorldsExperienceTests
python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27
python3 scripts/verify_experiences.py --only a12.tiny-worlds --runtime 27
python3 scripts/check_experience_packages.py && python3 scripts/check_app_contract.py --app tiny-worlds --render && python3 scripts/test_scripts.py
```

Expected: placement rules, exact transform round trips, schema 1 → 2 migration, store refusals and thumbnails pass;
runner 9/9; contract with G-PROPS, G-LIGHT, G-WORLDDOC closed.
