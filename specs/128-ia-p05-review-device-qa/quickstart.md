# Quickstart: A17-P05 (feature 128)

1. Tests on sim-27.2: `python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing InteractiveAnatomyCoreTests InteractiveAnatomyExperienceTests`; regenerate the review table with `UPDATE_DATA_SOURCES=1 TEST_RUNNER_UPDATE_DATA_SOURCES=1`, then rerun.
2. App, runner, packages, catalog, contract, documented API and scripts as in feature 127.

Every check is recorded with `python3 Tools/python/desktop_runbook.py run-check --stage A17-P05 --timeout 600 --name <n> -- <command>`.
