# Data Model: A20-P01 (feature 145)

- **`GardenPalette`:** tray `small-tray` (aspect 4:3, field 160 × 120); sand tones `pale`, `warm`, `grey` (opaque
  sRGB, components in 0…1); rake styles `fine-rake` (5 tines, width 0.06, depth 0.6) and `wide-rake` (3 tines, width
  0.10, depth 1.0); stone kinds `river-pebble`, `flat-slate`, `round-granite`, `tall-basalt`, `moss-boulder`, each with
  base radii (rx, ry) in tray widths, all in 0.01…0.08.
- **`RakeStroke`:** `rake` (a rake style id), `points` ([`Vec2`], 1…512, each coordinate finite and in 0…1),
  `capped` (Bool).
- **`Stone`:** `id` (UInt32, unique), `kind` (a stone kind id), `position` (`Vec2` in 0…1), `rotation` (−π…π),
  `scale` (0.5…2), `depth` (Int, unique among the stones).
- **`GardenDocument`:** schema 1, envelope kind `a20.garden`; `tray`, `tone`, `stones` (≤ 24), `strokes` (≤ 400),
  `nextStoneID`. `encoded()` writes sorted keys; `decode(_:)` checks the size (≤ 262,144 bytes), the envelope, the
  version, the body, then every value.
- **`DocumentRefusal`:** `damaged`, `newer-version`, `too-large`, `unknown-tray`, `unknown-tone`, `unknown-rake`,
  `unknown-stone`, `out-of-range`, `over-cap`, each with a sentence.
- **`StrokeResampler`:** `resample(_ points:, spacing: 0.004, cap: 512) -> Result<(points, capped), DocumentRefusal>`
  (a non-finite point refuses).
- **`RakeBrush`:** `height(across u:, style:)`; `stamp(into field:, at point:, direction:, style:)`.
- **`SandField`:** 160 × 120 `[Float]`, zero at rest; `replay(_ strokes:)`; `maxDifference(_:)`.
- **`GardenCommand`:** `rake(RakeStroke)`, `place(Stone)`, `move(id, from, to)`, `rotate(id, from, to)`,
  `remove(Stone)`, `tone(from, to)`.
- **`GardenHistory`:** `document`, `checkpoint` (document and field), `done` (≤ 100), `undone`; `apply(_:)`,
  `undo()`, `redo()`, `field()` (rebuilt from the checkpoint).
