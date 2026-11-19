# Quickstart: A24-P04 (feature 176)

```bash
python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing GraphicsBenchmarkLabCoreTests GraphicsBenchmarkLabExperienceTests
python3 scripts/check_experience_packages.py
xcodegen generate --spec project.yml && python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27
python3 scripts/verify_experiences.py --only a24.graphics-benchmark-lab --runtime 27
python3 scripts/check_app_contract.py --app graphics-benchmark-lab --render
```

Every check is recorded with `python3 Tools/python/desktop_runbook.py run-check --stage A24-P04 --timeout 595 --name <n> -- <command>`.
