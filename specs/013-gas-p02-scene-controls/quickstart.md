# Quickstart: A01-P02 validation

1. `swift test --package-path Packages/VisualCore` (SceneClock, ParameterEditor) and
   `swift test --package-path Apps/GenerativeArtStudio/Core` (CompositionEditor, open classification) pass.
2. VisualCoreRendering package tests on iOS 27.2 and 26.5 pass, including ParameterPanelTests.
3. GenerativeArtStudio scheme tests on both runtimes:
   - the unit tests cover parameter change visible, reset all returns the preset image, scrub determinism, and
     particles update equivalence;
   - the UI tests cover the controls sheet sliders, value and reset, play/pause and scrub, the preset, palette and
     seed pickers, and recovery from corrupt and future-version launch data.
4. `python3 scripts/release_check.py --only public-api app-contracts documented-api-showcase reference-engine-xcframework
   reference-build-projectm-ios-sim reference-test-anglerendering-ios27 reference-test-anglerendering-ios26
   reference-clean projectm-reference-ios27 projectm-reference-ios26` passes; `check_documented_api.py --sources
   Apps/GenerativeArtStudio` passes.
