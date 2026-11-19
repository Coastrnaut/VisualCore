# Quickstart: A23-P03 (feature 168)

```bash
python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing VisualProgrammingLabCoreTests VisualProgrammingLabExperienceTests
xcodegen generate --spec project.yml
python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27
python3 scripts/verify_experiences.py --only a23.visual-programming-lab --runtime 27
python3 scripts/check_app_contract.py --app visual-programming-lab --render
```

Every check is recorded with `python3 Tools/python/desktop_runbook.py run-check --stage A23-P03 --timeout 595 --name <n> -- <command>`.
