# Data model: A05-P04

- **GeometryDocument** (version 1, Codable, sorted keys): `version` (1), `name` (trimmed, ≤ 60, empty → "Untitled"),
  `presetIndex` (0…curated.count − 1), `preset` (GeometryPreset: kind, order, repeats, scale, palette, seed — existing
  Codable), `view2D` (centerX, centerY, zoom), `orbit3D` (yaw, pitch, distance, targetX/Y/Z, fovDegrees).
  `openValues: [Double]` and `init?(openValues:)` define the `composition.open` value layout (fixed order, documented
  in contracts/api.md).
- **Library file** `composition-<uuid>.json`: `{document, digest, format: 1, id, saved}`; `id` matches the file name;
  `format` > 1 or `version` > 1 → listed as newer, refused; undecodable → unreadable; neither is deleted or rewritten.
- **Action** `composition.open [values]`: refused as out of range when any value is out of its range or non-finite, as
  a rule when the camera is outside the bounds of the built composition; otherwise the whole state is replaced.
