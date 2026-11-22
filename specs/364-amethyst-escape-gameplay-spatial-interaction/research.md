# Research: R02-G07-04

- **R1 Drag a shell bezel.** Decision: a drag of at least 16 points that starts on a shell turns it by the swept angle
  rounded to whole sectors (shortest equivalent), sent on release as |n| one-sector turns. Rationale: the design's "drag
  each shell bezel"; the kernel turns one sector per action, so a multi-sector drag is a short sequence of the same
  action, each counted against the budget as on the panel. Alternatives: one action per drag with a sector count (a new
  kernel action and record format).
- **R2 Tap to advance.** Decision: a tap within the pearl's touch target sends one advance. Rationale: the design's "tap
  advance pearl"; the pearl wins at touch-down so a tap on it is never read as a shell drag. Alternatives: a tap anywhere
  (ambiguous with shell selection).
- **R3 Isolate a layer.** Decision: a double tap on a shell darkens every other shell to shade 0.25 in the existing
  crystal program (the shade in uv.y); presentation only. Rationale: the design's "double tap isolate layer" without new
  GLSL or translucency changes. Alternatives: hiding other shells (loses the pearl's context).
- **R4 Analytic picking.** Decision: the touch ray through the drawn camera against the pearl sphere first, then the
  shells' top planes from the innermost (tallest) outward, with a 22-point fallback target. Rationale: R2-F22's analytic
  picking; deterministic and host-testable.
- **R5 Orbit bounds.** Decision: yaw ±40°, pitch 30° … 75° (authored 50°), distance refit to the bounding sphere.
  Rationale: R2-F22's constrained orbit avoids the vertical singularity and keeps the whole crystal visible.
- **R6 The drag preview.** Decision: the scene draws a copy of the snapshot with the dragged shell's offset (and the pearl
  in it) turned by the candidate; the kernel is untouched until release. Rationale: the player sees exactly what the
  turn will do; the same geometry code draws it.
