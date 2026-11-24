# Research: R02-G13-04

- **R1 Projected-target picking.** Decision: coherence bars and hold pips, star centres and link splines are projected
  through the drawn camera and picked within 22 points of the touch, in that order. Rationale: the stars float at
  different heights (y 0.04 … 0.26) and the gauges lie on y = 0, so no single plane fits all targets; distances in view
  points give every target the same touch size at every orbit. Alternatives: a ray against a plane with world-space
  tolerances (rejected: the tolerance in points then varies with depth and orbit).
- **R2 Tap a star to nudge forward.** Decision: a tap on a star while playing sends `star.nudge [s, 1]` and chooses the
  star; the backward nudge stays on the panel. Rationale: the catalog's "tap a node to phase nudge"; one tap, one step,
  one action, predictable. Alternatives: left or right half of the star for − and + (rejected: stars are ~20 points wide
  at common sizes, too small to split reliably); a vertical drag on a star for ± (rejected: drags from a star make
  links).
- **R3 Drag from star to star toggles the link.** Decision: release on a second star links an unlinked pair or unlinks
  a pair the player linked; fixed links send nothing. Rationale: "drag links between 3D stars"; the same gesture undoes
  its own effect, and fixed links are part of the level. Alternatives: a tap on a link to unlink (rejected: accidental
  spending; a link tap inspects instead).
- **R4 Listen by touching the gauges.** Decision: a tap on a coherence bar or a hold pip sends `constellation.listen`.
  Rationale: the gauges show what a listen judges; the earlier games test where the verdict is drawn (Harmonic Bridges'
  pips). Alternatives: a hold anywhere (rejected: holds are kept for irreversible commits).
- **R5 Orbit and reset.** Decision: yaw ±35°, pitch −15° … +20° around the authored view, field of view refitted per
  aspect and orbit; double tap on empty space or "Reset view". Rationale: features 404 and 414's proven bounds.
- **R6 Panel parity.** Decision: every certified witness replays through the panel (star and partner steppers, link,
  nudge, listen). Rationale: R2-F26's accessible control path.
