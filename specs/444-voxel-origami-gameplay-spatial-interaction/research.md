# Research: R02-G15-04

- **R1 Projected-cube picking.** Decision: each cube's eight corners (side 0.9 s) are projected through the drawn camera;
  a touch inside their convex outline grown by 8 points hits the cube; the front-most hit (the one the paint order draws
  last) wins. Rationale: cubes of a folded chain overlap on screen and the player touches what they see; distances in
  view points give every cube the same allowance at every orbit. Alternatives: a ray against axis-aligned boxes in the
  world (rejected: equal to the outline for unrotated cubes but needs a tolerance in world units that varies with
  depth); picking hinge marks (rejected: they lie on the seam and overlap both cubes).
- **R2 Drag predicts the swing.** Decision: for the touched cube h, the projected centroid of the cubes hinge h swings
  after a +1 and a −1 quarter turn, minus before, gives two screen directions; the step whose direction has the larger
  projection of the finger's travel is pending from 24 points and sent on release, one quarter turn per drag.
  Rationale: cube h itself lies on its hinge line and never moves, so the finger must drive what moves; a prediction
  from the drawn camera makes the chain follow the finger at every orbit. Alternatives: rotary drag about the projected
  hinge axis (rejected: the axis is often seen end-on and the sense flips); several turns per drag (rejected: each turn
  may fail on a collision, so a long drag would spend actions the player did not mean to).
- **R3 Turn by double tap.** Decision: the second tap of a double tap on a turnable cube sends `hinge.turn [h, +1]`.
  Rationale: the first tap chooses the hinge, which is harmless; feature 434's pattern for its forward re-seat.
- **R4 Orbit and reset.** Decision: yaw ±60°, pitch −20° … +35°, refitted per aspect and orbit; the meshes face the drawn
  eye and are rebuilt when the orbit changes; double tap on empty space or "Reset view". Rationale: a folded solid hides
  cubes, so the player must see its sides and top; the eye (about 3.2 from the box centre) stays outside the box
  (half-diagonal about 1.7) at every orbit. Alternatives: 434's narrow bounds (rejected: built for a wall facing the
  camera).
- **R5 Panel parity.** Decision: every certified witness replays through the panel (hinge choose, turn). Rationale:
  R2-F26's accessible control path.
