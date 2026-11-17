# Quickstart: A18-P05 (feature 135)

1. Cache on iOS 27: `python3 scripts/xcodebuild_package.py --package Packages/VisualCoreRendering --scheme VisualCoreRendering-Package --destination sim-27.2 --action test --only-testing VisualCoreRenderingTests/CachedSceneTests`.
2. Ambient Clock on iOS 27: `… --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --only-testing AmbientClockCoreTests AmbientClockExperienceTests`.
3. App and interface: `python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27 app-ui-ios27-z2`; runner, contract, packages, catalog, script tests.

Every check is recorded with `python3 Tools/python/desktop_runbook.py run-check --stage A18-P05 --timeout 600 --name <n> -- <command>`.
