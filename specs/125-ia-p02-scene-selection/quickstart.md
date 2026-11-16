# Quickstart: A17-P02 (feature 125)

1. Tests on iOS 27: `python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing InteractiveAnatomyCoreTests InteractiveAnatomyExperienceTests`.
2. Manifest: rerun the experience tests with `UPDATE_SCENARIO_MANIFEST=1 TEST_RUNNER_UPDATE_SCENARIO_MANIFEST=1` and commit `InteractiveAnatomy/scenario-manifest.json`.
3. Catalog: `python3 scripts/build_catalog.py`, then `--check`.
4. App: `xcodegen generate --spec project.yml`; `python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27`; runner `python3 scripts/verify_experiences.py --only a17.interactive-anatomy --runtime 27`.
5. Records: `check_app_contract.py --app interactive-anatomy --render`, `check_documented_api.py --sources Packages/ExperiencesCreative/InteractiveAnatomy`, `check_experience_packages.py`, `test_scripts.py`.

Every check is recorded with `python3 Tools/python/desktop_runbook.py run-check --stage A17-P02 --timeout 600 --name <n> -- <command>`.
