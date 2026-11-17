# Quickstart: A19-P02 (feature 139)

1. `python3 scripts/xcodebuild_package.py --package Packages/VisualCoreRendering --scheme VisualCoreRendering-Package --destination sim-27.2 --action test --only-testing VisualCoreRenderingTests VisualCoreExperienceHostTests`
2. `python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing LivingWallpapersCoreTests LivingWallpapersExperienceTests`
3. `python3 scripts/check_public_api.py`; `python3 scripts/check_documented_api.py --sources Packages/ExperiencesCreative/LivingWallpapers`; `sh specs/138-lw-p01-export-contract/scan-platform-claims.sh`
4. `xcodegen generate --spec project.yml`; `python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27`; `python3 scripts/verify_experiences.py --only a19.living-wallpapers --runtime 27`

Each is recorded with `python3 Tools/python/desktop_runbook.py run-check --stage A19-P02 --timeout 600 --name <n> -- <command>`.
