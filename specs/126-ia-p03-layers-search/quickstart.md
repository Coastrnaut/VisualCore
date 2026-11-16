# Quickstart: A17-P03 (feature 126)

1. VisualCore: `python3 scripts/xcodebuild_package.py --package Packages/VisualCoreRendering --scheme VisualCoreRendering-Package --destination sim-27.2 --action test --only-testing VisualCoreRenderingTests/DepthMeshPassTests VisualCoreRenderingTests/DepthMeshPassTranslucentTests`; `python3 scripts/check_public_api.py --update` then `python3 scripts/check_public_api.py`.
2. Interactive Anatomy: `python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing InteractiveAnatomyCoreTests InteractiveAnatomyExperienceTests`. Regenerate with `UPDATE_DATA_SOURCES=1 TEST_RUNNER_UPDATE_DATA_SOURCES=1` and `UPDATE_SCENARIO_MANIFEST=1 TEST_RUNNER_UPDATE_SCENARIO_MANIFEST=1`, then rerun.
3. App and runner as in feature 125; contract, documented API, packages, scripts.

Every check is recorded with `python3 Tools/python/desktop_runbook.py run-check --stage A17-P03 --timeout 600 --name <n> -- <command>`.
