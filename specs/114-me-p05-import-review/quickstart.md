# Quickstart: A15-P05 (feature 114)

1. Tests on iOS 27: `python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing MolecularExplorerCoreTests MolecularExplorerExperienceTests` (regenerate the manifest with `UPDATE_SCENARIO_MANIFEST=1 TEST_RUNNER_UPDATE_SCENARIO_MANIFEST=1`, the review with `UPDATE_DATA_REVIEW=1 TEST_RUNNER_UPDATE_DATA_REVIEW=1`).
2. Contract: `python3 scripts/check_app_contract.py --app molecular-explorer --render` (G-IMPORT, G-REVIEW closed).
3. Copy claims: `python3 scripts/check_copy_claims.py --swift Packages/ExperiencesCreative/MolecularExplorer/Experience/*.swift Packages/ExperiencesCreative/MolecularExplorer/Experience/Adapter/*.swift`.
4. App: `python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27`; runner `python3 scripts/verify_experiences.py --only a15.molecular-explorer --runtime 27`.
5. `python3 scripts/check_documented_api.py --sources Packages/ExperiencesCreative/MolecularExplorer`; `python3 scripts/check_experience_packages.py`; `python3 scripts/test_scripts.py`.
