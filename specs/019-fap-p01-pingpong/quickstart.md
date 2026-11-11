# Quickstart: validate Fluid Art Playground Phase 01

Prerequisites: `python3 scripts/verify_environment.py` passes, and the simulators are
`19108E51-71E5-4862-9C7F-6CBC357C060D` (iOS 27.2) and `EC7498FF-31FF-4491-9666-B0D32785203C` (iOS 26.5).
Every command below is wrapped in `python3 Tools/python/desktop_runbook.py run-check --stage A02-P01 --name <n> --timeout <s> -- …`.

1. **Host tests**. Expected: all pass, including the new FieldGrid, TimeStepPolicy, configuration and dissipation
   suites.
   - `swift test --package-path Packages/VisualCore`
   - `swift test --package-path Apps/FluidArtPlayground/FluidArtPlaygroundCore`
2. **Rendering package tests**, one runtime per call. Expected: PingPongTarget, FieldPass, FloatRenderSupport and
   FloatTransfer pass.
   - `python3 scripts/xcodebuild_package.py --package Packages/VisualCoreRendering --scheme VisualCoreRendering-Package --destination sim-27.2 --action test --result-name fap-p01-rendering-27`
   - the same with `--destination sim-26.5 --result-name fap-p01-rendering-26`.
3. **App tests**. First run `xcodegen generate --spec project.yml`, then
   `xcodebuild test -project VisualCore.xcodeproj -scheme FluidArtPlayground -destination "platform=iOS Simulator,id=<udid>" -derivedDataPath Build/DerivedData/FluidArtPlayground -resultBundlePath .autonomy/xcresults/<unique>.xcresult -test-timeouts-enabled YES -default-test-execution-time-allowance 300 CODE_SIGNING_ALLOWED=NO`
   on each runtime. Then run
   `python3 scripts/check_test_enumeration.py --sources Apps/FluidArtPlayground/Tests --log <log>`.
   Expected:
   - the dissipation fixture is within tolerance for `d ∈ {0, 1, 5}` in both storages;
   - lifecycle: 0 leaks after the rebuild;
   - the UI canvas is non-blank and changing.
4. **API and documentation checks**. Expected: the baseline diff contains only additions.
   - `python3 scripts/check_public_api.py` (run `--update` after the review)
   - `python3 scripts/check_documented_api.py --sources Packages/VisualCoreRendering/Sources`
   - `python3 scripts/check_documented_api.py --sources Apps/FluidArtPlayground`
   - `check_dependencies.py`, `check_compliance.py`, `check_licenses.py`, `validate_docs.py`, `test_scripts.py`
5. **Contract**. Expected: G-PINGPONG, G-FLOATRT, G-FIELDPASS and G-CPUFIELD are closed; M01, M03 and M10 are
   available.
   - `python3 scripts/check_app_contract.py --app fluid-art-playground --render`
6. **ProjectM regression**. Expected: 3/3 and 4/4.
   - `release_check.py --only reference-engine-xcframework reference-build-projectm-ios-sim reference-clean`
   - `release_check.py --only reference-test-anglerendering-ios27 reference-test-anglerendering-ios26 projectm-reference-ios27 projectm-reference-ios26`
