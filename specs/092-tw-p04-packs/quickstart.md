# Quickstart: A12-P04 evidence (legacy ledger)

```bash
python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing TinyWorldsCoreTests TinyWorldsExperienceTests
python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27
python3 scripts/verify_experiences.py --only a12.tiny-worlds --runtime 27
python3 scripts/check_experience_packages.py && python3 scripts/check_app_contract.py --app tiny-worlds --render && python3 scripts/test_scripts.py
```

Expected: packs open with committed digests, sweeps keep limits and clearance over props, budgets and licenses hold;
runner 9/9; contract with G-PACKS closed.
