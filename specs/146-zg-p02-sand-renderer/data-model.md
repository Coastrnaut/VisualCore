# Data Model: A20-P02 (feature 146)

- **`SandField(columns:rows:)`:** defaults 160 × 120; the experience uses 480 × 360. Stamping and replay as in A20-P01,
  with cell centres at (c + 0.5)/columns and (r + 0.5)/rows.
- **`GardenCore` (ExperienceCore, snapshot schema 1):** `history` (`GardenHistory`), `inProgress` (raw points ≤ 2,048,
  rake), `rakeStyle` (0…1), `lastRefusal` (code or nil). Controls:
  - `stroke.begin` [x 0…1, y 0…1, rake 0…1]; `stroke.add` [24 × 0…1]; `stroke.end` [];
  - `rake.style` [0…1]; `sand.tone` [0…2]; `edit.undo` []; `edit.redo` [].

  The digest covers the garden document only, since the snapshot holds only the document and the engine refuses a
  restore whose digest differs (the history, the stroke in progress and the rake style are state, not digest).
  Outcome `strokes-<n>`, or `refused-<code>` after a refused commit. Quality tiers `level-0` (full, with grain) and
  `level-1` (without grain).
- **`SandScene`:** the field, its render target (`rgba16f` or `rgba8`), the relief program, the fitted tray rectangle,
  `rebuild(from:)`, `stampInProgress(_:)`, `commit(_:)`.
- **`BrushPreviewState`:** position (view points), direction, rake style, visible.
- **`StrokePatterns`:** `rows`, `circle`, `wave`, `spiral`, each a list of points in 0…1.
- **As built (convergence T-A20-213):**
  - `stroke.begin` during a stroke discards the uncommitted one; there is no cancel action, and `cancelPointers` or a
    cancelled phase ends a drag without a commit.
  - At the stroke cap `stroke.end` is accepted with the garden unchanged: `lastRefusal` is `over-cap`, the outcome is
    `refused-over-cap`, and the controls show "The garden holds 400 strokes. Undo one to rake again."
  - Rule codes: `a20.invalid-choice`, `a20.no-stroke`, `a20.nothing-to-undo`, `a20.nothing-to-redo` and
    `a20.<refusal code>`.
  - The rgba8 read-back is compared in stored values (h × 0.5 + 0.5) within 1/255.
  - Accessibility identifiers `experience.a20.digital-zen-garden.{rake, tone, undo, redo, pattern-rows,
    pattern-circle, pattern-wave, pattern-spiral, message}`.
  - Manifest fixtures `fixture-raked-garden`, `fixture-wide-rake`, `fixture-undo`, `fixture-redo`, `fixture-tone`.
