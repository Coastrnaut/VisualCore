# Quickstart: A17-P04 (feature 127)

1. VisualCore: `swift test --package-path Packages/VisualCore --filter AnchoredLabelLayoutTests`; `python3 scripts/check_public_api.py --update` then `python3 scripts/check_public_api.py`.
2. Interactive Anatomy on sim-27.2: `python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing InteractiveAnatomyCoreTests InteractiveAnatomyExperienceTests` (regenerate the manifest and the sources table if their inputs changed, then rerun).
3. App, runner, packages, catalog, scripts, contract and documented API as in feature 126.

Every check is recorded with `python3 Tools/python/desktop_runbook.py run-check --stage A17-P04 --timeout 600 --name <n> -- <command>`.
