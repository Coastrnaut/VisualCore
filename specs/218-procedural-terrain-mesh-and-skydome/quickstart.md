# Quickstart: R02-F18

1. `swift test --package-path Packages/VisualCore --filter "TerrainSettingsTests|TerrainLODTests|ErosionMaskTests|SkyModelTests"`
   — 200 seeded viewpoints obey the level rules and budget; every shared edge of 50 selections matches bit for bit;
   masks have their stated values and repeat bit for bit; settings round-trip.
2. `python3 scripts/xcodebuild_package.py --package Packages/VisualCoreRendering --scheme VisualCoreRendering-Package --destination sim-27.2 --action test`
   (and sim-26.5) — `SkyShaderTests` within 2 of 255 for 8 sun positions; `SkyRendererTests` leaves no GPU object and
   restores state; `ShaderBundleTests` compiles `vc/sky.glsl` alone.
3. `swift test --package-path Packages/VisualCore` — every existing test unchanged.
4. Regression: ExperiencesCreative (sim-27.2), the reference regression in two chunks, `python3 scripts/test_scripts.py`.
