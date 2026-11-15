# Quickstart: A12-P02 evidence (legacy ledger)

```bash
swift test --package-path Packages/VisualCore --filter RayIntersectionTests
python3 scripts/xcodebuild_package.py --package Packages/VisualCoreRendering --scheme VisualCoreRendering-Package --destination sim-27.2 --action test --only-testing VisualCoreRenderingTests/MeshRendererTests VisualCoreRenderingTests/DepthMeshPassTests VisualCoreRenderingTests/MeshRendererColorTests
python3 scripts/check_public_api.py
python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing TinyWorldsCoreTests TinyWorldsExperienceTests
python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27
python3 scripts/verify_experiences.py --only a12.tiny-worlds --runtime 27
python3 scripts/check_experience_packages.py && python3 scripts/check_app_contract.py --app tiny-worlds --render && python3 scripts/test_scripts.py
```

Expected: all pass; existing renderer tests unchanged; 27 detail meshes valid; contract with G-MATERIALS, G-PICKING,
G-CAMERA closed.
