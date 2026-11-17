# Data Model: A20-P02 (feature 146)

- **`SandField(columns:rows:)`:** defaults 160 × 120; the experience uses 480 × 360. Stamping and replay as in A20-P01,
  with cell centres at (c + 0.5)/columns and (r + 0.5)/rows.
- **`GardenCore` (ExperienceCore, snapshot schema 1):** `history` (`GardenHistory`), `inProgress` (raw points ≤ 2,048,
  rake), `rakeStyle` (0…1), `lastRefusal` (code or nil). Controls:
  - `stroke.begin` [x 0…1, y 0…1, rake 0…1]; `stroke.add` [24 × 0…1]; `stroke.end` [];
  - `rake.style` [0…1]; `sand.tone` [0…2]; `edit.undo` []; `edit.redo` [].

  Digest of the document, the history lists' counts, the stroke in progress and the rake style. Outcome
  `strokes-<n>`. Quality tiers `level-0`, `level-1`.
- **`SandScene`:** the field, its render target (`rgba16f` or `rgba8`), the relief program, the fitted tray rectangle,
  `rebuild(from:)`, `stampInProgress(_:)`, `commit(_:)`.
- **`BrushPreviewState`:** position (view points), direction, rake style, visible.
- **`StrokePatterns`:** `rows`, `circle`, `wave`, `spiral`, each a list of points in 0…1.
