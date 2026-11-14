# Quickstart: A08-P02 evidence (legacy ledger; iOS 27 only)

```bash
swift test --package-path Packages/VisualCore --filter "MinMaxDecimatorTests|SceneGraphTests"
python3 scripts/xcodebuild_package.py --package Packages/VisualCoreRendering --scheme VisualCoreRendering-Package --destination sim-27.2 --action test --only-testing VisualCoreRenderingTests/PrimitiveRendererTests
python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing OscilloscopeStudioCoreTests OscilloscopeStudioExperienceTests
python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27
python3 scripts/verify_experiences.py --only a08.oscilloscope-studio --runtime 27
python3 scripts/check_experience_packages.py
python3 scripts/check_public_api.py
python3 scripts/check_app_contract.py --app oscilloscope-studio --render
python3 scripts/test_scripts.py
```

Expected: all pass; the manifest's fixtures include the flat line, the missing crossing (auto and normal) and XY; the
contract records G-DECIMATION, G-TRACESTRIP and G-XYMODE closed by A08-P02.
