# Quickstart: A14-P04 (feature 106)

1. Host: `python3 scripts/xcodebuild_package.py --package Packages/VisualCoreRendering --scheme VisualCoreRendering-Package --destination sim-27.2 --action test --only-testing VisualCoreExperienceHostTests/CanvasOverlayTests VisualCoreExperienceHostTests/ExperienceHostViewTests`; `python3 scripts/check_public_api.py` (after `--update`); `python3 scripts/check_documented_api.py --sources Packages/ExperiencesCreative/SolarSystemExplorer`.
2. Experience tests on iOS 27: `python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing SolarSystemExplorerCoreTests SolarSystemExplorerExperienceTests` (regenerate with `UPDATE_SCENARIO_MANIFEST=1 TEST_RUNNER_UPDATE_SCENARIO_MANIFEST=1`).
3. Contract: `python3 scripts/check_app_contract.py --app solar-system-explorer --render` (G-TIME, G-TOURS closed).
4. App: `xcodegen generate --spec project.yml`; `python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27`; runner `python3 scripts/verify_experiences.py --only a14.solar-system-explorer --runtime 27`.
5. `python3 scripts/check_experience_packages.py`; `python3 scripts/test_scripts.py`.
