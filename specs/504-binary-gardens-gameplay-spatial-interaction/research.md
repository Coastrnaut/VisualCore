# Research: R02-G21-04

Facts read from the committed R02-G21-03 Core (`BinaryGardensSceneGeometry.swift`, `BinaryGardensSceneSnapshot.swift`,
`BinaryGardensShaders.swift`, `BinaryGardensExperienceCore.swift`, `BinaryGardensSky.swift`) and the drafted
R02-G21-03 experience, 2026-11-27. Model: feature 494 (`MushroomWeatherViewOrbit`, `MushroomWeatherPicker`,
`MushroomWeatherGestureController`, `MushroomWeatherPanelWinTests`, `MushroomWeatherGestureWiringTests`, commits
`63f05371c` … `b64b70803`).

- **R1 One press, two drags, told apart by direction.** Decision: a press on a star that travels 16 points while
  playing is a star drag; its mode is decided once, at the move (or release) that starts it, by comparing the travel's
  component along the star's projected orbit tangent u with its component across u (along strictly greater: phase; else
  ring; |u| < 0.5 points: ring), overridden by the locks (only ring adjustable: ring; only phase: phase; neither:
  explain and send nothing). u is the projection of table step (θ + ω·t + 1) minus that of (θ + ω·t − 1) on the star's
  ring at the current tilt, t the shown tick (48 counts as 0, since (θ + 48ω) mod 48 = θ). Rationale: "drag star
  distance rings" and the phase lever share one body; a fixed, once-only decision keeps the drag stable as the finger
  curves. Alternatives considered: a long-press to switch modes (slower, undiscoverable); separate handles (clutter on
  a phone).
- **R2 Ring targets snap to rings; phase targets snap to the grid.** Decision: a ring drag targets the ring index whose
  point at the star's drawn table step (radius k·ρᵢ, same tilt) projects nearest the finger (lower index on ties); a
  phase drag targets the grid phase p ∈ {0, g, 2g, …, 48 − g} whose drawn position (table step (p + ω·t) mod 48 on the
  current ring and tilt) projects nearest the finger (lower p on ties). Rationale: every release is either a legal
  candidate the kernel can judge or no change (the kernel refuses an off-grid phase, so no free-form phase is offered).
- **R3 Luminosity and tilt count travel.** Decision: a tap picks the pip whose projected centre is nearest the finger
  (lower index on ties); a drag of 16 points or more sets clamp(start + round(dx / 32), 0, upper) for the horizontal
  travel dx (right raises; halves away from zero), upper = levels − 1 or T_max. Rationale: the luminosity pips are
  0.022 apart and 0.008 in shape half, the dial pips 0.05 apart — a few points on a phone — so a drag counts travel, as
  feature 494's moon drag does (40 points there for 4 levels; 32 here for up to 7 tilt steps).
- **R4 Preview is the kernel's law.** Decision: `BinaryGardensPreview.of(_:arrangement:actionsLeft:level:)` applies
  the kernel's own `BinaryGardensSky.changed` (internal to `BinaryGardensCore`, same module) and, when accepted,
  `BinaryGardensSky.report` of the changed arrangement; a refusal is the kernel's `BinaryGardensError` in the order the
  play would give it (`changed`'s `.action(name)` first — range, grid, locked, unchanged, separation — then `.budget`
  when no action is left). An unchanged value, a `.run` or a level whose shape differs from the snapshot's yields no
  preview. Rationale: what the player sees before lifting is exactly what the commit gives or refuses; feature 494 did
  the same with `MushroomWeatherForest.run`. Unlike 494 (which drops refused previews), a refused change is previewed
  as refused (spec Q3) and still sent once on release, so the refusal and its reason code are shown and logged.
- **R5 What a preview draws.** Decision: the drawn snapshot (`drawnSnapshot(_:)`) takes the previewed report's worlds
  (flux, shares, bands, windows, integrals, bloom) for an accepted preview; for a luminosity or tilt preview also the
  previewed arrangement and star positions (the star disc and pips at the previewed level; the orbit plane, rings and
  stars at the previewed tilt); for a ring or phase preview the committed stars and rings stay and a ghost star (dashed outline, `ghostStar`, the star's current disc radius) is drawn at the target's position at the
shown tick, right after its star's disc and pips, inside that star's body element. Behind
  every previewed gauge cell the committed cell is drawn as a ghost outline (`ghostCell`, the committed band's colour).
  A refused preview keeps the committed drawing and adds the ghost in the broken colour: at the target for a ring or
  phase change, at the star with its previewed radius for a luminosity change, at both stars' positions at the
  previewed tilt (`starPosition(radius:phase:tilt:)`, pure geometry) for a tilt change. Rationale: the change in each
  world's light reads cell by cell, and no ghost relies on hue (dashed shape; refusal also in words).
- **R6 Inspection is presentation.** Decision: a world tap toggles the inspected world (a second tap or "Inspect: none"
  clears it); a gauge-row tap inspects its world too. The scene draws an `inspectRing` (ring shape, outer radius 0.115,
  marker colour, outside the 0.1 broken ring) with the world and two `inspectBracket` strips (0.006 wide, y ± 0.05) at
  x −0.962 and 1.232 round its gauge row; the description gives `worldTickDescription(_:tick:report:)` at the shown
  tick and `worldDescription(_:report:)`. Rationale: "inspect each miniature world" without a camera zoom keeps the one
  fit box (spec assumption) and reuses the kernel's words.
- **R7 Scrubbing is the gauge row.** Decision: a press on a gauge row reads the tick under the finger at touch-down
  (nothing sent) and every later move sends `clock.show [tick]` when it differs from the last read, in any stage; tick
  = clamp(⌊(x + 0.9) / (1.8 / 48)⌋ + 1, 1, 48) for the cast x clamped to the cells (so the plate margin x −0.95 … −0.9
  reads 1 and the bloom meter reads 48); a tap that did not scrub sends the tick only when x ≤ 0.95. Rationale: the 48
  tick cells are already a timeline (unlike 494, no separate scrubber track is needed, so the paint order is unchanged).
- **R8 Thresholds and orbit as feature 494.** Decision: tap 10 points and 0.5 s, drag 16 points, double tap 0.35 s and
  22 points, orbit 90° per view width and 60° per view height, yaw ±60°, pitch −20° … +35°, allowance 12 points, the
  same arbitration (a second finger cancels and orbits, a third re-bases, cancelled phases send nothing), only event
  timestamps. Rationale: every round-two game feels the same.
- **R9 Orbit camera and drawn eye.** Decision: `camera(aspect:orbit:)` turns the authored frame by −pitch about +x
  through the look-at point, then by the yaw about +z through `orbitPivot` = the authored box centre (0, −0.35, 0) —
  here the authored look-at point itself, so the yaw never moves the target; keeps the authored field of view; and moves
  the eye along the turned view axis to the larger of the authored distance (≈ 3.60) and the distance at which every
  corner of the authored box lies inside the view with `refitMargin` 0.06 per side. At orbit (0, 0) it returns the
  authored camera bit for bit. The authored elevation is atan(3.2 / 1.65) ≈ 62.7°, so pitch +35° carries the eye just
  past the vertical (≈ 97.7°) as in 494, where the frame does not roll; at −20° the eye stands ≈ 42.7° above the
  base plane, z ≈ 2.4 > 0.85, outside the box. No box extension is needed (494 extended its box to the moon): every
  drawn point already lies in the authored box (rings at tilt 6 reach |z| ≤ 0.95 · sin 45° + 0.086 ≈ 0.76; dial, gauges
  and bars at z 0). With an orbit every part facing the eye (star discs, luminosity, world and tilt pips, trails, motes,
  coronas, glow shells, ghost star, inspect ring) faces the drawn eye, bodies sort back to front from it, cube-sphere
  quads are emitted far-first from it and the backdrop stands perpendicular to its view axis behind the box; the
  camera-free overloads are the camera-taking ones at the authored camera. Rationale: 503's meshes face the static
  authored eye (`billboardBasis` and `paintOrder` read it), which would look wrong and mis-pick once orbited.
- **R10 The snapshot gains the star speed and freedoms.** Decision: `BinaryGardensSceneSnapshot` gains `starSpeed` (ω,
  the level's 1 … 3) and `freedoms` (per star: ring, phase, luminosity adjustable), copied in `init(play:…)`; the
  unchecked initialiser takes them with defaults (ω 1, everything adjustable) so 503's tests stay as they are.
  Rationale: the tangent, the phase targets and the lock overrides need them at touch-down, and the controller (like
  494's) reads only the drawn snapshot; the preview still takes the level, as 494's `previewing(_:level:)` does.
  Neither enters the digest (the snapshot never does).
- **R11 Picking order as drawn.** Decision: the reverse of the paint order (bars, gauges, bodies front to back from
  the drawn eye — a star's pip row before its disc —, rings with later indices first, the dial, the system disc);
  glow, trails, orbits and backdrop are empty space. The gauge plates (0.09 tall at a 0.1 pitch) never overlap, so the
  spec's "centre lines decide between neighbours" never applies, and the 0.01 gap between two plates is empty space.
  Rationale: what the finger seems to touch is what is picked (spec Q1).
- **R12 Panel direct choices.** Decision: for the selected star a ring choice (ring 1 … n), a luminosity choice (level
  1 … L) and a phase target (a stepper by g over 0 … 48 − g, presentation only) with "Set phase"; a tilt choice
  (0 … T_max, shown only when T_max > 0); an "Inspect" world choice (none, world 1 … W); "Reset view"; the existing
  one-step − / + rows stay. Each choice sends one action. Rationale: a witness action may move a ring, luminosity or
  tilt by more than one step, or a phase by more than one grid step; through − / + it would cost more than one action
  and exceed the budget; direct choices replay every witness within its budget (SC-R02G2104-005).

## Spec assumptions checked against the R02-G21-03 code

| Spec statement | Code (2026-11-27) | Consequence |
|---|---|---|
| "fitted to the box … with a 5 % margin" | `fitMargin` = 0.06 per side | the refit uses 0.06 too (≥ 5 %), continuous at orbit 0 |
| luminosity pips "as the scene geometry gives them" | pips face the static authored eye (`billboardBasis`) | camera-taking `luminosityPips(_:_:eye:)`; picker reads the drawn eye's |
| bodies "sorted back to front from the eye" | `paintOrder` sorts by distance from the static `eye` | `paintOrder(_:eye:)`; picker and meshes use the drawn eye |
| tangent from table step (θ + ω·t ± 1); locks from the star flags | snapshot lacks ω and the flags | R10: snapshot gains `starSpeed` and `freedoms` |
| gauge rows "the rows' centre lines deciding between neighbours" | plates y ± 0.045 at 0.1 pitch: disjoint | tie-break never applies; 0.01 gap is empty space |
| `clock.show` "ticks 1 … 48" | declared range 0 … 60, 0 and 49 … 60 refused `r02-g21.tick` | gestures send only 1 … 48 |
| the panel's phase −/+ "by g" | `phase(moved:)` wraps cyclically over 0 … 47 | unchanged; direct "Set phase" added |
| the kernel's "pure change rule" | `BinaryGardensSky.changed` is internal | callable from the Core's preview; no kernel API change |
| the 503 experience | committed and recorded (R02-G21-03 pass); no `pointer` override | this feature starts after R02-G21-03 is recorded |
