# Research: R02-G03-03

- **R1 Rope geometry.** Decision: a closed tube along the control polygon, each segment straight and each corner rounded
  by a quadratic arc between the points a quarter along the adjacent segments; frames by parallel transport around the
  loop with the closing twist spread evenly. Rationale: the rules use the polygon, so the drawn crossings must be the
  rules' crossings; a Catmull-Rom spline through the points can cross where the polygon does not. Alternatives: spline
  (rejected for that reason); camera-facing strip (rejected: a glass tube needs a real normal for its fresnel rim).
- **R2 Handles and gates.** Decision: subdivided icospheres (2 levels, 320 triangles) of radius 0.18 world units for
  handles; gate cubes as 12 triangles with an edge-distance term in the shader. Both from `MeshBuilder`.
- **R3 Caustic pulses.** Decision: each projected crossing of the summary marks the over-strand segment; the vertex
  stream carries a per-vertex crossing weight (1 within one tube radius of the crossing point along the over-strand,
  fading to 0 over a further radius); the fragment shader adds an ember pulse `0.5 + 0.5 sin(2π · 0.5 · time)` times the
  weight. Reduce Motion holds time at 0.
- **R4 Camera.** Decision: a fixed authored view down −z tilted 20° about x, distance fitted to the bounding sphere of the
  rope and gates for the aspect (0.4 … 2.5) with a 5 % margin. Rationale: looking along z keeps the projection the rules
  use readable; the tilt shows depth.
- **R5 Reuse of R02-G02-03 patterns.** Decision: the adapter, snapshot, presenter, fallback, tier log, scenario manifest
  and registration follow Lissajous Labyrinth's shapes so the shared checks apply unchanged; the digest is the level
  number and the play fingerprint.
