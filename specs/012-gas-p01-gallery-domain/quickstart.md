# Quickstart: A01-P01 validation

1. `swift test --package-path Packages/VisualCore`: VisualCoreParameters and TestSupport tests pass.
2. `swift test --package-path Apps/GenerativeArtStudio/Core`: document validation, round trips (≥ 50 generated
   documents, seeds 0 and 2^64−1), hash stability and particle replay determinism pass.
3. `python3 scripts/xcodebuild_package.py --package Packages/VisualCoreRendering --scheme VisualCoreRendering-Package
   --destination sim-27.2|sim-26.5 --action test`: ShaderBundle, GLSL library and FullScreenShaderScene tests pass.
4. Run the `GenerativeArtStudio` scheme tests on both simulators: unit tests (determinism, distinctness, non-blank,
   cleanup) and UI tests (gallery shows 4 families; opening each shows the canvas) pass.
5. The Showcase tests pass on both runtimes (ShaderBundle migration).
6. `python3 scripts/release_check.py --only public-api documented-api-showcase app-contracts reference-engine-xcframework
   reference-build-projectm-ios-sim reference-test-anglerendering-ios27 reference-test-anglerendering-ios26
   reference-clean projectm-reference-ios27 projectm-reference-ios26` passes; `check_documented_api.py --sources
   Apps/GenerativeArtStudio` passes.
