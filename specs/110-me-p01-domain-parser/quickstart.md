# Quickstart: A15-P01 (feature 110)

1. Tests on iOS 27: `python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing MolecularExplorerCoreTests MolecularExplorerExperienceTests`.
2. Regenerate the manifest and data-sources document: prefix with `UPDATE_SCENARIO_MANIFEST=1 TEST_RUNNER_UPDATE_SCENARIO_MANIFEST=1 UPDATE_DATA_SOURCES=1 TEST_RUNNER_UPDATE_DATA_SOURCES=1`.
3. Contract: `python3 scripts/check_app_contract.py --app molecular-explorer --render` (G-ELEMENTS, G-DOMAIN, G-PARSER closed).
4. App: `xcodegen generate --spec project.yml`, `python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27`; runner `python3 scripts/verify_experiences.py --only a15.molecular-explorer --runtime 27`.
5. `python3 scripts/check_experience_packages.py`; `python3 scripts/test_scripts.py`.
