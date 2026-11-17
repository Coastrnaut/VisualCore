# Data model: A19-P01 (feature 138)

- **`SceneDefinition`:**
  - `id`, one of aurora-bands, ink-flow, soft-cells or ripple-dunes;
  - `name`;
  - `parameters`: [`SceneParameter`(id, name, minimum, maximum, default)], two or three per scene, with minimum < maximum
    and minimum ≤ default ≤ maximum;
  - `presets`: three `ColorPreset`(id, name, colours: four `RGBColor` with r, g, b in 0…1, opaque by construction).
  - `SceneCatalog.scenes` is fixed and in catalog order.
- **`CanvasTemplate`:**
  - `id` (for example "iphone-16-pro"), `device`, `family` (iPhone or iPad);
  - `portraitWidth` and `portraitHeight` in pixels;
  - `provenance` ("Apple technical specifications, retrieved 2026-11-17").
  - `size(for: Orientation)` swaps the edges for landscape. `SafeAreaGuide` has top 0.22, bottom 0.10 and side 0.04
    (fractions, labelled approximate).
- **`WallpaperProject` (schema 1):**
  - `scene`, `preset` (Int), `seed` (UInt64), `parameters` ([String: Double]), `template`, `orientation`,
    `animationTime` (0…3600, finite) and `format` (`ExportFormat`: png);
  - its envelope kind is `a19.wallpaper-project`, with a size limit of 16,384 bytes;
  - `ProjectRefusal`: damaged, newerVersion(Int), unknownScene, unknownPreset, unknownTemplate, invalidParameter and
    tooLarge(Int), each with a `code` and a `sentence`.
- **`ExportPlan`:** format, width, height, colour profile (sRGB), and `fallback` (Bool).
  - `ExportPlanner.plan(project:maxEdge:maxPixels:)` returns `.success(plan)` when the template fits. Otherwise it
    returns `.failure(.doesNotFit(template:offered:))`, or `.failure(.noLimit)` when maxEdge ≤ 0.
- **`ExportResult`:** width, height, profile name and bytes, from `ImageColorPipeline.inspect(_ data:)`.
  `verify(_:against:)` gives `.ok`, or the mismatches as `dimensions`, `profile` or `unreadable`.
