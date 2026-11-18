# Quickstart: A22-P05 (feature 163)

1. **Shader Studio tests:**
   `python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing ShaderStudioCoreTests ShaderStudioExperienceTests`.
   Expected: the stress and recovery levels are flat, the shape bounds hold, and every test is under 10 s.
2. **Manifest:** prefix the same command with `UPDATE_SCENARIO_MANIFEST=1 TEST_RUNNER_UPDATE_SCENARIO_MANIFEST=1`,
   then run it again without the prefix.
3. **App:** `xcodegen generate --spec project.yml`, then
   `python3 scripts/release_check.py --only app-build-for-testing-ios27 app-ui-ios27-d3`.
   `SSRecoveryUITests` passes.
4. **Runner:** `python3 scripts/verify_experiences.py --only a22.shader-studio --runtime 27`.
5. **Contract:** `python3 scripts/check_app_contract.py --app shader-studio --render`. G-DEVICE is closed by the
   plan; its rows stay pending.
