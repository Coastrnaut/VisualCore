# Research: R02-G17-04

- **R1 Projected-disc picking.** Decision: each body's centre is projected through the drawn camera and its disc radius
  (r · s) converted to view points at its depth; a touch within that radius grown by 8 points hits the body; the
  front-most hit (painted last) wins. Rationale: discs overlap on screen during eclipses and the player touches what
  they see; view points give every body the same allowance at every orbit. Alternatives: a ray against spheres in the
  world (rejected: a world tolerance varies with depth); picking rings (rejected: rings cross, and the body is the
  handle).
- **R2 The orbital handle is the body.** Decision: a drag from a movable body picks the phase whose orbit position at the
  shown tick projects nearest to the finger. Rationale: "drag orbital handles" — the body slides along its own ring, and
  the phase offset is exactly which orbit position it occupies at the shown tick. Alternatives: an angular drag about
  the ring's centre (rejected: orbits are lattice ellipses, and nearest-position is exact for any shape).
- **R3 The time dial is the timeline.** Decision: the dial is the projected box of the timeline strip and its brackets
  grown by 8 points; the tick is round(f · (horizon − 1)) for the finger's fraction along the strip. Rationale: the
  playhead already shows the shown tick (R02-G17-03), so the control is where its value is drawn; "step through predicted
  eclipse timeline" is also the panel's tick − and +.
- **R4 Preview of the phase change.** Decision: while dragging, the ghost shows the body at the pending orbit position and
  the timeline shows the predicted events with that phase. Rationale: the player sees which eclipses the change would
  produce before committing it; presentation only, so the digest never changes.
- **R5 Orbit and reset.** Decision: feature 454's bounds (yaw ±60°, pitch −20° … +35°), refitted per aspect and orbit;
  meshes face the drawn eye and are rebuilt when the orbit changes; double tap on empty space or "Reset view".
- **R6 One agent for the vertex contract.** Decision: the snapshot fields, ghost geometry, the new material and the picker
  are one agent's work (the lesson of R02-G16-03 and R02-G17-03).
- **R7 Panel parity.** Decision: every certified witness replays through the panel (planet − and +, phase − and +, run).
  Rationale: R2-F26's accessible control path.
