# Quickstart: A22-P04 (feature 162)

1. **Shader Studio tests:**
   `python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing ShaderStudioCoreTests ShaderStudioExperienceTests`.
   Expected:
   - every refusal code and the three compiler patterns give their own guidance;
   - the watchdog stops on 8 slow intervals and never on normal ones;
   - Reset restores the fallback with no compile;
   - library round trips and refusals pass.
2. **Manifest:** prefix the same command with `UPDATE_SCENARIO_MANIFEST=1 TEST_RUNNER_UPDATE_SCENARIO_MANIFEST=1`
   after a fixture change, then run it again without the prefix.
3. **App:** `xcodegen generate --spec project.yml`, then
   `python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27 app-ui-ios27-d3`.
   `SSLibraryUITests` passes, each test under 60 s.
4. **Runner:** `python3 scripts/verify_experiences.py --only a22.shader-studio --runtime 27`. Every scenario passes.
5. **Contract:** `python3 scripts/check_app_contract.py --app shader-studio --render`. G-LIBRARY and G-WATCHDOG are
   closed.
