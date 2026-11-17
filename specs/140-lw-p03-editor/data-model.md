# Data model: A19-P03 (feature 140)

- **`WallpaperProject` schema 2:**
  - adds `customColors: [RGBColor]?`, either nil or exactly four colours;
  - a schema-1 file decodes as schema 2 with nil;
  - a count other than four is `invalid-parameter`, with the id `customColors`.
- **`WallpaperCore` snapshot schema 2:**
  - adds `custom` (0/1) and `colors` (twelve numbers, each 0…1);
  - the migration 1 → 2 sets `custom` 0 and fills `colors` from the preset;
  - the controls `preset.color [slot 0…3, r 0…1, g 0…1, b 0…1]` and `preset.reset []` are added;
  - a scene or preset change sets `custom` 0;
  - the digest writes `custom`, and writes `colors` when `custom` is 1.
- **`AdapterSchemaExamples`:** `schemaExample(version:seed:)`, `schemaOneExample()` (registered) and
  `schemaTwoExample()` (round-trip only).
- **`ExportNotice`:**
  - `notice(for: ExportRefusal, limit: Int) -> String?`, which is nil for a plan that fits;
  - the device name, pixel sizes and limit are formatted as integers with "×".
- **`ExportResultLine`:** `line(plan:result:) -> String`, for example "PNG, 1206 × 2622 pixels, sRGB".
- **`WallpaperHelp`:** three sections, each a title and a body.
