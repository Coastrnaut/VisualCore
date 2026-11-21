# Research: R02-G03-04

- **R1 Drag to direction.** Decision: compare the drag with the six projected one-step vectors at the handle and take
  the best-aligned, with a snap distance of half the projected step (at least 6 points). Rationale: the tilted (and
  orbited) view makes all three axes visible, so depth moves need no extra gesture; one move per gesture matches the
  kernel's unit step. Alternatives: free 3D drag with several moves per gesture (rejected: one drag could spend several
  moves unseen); separate z slider (rejected: an extra control the panel already offers as Over and Under).
- **R2 Arbitration.** Decision: the Lissajous controller's states (idle, dragging, orbiting, cancelled) with taps as
  selection. Rationale: proven pattern, host-testable.
- **R3 Orbit.** Decision: yaw ±40°, pitch 5° … 60° from the z axis, refit distance. Rationale: enough to read which strand
  is over, while the projection the rules use stays recognisable.
- **R4 Panel.** Decision: no pending values; one button = one move. Rationale: unlike Lissajous's dials, each panel action
  is already the game's unit move.
