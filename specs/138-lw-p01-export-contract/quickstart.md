# Quickstart: A19-P01 (feature 138)

1. `python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing LivingWallpapersCoreTests`: all core tests pass.
2. `sh specs/138-lw-p01-export-contract/scan-platform-claims.sh`: PASS.
3. `python3 scripts/check_documented_api.py --sources Packages/ExperiencesCreative/LivingWallpapers`; `python3 scripts/check_experience_packages.py`; `python3 scripts/check_app_contract.py --app living-wallpapers --render`; `python3 scripts/test_scripts.py`; `python3 scripts/release_check.py --only app-build-for-testing-ios27`.

Each check is recorded with `python3 Tools/python/desktop_runbook.py run-check --stage A19-P01 --timeout 600 --name <n> -- <command>`.
