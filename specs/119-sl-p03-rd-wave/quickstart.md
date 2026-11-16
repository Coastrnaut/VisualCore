# Quickstart: A16-P03 (feature 119)

1. Tests on iOS 27: `python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing SimulationLabCoreTests SimulationLabExperienceTests` (manifest: `UPDATE_SCENARIO_MANIFEST=1 TEST_RUNNER_UPDATE_SCENARIO_MANIFEST=1`).
2. Contract: `python3 scripts/check_app_contract.py --app simulation-lab --render` (G-RDWAVE-GPU closed).
3. App: `python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27`; runner `python3 scripts/verify_experiences.py --only a16.simulation-lab --runtime 27`.
4. `python3 scripts/check_documented_api.py --sources Packages/ExperiencesCreative/SimulationLab`; `python3 scripts/check_experience_packages.py`; `python3 scripts/test_scripts.py`.

Every check is recorded with `python3 Tools/python/desktop_runbook.py run-check --stage A16-P03 --timeout 600 --name <n> -- <command>`.
