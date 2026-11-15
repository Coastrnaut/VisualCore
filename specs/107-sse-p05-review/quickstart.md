# Quickstart: A14-P05 (feature 107)

1. `python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing SolarSystemExplorerCoreTests SolarSystemExplorerExperienceTests` (regenerate with `UPDATE_SCIENTIFIC_REVIEW=1 TEST_RUNNER_UPDATE_SCIENTIFIC_REVIEW=1`).
2. `python3 scripts/check_app_contract.py --app solar-system-explorer --render` (G-REVIEW closed).
3. `xcodegen generate --spec project.yml`; `python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27`; `python3 scripts/verify_experiences.py --only a14.solar-system-explorer --runtime 27`.
4. `python3 scripts/check_experience_packages.py`; `python3 scripts/test_scripts.py`; `python3 scripts/check_documented_api.py --sources Packages/ExperiencesCreative/SolarSystemExplorer`.
