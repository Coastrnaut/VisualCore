# Research: R02-G04-04

- **R1 Angle about the projected centre.** Decision: the swipe's turn is the accumulated change of the touch's angle
  about the compass centre projected through the drawn camera, ignoring points within 20 points of the centre.
  Rationale: the finger "holds" the dial as on a physical compass; accumulating increments (not start-to-end) keeps a
  swipe that winds past ±180° correct; the dead zone avoids jumps where the angle is unstable. Alternatives: horizontal
  drag distance (rejected: does not feel like rotation, and depends on where the finger is).
- **R2 One action per gesture.** Decision: the turn is sent once at release, wrapped into −47 … 48. Rationale: matches
  Wave Knot Keeper and keeps undo to one step per gesture; the preview shows the result before it is sent.
- **R3 Hub tap to probe.** Decision: a tap (release within 10 points of the touch-down) inside the projected hub (0.3
  world units, at least 30 points) probes. Rationale: "press to sample a clue" with a target large enough for the
  44-point guideline at common sizes, and far from the wheel.
- **R4 Orbit.** Decision: yaw ±40°, tilt 15° … 60° (authored 35°), refitted to the 1.45 sphere. Rationale: enough to see
  fog heights without losing the wheel's readability.
