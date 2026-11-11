# Quickstart: A01-P04 validation

1. `swift test --package-path Packages/VisualCore`: the `ExportGeometry` tests pass. They cover 12 combinations
   (for example 864×1080 and 1080×608), even edges, the maxEdge, 8192 and 64 MP caps, and clamped long edges.
2. `swift test --package-path Apps/GenerativeArtStudio/Core`: the `ExportOptions` tests pass (file names, available
   sizes under a cap, the format label).
3. `python3 scripts/xcodebuild_package.py --package Packages/VisualCoreRendering --scheme VisualCoreRendering-Package
   --destination sim-27.2 --action test --result-name <name>` (and `sim-26.5`): the `OffscreenExportTests` pass
   (exact size, top-down quadrants, opaque sRGB PNG round trip, live frame restored, over-budget failure with 0
   leaks, over-limit refused, `maxRenderSize` ≥ 4096).
4. GenerativeArtStudio scheme tests on iOS 27.2 and 26.5:
   - `ExportRenderTests`: 12 dimensions, determinism for 4 families, downscaled match ≤ 6/255, failure keeps the
     scene running with 0 leaks, particle proportions;
   - `ExportUITests`: the sheet, pickers, dimension label, export, share control and close.
5. `check_public_api.py`, `check_documented_api.py --sources Apps/GenerativeArtStudio`,
   `check_app_contract.py --app generative-art-studio` (G-EXPORT closed), the release-check fast steps and the
   7-step reference regression all pass.
