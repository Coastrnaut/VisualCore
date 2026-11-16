# Quickstart: A16-P05 (feature 121)

1. Regenerate the report: `UPDATE_VALIDATION_REPORT=1 TEST_RUNNER_UPDATE_VALIDATION_REPORT=1 python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing SimulationLabExperienceTests/SimulationValidationTests`.
2. Tests on iOS 27: `python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing SimulationLabCoreTests SimulationLabExperienceTests`.
3. Contract `python3 scripts/check_app_contract.py --app simulation-lab --render`; app `python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27`; runner `python3 scripts/verify_experiences.py --only a16.simulation-lab --runtime 27`; `check_documented_api.py`, `check_experience_packages.py`, `test_scripts.py`.

Every check is recorded with `python3 Tools/python/desktop_runbook.py run-check --stage A16-P05 --timeout 600 --name <n> -- <command>`.
