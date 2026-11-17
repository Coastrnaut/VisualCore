# Quickstart: A21-P05 (feature 156)

```bash
python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing AuroraCoreTests AuroraExperienceTests
xcodegen generate --spec project.yml
python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27 app-ui-ios27-c3
python3 scripts/verify_experiences.py --only a21.aurora --runtime 27
```

Every check is recorded with `python3 Tools/python/desktop_runbook.py run-check --stage A21-P05 --timeout 595 --name <n> -- <command>`.
