# Quickstart: A19-P05 (feature 142)

1. `python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing LivingWallpapersCoreTests LivingWallpapersExperienceTests`
2. `xcodegen generate --spec project.yml`; `python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27 app-ui-ios27-a3`
3. `python3 scripts/verify_experiences.py --only a19.living-wallpapers --runtime 27`; `python3 scripts/check_app_contract.py --app living-wallpapers --render`

Each is recorded with `python3 Tools/python/desktop_runbook.py run-check --stage A19-P05 --timeout 600 --name <n> -- <command>`.
