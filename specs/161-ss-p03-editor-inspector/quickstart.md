# Quickstart: A22-P03 (feature 161)

```bash
python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing ShaderStudioCoreTests ShaderStudioExperienceTests
xcodegen generate --spec project.yml
python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27 app-ui-ios27-d3
python3 scripts/verify_experiences.py --only a22.shader-studio --runtime 27
python3 scripts/check_app_contract.py --app shader-studio --render
```

Every check is recorded with `python3 Tools/python/desktop_runbook.py run-check --stage A22-P03 --timeout 595 --name <n> -- <command>`.
