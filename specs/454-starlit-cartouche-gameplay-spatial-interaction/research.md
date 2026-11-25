# Research: R02-G16-04

- **R1 Projected-disc picking.** Decision: each star's centre is projected through the drawn camera and its ring radius
  (0.098) converted to view points at its depth; a touch within that radius grown by 8 points hits the star; the
  front-most hit (the one the paint order draws last) wins; the ship's star is the ship. Rationale: stars overlap on
  screen as the chart turns and the player touches what they see; distances in view points give every star the same
  allowance at every orbit. Alternatives: a ray against spheres in the world (rejected: needs a world tolerance that
  varies with depth); picking corridors (rejected: legs are chosen by destination, and corridors cross).
- **R2 The slider is the wait pips.** Decision: the slider is the projected box of the nine wait pips grown by 8 points;
  the wait is the pip nearest to the finger's projection onto the screen line through pips 0 and 8. Rationale: the pips
  already show the chosen wait (R02-G16-03), so the control is where its value is drawn. Alternatives: a horizontal drag
  anywhere (rejected: collides with orbit and ship drags); a separate UI slider (rejected: the panel already has
  wait − and +).
- **R3 Launch preview at L = beat + wait.** Decision: the stars (and the ship) are drawn at their positions at the launch
  beat; a dashed sapphire ribbon previews the leg to the destination's position at arrival. Rationale: the player can
  see range, windows and hazards at the moment of launch — the source's "preview gliding 3D route"; at wait 0 nothing
  moves. Alternatives: ghost stars beside the current ones (rejected: doubles the clutter); animating through the beats
  (rejected: motion is presentation-only and must stay still under Reduce Motion).
- **R4 Fly by double tap or ship drag.** Decision: the second tap of a double tap on a star sends `route.fly`; a drag
  from the ship released over a star sends it. Rationale: the first tap chooses, which is harmless; feature 444's
  pattern for its forward turn; the drag reads as drawing the route.
- **R5 Orbit and reset.** Decision: feature 444's bounds (yaw ±60°, pitch −20° … +35°), refitted per aspect and orbit;
  meshes face the drawn eye and are rebuilt when the orbit changes; double tap on empty space or "Reset view".
- **R6 One agent for the vertex contract.** Decision: the snapshot fields, preview geometry, the new material and the
  picker are one agent's work. Rationale: R02-G16-03's parallel shader and geometry agents wrote different vertex
  conventions and had to be reconciled.
- **R7 Panel parity.** Decision: every certified witness replays through the panel (route.choose, route.fly).
  Rationale: R2-F26's accessible control path.
