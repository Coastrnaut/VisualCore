# Research: R02-G12-04

- **R1 Projected-target picking.** Decision: pips, the goal island's top centre and string segments are projected
  through the drawn camera and picked within 22 points of the touch, in that order. Rationale: the strings float at
  y = 0.1 and the pips lie on y = 0, so no single plane fits all targets; distances in view points give every target the
  same touch size at every orbit. Alternatives: a ray against the plane y = 0.1 with world-space tolerances (rejected:
  the tolerance in points then varies with depth and orbit).
- **R2 Pluck chooses, never tunes.** Decision: a tap on a string chooses it at its current peg and describes its
  resonance; no action is spent. Rationale: "pluck to audition" is listening, and every action costs budget; the audible
  audition comes with sound in R02-G12-06. Alternatives: a tap that steps the peg (rejected: accidental spending).
- **R3 Peg by vertical drag.** Decision: 24 points of upward movement per peg from the current peg, clamped 1 … 12,
  tuned on release when changed. Rationale: a peg is turned in whole steps; a fixed screen distance is the same at every
  orbit and string direction, and 11 steps fit in 264 points. Alternatives: drag along the string's projected direction
  (rejected: short or end-on strings would be untunable at some orbits).
- **R4 Tap freeze to test.** Decision: a tap on the goal island or a step pip sends the crossing test. Rationale: the
  catalog's "tap freeze to test walkway"; the goal and the window's pips are where the walkway is judged.
  Alternatives: a hold to test (rejected: the earlier games keep holds for irreversible commits, and a test is undoable).
- **R5 Orbit and reset.** Decision: yaw ±35°, pitch −15° … +20° around the authored view, field of view refitted per
  aspect and orbit; double tap on empty space or "Reset view". Rationale: features 394 and 404's proven bounds.
- **R6 Panel parity.** Decision: every certified witness replays through the panel (string and peg steppers, tune, test).
  Rationale: R2-F26's accessible control path.
