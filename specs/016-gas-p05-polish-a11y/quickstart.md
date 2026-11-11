# Quickstart: A01-P05 validation

1. `swift test --package-path Packages/VisualCore`: the `AccessibilityPreferences` tests pass (12 resolutions,
   playback rate, unknown stored values, Codable).
2. `swift test --package-path Apps/GenerativeArtStudio/Core`: the `CanvasDescription` tests pass.
3. `python3 scripts/xcodebuild_package.py --package Packages/VisualCoreRendering --scheme VisualCoreRendering-Package
   --destination sim-27.2 --action test --result-name <name>` (and `sim-26.5`): the observer and `EffectScene` bypass
   tests pass.
4. GenerativeArtStudio scheme tests on iOS 27.2 and 26.5:
   - `AccessibilityApplyTests`: rate, limiter bound, export unlimited;
   - `LifecycleRegressionTests`: background/foreground, recreation, 20 cycles, export after recovery;
   - `SettingsUITests`: pickers, persistence, footer;
   - `AccessibilityAuditUITests`: 6 screens at 2 text sizes, canvas description;
   - all Phase 01–04 suites.
5. `check_public_api.py`, `check_documented_api.py --sources Apps/GenerativeArtStudio`,
   `check_app_contract.py --app generative-art-studio` (G-UI closed), the release-check fast steps and the 7-step
   reference regression all pass.
