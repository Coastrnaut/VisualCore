# Quickstart: A18-P03 (feature 133)

1. Crossfade on iOS 27: `python3 scripts/xcodebuild_package.py --package Packages/VisualCoreRendering --scheme VisualCoreRendering-Package --destination sim-27.2 --action test --only-testing VisualCoreRenderingTests/CrossfadeSceneTests`.
2. Ambient Clock on iOS 27: `python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing AmbientClockCoreTests AmbientClockExperienceTests`.
3. Public API, documented API, contract, catalog, app build and unit, the runner, packages and script tests.

Every check is recorded with `python3 Tools/python/desktop_runbook.py run-check --stage A18-P03 --timeout 600 --name <n> -- <command>`.
