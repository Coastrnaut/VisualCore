# Quickstart: A24-P03 (feature 175)

```bash
python3 scripts/xcodebuild_package.py --package Packages/VisualCoreRendering --scheme VisualCoreRendering-Package --destination sim-27.2 --action test --only-testing VisualCoreRenderingTests/RegistryCapabilitiesTests VisualCoreRenderingTests/GPUFrameTimerTests
python3 scripts/check_public_api.py
python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing GraphicsBenchmarkLabCoreTests GraphicsBenchmarkLabExperienceTests
sh specs/175-gbl-p03-runner-probe/scan-identifiers.sh
python3 scripts/release_check.py --only reference-engine-xcframework reference-build-projectm-ios-sim reference-clean
python3 scripts/release_check.py --only reference-test-anglerendering-ios27 reference-test-anglerendering-ios26 projectm-reference-ios27 projectm-reference-ios26
xcodegen generate --spec project.yml && python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27
python3 scripts/verify_experiences.py --only a24.graphics-benchmark-lab --runtime 27
```

Every check is recorded with `python3 Tools/python/desktop_runbook.py run-check --stage A24-P03 --timeout 595 --name <n> -- <command>`.
