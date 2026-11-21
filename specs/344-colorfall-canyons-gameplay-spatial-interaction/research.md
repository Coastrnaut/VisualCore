# Research: R02-G05-04

- **R1 Drag to carve, tap for valves.** Decision: carving needs a drag of at least 16 points that starts on a carvable
  cell; a tap on a spring toggles its valve; a tap on a cell does nothing. Rationale: the design says "drag short sluice
  edits and tap valves"; a stray tap never changes the terrain. Alternatives: tap to carve (too easy to misfire on a
  phone).
- **R2 Analytic picking.** Decision: the touch ray through the drawn camera against block tops and emitter boxes, nearest
  hit, with a 22-point fallback target. Rationale: R2-F22's analytic picking; deterministic and host-testable; cells can
  be small on large grids.
- **R3 Orbit bounds.** Decision: yaw ±40°, pitch 25° … 70°, distance refit to the bounding sphere. Rationale: R2-F22's
  constrained orbit avoids the vertical singularity and keeps the whole canyon visible.
- **R4 Reuse of R02-G04-04 patterns.** Decision: the gesture controller's states and event handling follow Hue Compass's
  so the experience host's pointer entry and the wiring tests apply unchanged.
- **R5 The drag highlight.** Decision: the highlighted cell's top gets a thin square pearl ring (inset 0.08·u, 0.06·u
  wide, lifted 0.01·u) with terrain material code 2 (pearl) like the basin rims, drawn by the existing terrain program
  after the terrain; in the fallback it is a pearl per-vertex-coloured ring. Rationale: no new GLSL; pearl is already the palette's rim colour. Alternatives:
  a fluid-program glow (would read as fluid).
