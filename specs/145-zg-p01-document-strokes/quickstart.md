# Quickstart: A20-P01 (feature 145)

```bash
python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing DigitalZenGardenCoreTests
python3 scripts/check_documented_api.py --sources Packages/ExperiencesCreative/DigitalZenGarden
python3 scripts/check_app_contract.py --app digital-zen-garden --render
python3 scripts/check_experience_packages.py
```

Every check is recorded with `python3 Tools/python/desktop_runbook.py run-check --stage A20-P01 --timeout 600 --name <n> -- <command>`.
