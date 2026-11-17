# Quickstart: A18-P01 (feature 131)

1. VisualCore host tests: `swift test --package-path Packages/VisualCore --filter VisualCoreExperienceTests`.
2. The host addition on iOS 27: `python3 scripts/xcodebuild_package.py --package Packages/VisualCoreRendering --scheme VisualCoreRendering-Package --destination sim-27.2 --action test --only-testing VisualCoreExperienceHostTests`.
3. Core tests on iOS 27: `python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing AmbientClockCoreTests`.
4. Public API (`python3 scripts/check_public_api.py`), documented API (`python3 scripts/check_documented_api.py --sources Packages/ExperiencesCreative/AmbientClock`), contract (`python3 scripts/check_app_contract.py --app ambient-clock --render`), packages, catalog, script tests, app build.

Every check is recorded with `python3 Tools/python/desktop_runbook.py run-check --stage A18-P01 --timeout 600 --name <n> -- <command>`.
