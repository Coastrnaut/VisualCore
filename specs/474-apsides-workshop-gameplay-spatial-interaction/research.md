# Research: R02-G18-04

- **R1 Projected-marker picking.** Decision: the orbiter, the apoapsis square and the periapsis diamond are projected
  through the drawn camera; the orbiter is hit within its projected radius grown by 8 points, the markers within their
  projected half-size grown by 12 points (they are small); the one drawn last wins; the orbit loop is a band of 10 points
  around its projected chords. Rationale: the player touches what they see; view points give every handle the same
  allowance at every orbit. Alternatives: rays against world shapes (rejected: a world tolerance varies with depth).
- **R2 The knob and the handle are the apsides.** Decision: the periapsis marker is the knob (its direction and
  distance set the direction and eccentricity steps at the current size); the apoapsis marker is the size handle (its
  distance sets the size at the current eccentricity). The finger is cast onto the sky plane z = 0 through the drawn
  camera and rounded to the nearest steps. Rationale: "drag periapsis knob and semi-major axis" made exact — the
  periapsis lies at a(20 − k)/20 in direction 15d°, the apoapsis at a(20 + k)/20 opposite, so each drag inverts one
  closed formula. Alternatives: a radial slider beside the compass (rejected: off the picture the player reads).
- **R3 The time crank is the orbiter.** Decision: dragging the orbiter picks the tick whose projected position is
  nearest the finger; tapping the loop jumps there. Rationale: "turn time crank" — the orbiter itself is turned around
  its orbit, and the shown tick is exactly where it stands.
- **R4 Preview of the tuning.** Decision: while dragging, a dashed ghost loop shows the pending orbit with its apsis
  markers and the gauges show its readings; an invalid pending orbit shows no ghost and says why. Rationale: the player
  sees the sweep and apsides before committing; presentation only, so the digest never changes.
- **R5 Orbit and reset.** Decision: feature 464's bounds (yaw ±60°, pitch −20° … +35°), refitted per aspect and orbit;
  meshes face the drawn eye and are rebuilt when the orbit changes; double tap on empty space or "Reset view".
- **R6 One agent for the vertex contract.** Decision: the snapshot fields, ghost geometry, the new material and the
  picker are one agent's work (the lesson of R02-G16-03 and R02-G17-03).
- **R7 Panel parity within the budget.** Decision: the panel's − and + move a pending orbit and "Set periapsis" / "Set
  size" commit it, so every certified witness (at most two tunings) replays through the panel within its budget.
  Rationale: R2-F26's accessible control path; one action per press would exceed budgets of 8 … 19 for far orbits.
