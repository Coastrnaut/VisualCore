# Quickstart: A19-P04 (feature 141)

1. `python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing LivingWallpapersCoreTests LivingWallpapersExperienceTests`
2. `sh specs/141-lw-p04-save-share/scan-photos.sh`; `sh specs/138-lw-p01-export-contract/scan-platform-claims.sh`; `sh specs/140-lw-p03-editor/scan-help-claims.sh`; `python3 scripts/check_app_isolation.py --experiences Packages/ExperiencesCreative/LivingWallpapers`
3. `python3 scripts/build_catalog.py --check`; `xcodegen generate --spec project.yml`; `python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27`; `python3 scripts/release_check.py --only app-release-build app-usage-descriptions`; `python3 scripts/verify_experiences.py --only a19.living-wallpapers --runtime 27`

Each is recorded with `python3 Tools/python/desktop_runbook.py run-check --stage A19-P04 --timeout 600 --name <n> -- <command>`.
