# Starlit Cartouche (R02-G16) — rules

Experience `r02-g16.starlit-cartouche` (free) of the one VisualCore app; package `Packages/ExperiencesRound02`, target
`StarlitCartoucheCore` (feature 451, R02-G16-01). A ship waits at a star of a drifting star chart and flies corridors
between stars; each leg draws a stroke of light between the two stars' points on a cartouche, an ancient symbol drawn
as strokes. The level is won when the trail has drawn exactly the symbol's strokes and the ship rests at the beacon in
time; a leg that crosses a hazard tube, misses a star's time window, strays off the symbol or arrives after the
deadline fails. Everything here is pure, exact integer logic on beats (one quantized launch tick, 30 presentation
ticks of 0.008333 s); drawing, controls and sound come in later features of R02-G16.

## Stars, orbits and corridors

- **Stars.** 4 … 12; star i cycles through an orbit of 1 … 4 lattice positions (coordinates −8 … 8), sitting at
  orbit[b mod length] at beat b, and has a glyph point on the 5 × 5 cartouche grid, distinct from every other star's,
  and a time window [open, close] with 0 ≤ open ≤ close ≤ 64.
- **Corridors.** At most 24 undirected corridors, each joining two different stars once, with a travel time of 1 … 3
  beats. A corridor is flyable at beat b when its stars' squared distance at b is at most r², r the level's range
  (1 … 12), so a leg may have to wait for its stars to drift close.
- **Hazard tubes.** At most 8; each names a corridor and a closed beat interval [from, to] during which it blocks it.

## Legs, failures and the win

The ship starts at the start star at beat 0 (its window contains 0). `leg(j, w)` waits w beats (0 … 8), departs at
t₀ = t + w along the corridor to j and arrives at t₁ = t₀ + travel. It is refused (`r02-g16.action`) for an unknown
star, the ship's own star, no corridor, a wait out of range and stars out of range at t₀. Otherwise it spends one action
and fails, in this order: `window` when t₀ is after the close of the star left, `hazard` when a hazard on the corridor
meets [t₀, t₁] (the lowest such hazard), `window` when t₁ is outside j's window, `deadline` when t₁ is after the level's
deadline (1 … 64) and `stroke` when the corridor is not one of the symbol's 1 … 12 strokes. A failed leg leaves the
route as it was. After an accepted leg the level is won when the drawn corridors equal the symbol (a retraced stroke
counts once) and the ship is at the beacon; otherwise a budget (1 … 16) fully spent fails `budget`. (Windows first had
to close by the deadline, which made the deadline failure unreachable; the chart tests found it during implementation,
and windows now close by beat 64.)

## The truth metric

After every action (`StarlitCartoucheRouteReport`): the ship's star and beat, the strokes drawn, the missing strokes,
the stray strokes, the glyph mismatch (missing + stray) and the hazard clearance (the fewest beats between a flown leg
and a hazard on its corridor, nil when none shares a flown corridor). It never decides on its own.

## Play, records and the puzzle contract

The play (`StarlitCartouchePlay`) follows loading → tutorial (when the level has one) → playing ⇄ paused → won or
failed → result. Legs are validated in the order stage, previous fingerprint, action (`r02-g16.stage`,
`r02-g16.stale`, `r02-g16.action`); every accepted leg appends a record with previous and next fingerprints (SHA-256 of
the schema, the level fingerprint, the ship's star and beat, the drawn strokes, the legs flown, the actions spent, the
stage and the failure). Undo and redo restore exact states; undo from failed returns to playing before the failing leg
and refunds its action (recorded); a won level is final. A trace replays to the same states. Levels are JSON schema 1
with sorted keys and a fingerprint, re-checked on decode (`r02-g16.level`, `r02-g16.newer-schema`,
`r02-g16.malformed`). `StarlitCartoucheRules` expresses the rules as an R02-F23 `PuzzleRules` (moves: every corridor
from the ship's star in index order, waits 0 … 8, flyable ones only) for the level certification of R02-G16-02.

## Levels, the solver and witness files (feature 452, R02-G16-02)

- **Manifest.** The 100 planned levels of the archived design (`StarlitCartoucheManifest`): number, seed, band 1 … 5
  (20 each), action budget 8 … 19 and control emphasis. The level's budget bound was widened from 1 … 16 to 1 … 24 for
  these budgets.
- **Generator.** Candidate c of an entry draws from `SeedDerivation.derive(seed, index: c)`: the star count (band + 4 …
  band + 5), glyph points (redrawn until distinct) and orbits of 1 … 3 positions with coordinates −5 … 5, the range
  (6 … 8), the start star, a route of band + 1 … band + 2 legs (each up to 8 draws of a next star, taking the first
  flyable wait from a drawn offset), band + 1 decoy corridors, hazards (band + 2 for `avoid hazard`, else 0 … band,
  dropped when they meet a route leg), the deadline (the last arrival plus 0 … max(0, 5 − band)) and the windows
  (tight on every visited star for `time launch`, else on a visited star with a 1 in 3 draw). The symbol is the route's
  corridors and the beacon its last star. The first candidate whose minimal plan lies in its band's range (b + 1 …
  b + 2 legs) and within the budget is kept; at most 256, then `generation(n)`. The ranges were measured by a prototype
  on the real kernel first; the catalog needs at most 3 candidates per entry and 19 792 legs tried.
- **Solver.** A breadth-first search over (star, beat, strokes drawn) states: states expanded in the order reached, legs
  by corridor index from the ship's star then wait 0 … 8, each leg filtered by the chart (refusals and failures, so a
  stray stroke is never flown), states merged; the first winning leg ends the search and every state reached at a
  smaller depth (counted) is the proof that nothing shorter wins. Work is bounded at 300 000 legs tried and 7 legs.
- **Witness files.** `docs/games/starlit-cartouche/levels/NNN.witness.json` (schema 1): the level, the legs, a state
  digest after every leg (the first 16 hex of SHA-256 of `star=…;beat=…;drawn=…`), the play fingerprints, the
  counterexample (the depth below the plan and its states, none winning), the difficulty and the candidates skipped;
  decoding re-checks everything by replay and by re-solving (`r02-g16.witness`). The catalog digest over the 100 level
  fingerprints is pinned, R02-F24's progression rule holds on the witness leg count, and a depth-first enumeration on
  the two levels with the fewest stars per band confirms the minima.

## Hero renderer and experience (feature 453, R02-G16-03)

- **Scene.** A lattice position v is drawn at w(v) = (v − m)·s, with m the centre of the bounding box of every orbit
  position of every star (so no star leaves the frame at any beat) and s = 1.5 / (e + 1) for the box's largest extent
  e; stars are drawn at their kernel positions for the current beat. Painter's order by distance from the eye,
  farthest first, ties by kind (corridor, hazard, trail, failed leg, star, ship, beacon, chosen ring, cartouche, actions
  bar, beat track, wait pip) then index, with depth testing off (`StarlitCartoucheSceneGeometry`): the firmament quad,
  corridor ribbons 0.02 wide (undrawn symbol strokes dashed pearl), hazard tubes 0.06 wide (striped, coral while
  active), meteor-gold trail ribbons 0.05 wide from each leg's departure to its arrival position with motion-blur
  ghosts, pearl star spheres of radius 0.07 with rings of (index mod 6) + 1 notches, the sapphire ship arrow (0.14 long,
  along its newest trail), the beacon ring (0.12) and the chosen destination's dashed ring (0.1), and the gauges below
  the chart: the cartouche (a 5 × 5 grid 0.5 wide at (−0.5, −1.2), each symbol stroke a line between its stars' glyph
  points, dashed until drawn), the actions bars at y −1.05, the beat track at y −1.2 (filled to beat / deadline) and nine
  wait pips at y −1.35.
- **Shading.** Two GLSL ES 3.00 programs (`StarlitCartoucheShaders`): the chart program selects one of 22 material
  codes from uv.x and shades from the local coordinate in uv.y and the normal slot — layered star shading (core, limb,
  corona), signed-distance dashes, stripes, notches, rings and the ship's dart, and the firmament (a gradient from
  #0A1240 to #141E5C with hashed specks under 5 % of its pixels, turned by `u_firmamentAngle`, 0.02 rad/s of
  presentation time, 0 under Reduce Motion). A won level brightens the trails and drawn strokes and seals the cartouche
  in gold through `u_won` without moving anything; a failure draws the failed leg (recomputed through the chart from
  the last record's action) in #FF6B4A and marks the star, hazard, stray stroke, beat track or actions bars it names.
  The glow program draws shells around stars, the ship and lit trails additively and last; its gain is clamped by
  `u_glowLimit`.
- **Tiers.** level-0: spheres of 16 × 12 segments, three trail ghosts, two glow shells; level-1: 12 × 8, one ghost, one
  shell; level-2: flat 12-sided discs, no ghosts, no glow. Positions are the same at every tier; the presenter logs tier
  changes with their reason.
- **Camera.** A fixed authored three-quarter view from eye (1.2, 1.0, 2.8) towards (0, −0.2, 0), fitted to the box
  x −0.95 … 0.95, y −1.45 … 0.95, z −0.95 … 0.95 with a 6 % margin per side (at least the specified 5 %) for aspects
  0.4 … 2.5.
- **Adapter.** `StarlitCartoucheExperienceCore` opens certified level (seed mod 100) + 1 from its table of each
  witness's skipped candidate and accepts `route.fly` [star, wait], `play.undo`, `play.redo`, `level.next` and
  `route.choose` [star, wait] (presentation only; the choice resets at opening and after every leg to the other end of
  the lowest-index corridor from the ship's star with wait 0; refusals `r02-g16.choice` and `r02-g16.not-whole`); its
  digest ("r02-g16.starlit-cartouche.v1") is the level number and the play fingerprint, never the choice; snapshot
  schema 1 `{level, records}`. The renderer reads only an immutable `StarlitCartoucheSceneSnapshot`, so nothing drawn
  can change the game (renderer purity).
- **Fallback and settings.** A shader failure draws the level-2 geometry unlit with the shared mesh renderer and keeps
  the reason; Reduce Motion stops the firmament and the ship's 0.5 s glide along its newest trail; Reduce Flashing caps
  the glow. The firmament turns by a uniform, so meshes are rebuilt only when what they read changes. The presenter
  declares two frame probes (the top-left and bottom-right firmament corners) for the X gates.
- **Candidate.** Registered in `Catalog/registrations.json` (100 levels, digest ee022539…969e) and linked into the app
  as a candidate (`ExperienceRegistry.candidates`) until X-R02-G16; the scenario manifest holds 9 standard scenarios,
  `full-playthrough`, `hero`, 80 acceptance scenarios (R2-G16-QA-001 … 080) and 3 fixtures. Spending the whole budget
  is possible on only 17 of the 100 levels (each leg advances the beat into windows and the deadline), so the failure
  fixture and the even witness rows end on a failing leg.

