# Research: R02-G06-03

- **R1 Sky layout.** Decision: the grid in the xz-plane, cell size 2/max(columns, rows), stars at node height 0.25·u over
  their cells, tracks and targets on the field. Rationale: one-to-one with the rules (cell, loop, target), so every drawn
  element names a rule value. Alternatives: continuous orbits (rejected: hides the discrete cells that decide collisions).
- **R2 History ribbons as a score.** Decision: each star's last R ticks joined as a ribbon whose points rise by 0.04·u per
  tick of age and fade by alpha 1 − age/R. Rationale: the design's "polyline history cache with predictable alpha decay"
  and "3D star traces accumulate into glowing history ribbons"; rising staves read as a woven score and show timing
  without touching the rules.
- **R3 Shape is the non-colour twin.** Decision: star i has shape i (ring, cross, diamond, triangle, square), repeated
  inside its target ring; holds and collisions have their own marks. Rationale: R2-F10's rule that shape and luminance
  carry every clue independently of hue.
- **R4 Camera.** Decision: a fixed authored view from the front (+z) pitched 55° down, fitted to the grid plus the ribbons'
  height for aspects 0.4 … 2.5 with a 5 % margin. Rationale: every cell and ribbon visible; orbit comes with gestures in
  R02-G06-04.
- **R5 Reuse of R02-G05-03 patterns.** Decision: the adapter, snapshot, presenter, fallback, tier log, scenario manifest
  and registration follow Colorfall Canyons's shapes so the shared checks apply unchanged; the digest is the level number
  and the play fingerprint; generated levels are cached once per process.
