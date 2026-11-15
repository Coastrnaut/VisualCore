# Quickstart: A14-P03 (feature 105)

1. Tests on iOS 27: `python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing SolarSystemExplorerCoreTests SolarSystemExplorerExperienceTests` (regenerate with `UPDATE_SCENARIO_MANIFEST=1 TEST_RUNNER_UPDATE_SCENARIO_MANIFEST=1 UPDATE_DATA_SOURCES=1 TEST_RUNNER_UPDATE_DATA_SOURCES=1`).
2. Contract: `python3 scripts/check_app_contract.py --app solar-system-explorer --render` (G-BODIES closed).
3. App: `xcodegen generate --spec project.yml`; `python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27`; runner `python3 scripts/verify_experiences.py --only a14.solar-system-explorer --runtime 27`.
4. `python3 scripts/check_experience_packages.py`; `python3 scripts/test_scripts.py`.
