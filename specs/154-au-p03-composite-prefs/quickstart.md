# Quickstart: A21-P03 (feature 154)

```bash
python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing AuroraCoreTests AuroraExperienceTests
python3 scripts/check_documented_api.py --sources Packages/ExperiencesCreative/Aurora
python3 scripts/check_app_isolation.py --experiences Packages/ExperiencesCreative/Aurora
python3 scripts/verify_experiences.py --only a21.aurora --runtime 27
python3 scripts/check_app_contract.py --app aurora --render
```

Every check is recorded with `python3 Tools/python/desktop_runbook.py run-check --stage A21-P03 --timeout 595 --name <n> -- <command>`.
