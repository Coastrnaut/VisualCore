# Quickstart: A15-P04 (feature 113)

1. Tests on iOS 27: `python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing MolecularExplorerCoreTests MolecularExplorerExperienceTests`.
2. Contract: `python3 scripts/check_app_contract.py --app molecular-explorer --render` (G-LIBRARY closed).
3. App: `python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27`; runner `python3 scripts/verify_experiences.py --only a15.molecular-explorer --runtime 27`.
4. `python3 scripts/check_documented_api.py --sources Packages/ExperiencesCreative/MolecularExplorer`; `python3 scripts/check_experience_packages.py`; `python3 scripts/test_scripts.py`.
