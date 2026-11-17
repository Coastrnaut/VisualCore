# Quickstart: A20-P03 (feature 147)

```bash
python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing DigitalZenGardenCoreTests DigitalZenGardenExperienceTests
python3 scripts/check_documented_api.py --sources Packages/ExperiencesCreative/DigitalZenGarden
python3 scripts/check_app_isolation.py --experiences Packages/ExperiencesCreative/DigitalZenGarden
python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27
python3 scripts/verify_experiences.py --only a20.digital-zen-garden --runtime 27
```

Every check is recorded with `python3 Tools/python/desktop_runbook.py run-check --stage A20-P03 --timeout 600 --name <n> -- <command>`.
