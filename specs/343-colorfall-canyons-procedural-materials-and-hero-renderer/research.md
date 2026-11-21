# Research: R02-G05-03

- **R1 Canyon layout.** Decision: the grid in the xz-plane, cell size 2/max(columns, rows), block tops at 0.06·h·u, rows
  nearer the camera lower (the generator slopes heights down by row), so falls read as waterfalls toward the viewer.
  Rationale: one-to-one with the rules (cell, height, ground, fluid), so every drawn element names a rule value; the
  design's "heightfield mesh, generated surface normals, flow-map bands". Alternatives: a smooth interpolated heightfield
  (rejected: hides the discrete steps that decide routing).
- **R2 Colour and its non-colour twin.** Decision: fluid colour is the mass-weighted mix of cyan, coral and yellow, its
  brightness follows volume, and each colour has a pattern (stripes, dots, chevrons) in the sheet and in the basin
  target arcs. Rationale: R2-F10's rule that shape and luminance carry every clue independently of hue.
- **R3 Flow bands as presentation.** Decision: bands move along each cell's downhill direction with presentation time
  only; Reduce Motion freezes them. Rationale: motion shows direction without touching the rules.
- **R4 Camera.** Decision: a fixed authored view from the front (+z) pitched 50° down, fitted to the grid's bounding
  sphere for aspects 0.4 … 2.5 with a 5 % margin. Rationale: every cell and fall visible; the design asks for an authored
  pose readable on a phone (orbit comes with gestures in R02-G05-04).
- **R5 Reuse of R02-G04-03 patterns.** Decision: the adapter, snapshot, presenter, fallback, tier log, scenario manifest
  and registration follow Hue Compass's shapes so the shared checks apply unchanged; the digest is the level number and
  the play fingerprint; generated levels are cached once per process.
