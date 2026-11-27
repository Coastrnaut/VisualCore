# Research: R02-G21-03

- **R1 One fit rule per level.** Decision: a kernel point (x, y, z) at scale 2²⁰ is drawn at k · (x, y, z) / 2²⁰ with
  k = 0.95 / R, R the largest of the level's ring radii and world radii (level constants), barycentre at the origin, the
  kernel's base plane z = 0 (x right, y away across the plane, z up). Rationale: catalog systems range from ring radii
  of a few units to 16 and world radii up to 36; one rule fills the same disc of radius 0.95 for every level, and nothing
  a player does (ring, phase, luminosity, tilt) changes the scale, so the scene never jumps. Alternatives: one fixed
  scale for the kernel's largest radius 60 (rejected: a small system would be a speck); a scale from the current
  arrangement (rejected: moving a star would rescale everything).
- **R2 Orbits through the kernel's table points.** Decision: every ring and orbit is a 48-gon whose vertex i is
  (ρ·C[i]/1024, ρ·S[i]/1024·C[τ]/1024, ρ·S[i]/1024·S[τ]/1024) · k for a star ring at tilt τ and (a·C[i]/1024,
  a·S[i]/1024, 0) · k for a world orbit, from `BinaryGardensSky.cosine` and `sine`. Rationale: the kernel's positions are
  exactly these points times 2²⁰, so every body sits on a vertex of its drawn orbit ("analytic orbit curves") and no
  run-time trigonometry can disagree with the rules. Alternatives: smooth circles from `cos` (rejected: off the bodies
  by up to the table's rounding).
- **R3 Drawn values are judged values.** Decision: bodies stand at the kernel's positions for the shown tick
  (`starPositions[t − 1]`, `worldPositions[t − 1]`); a world's lit sides scale by each star's kernel share over 64 000 at
  that tick and its banding is the kernel's band at that tick; gauge cells, guide lines, window bracket and bloom marker
  use the kernel's flux, bounds, window, start and integral; nothing is interpolated between ticks. The shown tick is 48
  at opening (the starting configuration, since tick 48 is tick 0 again) and never advanced by time. Rationale: the exact
  light stays exact on screen; the picture never decides.
- **R4 Painter's order for everything.** Decision: backdrop, tilt dial, star rings, world orbits, trails, then the
  bodies (two stars and every world) sorted back to front by distance from the eye (ties: worlds first, then index),
  each body's pips with it, then gauges and actions bars, the glow additive and last; depth testing off and no face
  culling; a cube-sphere emits its faces far-first relative to the fixed eye. Rationale: the window surface of the
  shared renderer has no depth buffer (feature 493's research R3, corrected at its implement), so no round-two
  experience depth-tests; a quad's transparent fringe writes no depth and never clips a neighbour.
- **R5 Cube-sphere worlds and two-sun shading.** Decision: each world is a cube-sphere (six faces of n × n quads,
  vertices normalised onto the sphere; n = 8, 5, 3 by tier) of radius 0.07, generated in the game's Core with
  `MeshBuilder` (the shared packages offer only a UV sphere; a game-local generator needs no VisualCore API change). The
  vertex carries the sphere normal, the band as the material (five world materials), star 1's share / 64 000 as the
  value of `a_uv.x` and star 2's share / 64 000 in `a_uv.y`; the star positions at the shown tick are uniforms. The
  fragment shader lights the surface with each star's colour by max(0, n · l_i) times its share, adds a sunrise band
  (a narrow brightened strip where n · l_i is near 0, warm for star 1, cool for star 2) so the two terminators cross as
  two coloured dawn lines, and keeps an ambient floor of 0.35 of the surface colour so a world's night side still
  reads (the frame check needs a world centre at least 0.15 brighter than the backdrop: mint #7BE8BE at 0.35 is about
  0.28 in luminance against a backdrop of at most about 0.1). Rationale: "two suns painting crossing sunrise bands over
  tiny flowering spheres" and "twin light discs" on the GL ES path without textures.
- **R6 Shader-only seasonal banding.** Decision: from the normal's latitude φ = asin(n.z): lethal low draws frost caps
  for |φ| ≥ 30°, dim frost caps for |φ| ≥ 60°, comfortable a mint surface with procedural petal dots (flower #FFE6F2)
  from a fixed hash of the cube-sphere coordinates, bright a scorched equatorial belt |φ| ≤ 15°, lethal high a belt
  |φ| ≤ 40°; edges feathered. Rationale: "cube-sphere planet mesh and shader-only seasonal banding"; the band is
  readable by shape (caps, belt, flowers) as well as tint. ("Caps reaching latitude ±30°" is read as caps covering every
  latitude beyond ±30°.)
- **R7 Flats by signed distance, materials in uv.** Decision: as in feature 493, `a_uv.x` = material code + 0.4 · value
  (valued materials only) + 64 when a failure names the element (above every code 0 … 37); flats (ring dashes, pips, cells, brackets, markers,
  bars, discs, rays, motes) carry their quad-local coordinate (u, v) and a shape parameter w in `a_normal`, as 493's
  quads do (a world's `a_normal` is its sphere normal, so its second share rides in `a_uv.y`), and are cut by signed
  distance; the backdrop carries its height 0 … 1 in `a_uv.y`; star discs are quads facing the eye with a white-hot core of half the radius. Rationale: the shared
  `ShaderMeshRenderer` binds only position, normal and uv.
- **R8 Trails, coronas, motes and glow are decoration.** Decision: trails are dots at the kernel's positions of the 8
  (level-0) or 4 (level-1) ticks before the shown tick, cyclically, fading with age (the design's "numerical gravitation
  in fixed steps" read as the 48 fixed steps); coronas of 12 or 6 rays and 8 or 4 pollen motes circling each comfortable
  world on a fixed loop move by presentation time only (still under Reduce Motion); 2 or 1 glow shells around the stars
  and blooming worlds; level-2 drops them all. Rationale: richness that carries no rule meaning; level-2 loses nothing a
  player needs.
- **R9 Shape is the non-colour twin.** Decision: stars by position, ring and pips (luminosity = disc size and filled
  pips); a world's band by caps, belt or flowers; gauge cells by height and shape (crossed lethal, hollow dim/bright,
  solid comfortable); window bracket solid or dashed; bloom bracket with marker; world ↔ gauge row by j + 1 pips; tilt by
  the dial and the drawn plane; actions by a row of bars; the broken colour always with a broken ring or mark.
  Rationale: R02-F10.
- **R10 Camera.** Decision: a fixed authored perspective, eye (0, −2.0, 3.2) looking at (0, −0.35, 0), fitted to x
  −1.3 … 1.3, y −1.85 … 1.15, z −0.85 … 0.85 for aspects 0.4 … 2.5 with a 5 % margin. Arithmetic: a star at the
  largest tilt rises at most 0.95 · 724/1024 ≈ 0.672 above the plane, plus a disc of at most 0.05 + 0.012 · 3 = 0.086;
  five gauge rows end at y = −1.6 and the actions bars at y = −1.2 − 0.5 − 0.03 = −1.73 (0.035 tall); the tilt dial
  starts at (−1.15, 1.08); the gauge plate reaches x = 1.22. Rationale: the orbit plane reads as a plane while every
  body, gauge and bar stays visible.
- **R11 Failure marks.** Decision: frozen or scorched mark the named world with a broken ring and its gauge cell at
  column ((tick − 1) mod 48) + 1 (walk ticks run to 48 + E); unstable marks the world's window bracket (with no
  comfortable tick — window 0, start 0 — the required-length tick W alone is drawn and marked); wilted or bleached mark
  its bloom meter marker; the failure text is the kernel's `failureDescription`. Rationale: the failing element is
  visible by colour and by shape and named in words.
- **R12 The shown tick's control range.** Decision: `clock.show` declares the range 0 … 60 (0 … 48 + the largest
  tolerance 12, the span of the kernel's walk ticks), and the adapter refuses 0 and 49 … 60 with `r02-g21.tick` without
  touching the kernel; the engine refuses values outside the declared range before the core. The shown tick persists
  across ring, phase, luminosity, tilt, run, undo and redo (the report always covers ticks 1 … 48) and returns to 48 at
  an opening, `level.next`, reset and restore. Rationale: a declared range of exactly 1 … 48 would let the engine's
  standard out-of-range refusal pre-empt every `r02-g21.tick`, making the spec's adapter code unreachable; the wider
  declaration keeps the adapter's own rule observable, as Mushroom Weather's `r02-g20.cycle` is.
- **R13 Reuse of R02-G20-03 patterns.** Decision: the adapter, snapshot, presenter, fallback, tier log, frame probes
  (two backdrop corners), scenario manifest (standard scenarios, `full-playthrough`, `hero`, fixtures, 80 acceptance
  scenarios R2-G21-QA-001 … 080) and registration follow Mushroom Weather's shapes as recorded at R02-G20-03 so the
  shared checks apply unchanged; the digest (domain `r02-g21.binary-gardens.v1`) is the level number and the play
  fingerprint; the adapter certifies each level directly from its recorded candidate (`certifiedCandidates`, each
  R02-G21-02 witness's `skipped`), the whole catalog only if that candidate no longer certifies; the invariant scans
  read a fixed kernel file list (493's T-002 change to `MushroomWeatherInvariantTests`).
- **R14 Quality profile.** Decision: one `QualityLevel` per tier, best first: element share = motes / 8 (1, 0.5, 0),
  iteration share = quads per face / 64 (1, 25/64, 9/64), effect passes = glow shells (2, 1, 0), resolution share 1;
  no budget rises from level-0 to level-2. Rationale: the shared contract requires a non-increasing profile; the Core's
  `qualityTiers` (3) equals the presenter's levels.

## Implementation decisions (feature 503 convergence, T-R02G2103-014 … 016)

- **Light response.** A linear share / 64 000 leaves catalog worlds (tens to hundreds of milliflux) black, so the
  shaders light through `BinaryGardensShaders.lightResponse(share:)`, log2-shaped and 1 at 1 024 milliflux; the uv
  stream still carries share / 64 000.
- **Fallback star check.** The unlit fallback draws a star as its flat disc colour (vermilion about 0.48 in luminance)
  without the white-hot core, so its frame check is that colour within 0.1; the shader path keeps the +0.4 margin.
- **Failure marks** are drawn on a failed play only (stage failed, or result after a failed run), never for the
  predicted failure while playing, as feature 493 does.
- **Hero tick.** The earliest tick with the most comfortable worlds after the certified plan (tick 1 on level 1).
- **Gauge plate.** Its quad spans u = ±1 exactly (coverage by v only), because the ±1.25 fringe of a plate over
  x −0.95 … 1.22 would reach x 1.49, outside the fitted box; every other flat keeps ±1.25.

