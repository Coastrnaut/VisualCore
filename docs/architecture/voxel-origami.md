# Voxel Origami (R02-G15) — rules

Experience `r02-g15.voxel-origami` (free) of the one VisualCore app; package `Packages/ExperiencesRound02`, target
`VoxelOrigamiCore` (feature 441, R02-G15-01). A chain of luminous cubes is joined by hinges; each hinge turns in quarter
turns and swings every cube beyond it to a new place on the cube lattice. The level is won when the cubes occupy
exactly the cells of the target solid, in any orientation the level allows and anywhere in space; a turn that would
put a cube inside another, or drag one through another, fails. Everything here is pure, exact integer logic; drawing,
controls and sound come in later features of R02-G15.

## Cubes, hinges and poses

- **Cubes.** 4 … 12; cube 0 is the root, fixed at cell (0, 0, 0) with the identity orientation; every other cube i is
  attached face to face to a lower-index parent p(i) along a rest direction d(i), one of ±x, ±y, ±z, given in the
  parent's frame. The joint is hinge i, with a quarter turn q(i) in 0 … 3 (0°, 90°, 180°, 270°) and a starting value.
- **Poses.** Computed from the root with the 24 rotation matrices of the cube (entries −1, 0, 1):
  x(i) = x(p) + O(p) · d(i) and O(i) = O(p) · R(d(i), q(i)), R being quarter turns counter-clockwise by the right-hand
  rule. A turn of hinge i therefore twists everything beyond cube i about the line from p(i) through i: cube i spins in
  place, its descendants swing, and the pair stays face to face, so the tree can never come apart.
- **Idle hinges.** A hinge with no descendant off its axis (a leaf, or a straight run along the axis) would move
  nothing and is refused (`r02-g15.action`).

## Collisions and the sweep

The turning body is cube i and its subtree; every other cube stands still. A turn first checks the end pose: a swinging
cube landing on a still cube's cell fails `collision` (the lowest such swinging cube, the still cube and the cell).
It then checks the sweep: each swinging cube's centre traces an open quarter arc of radius ρ around the axis; a still
cube in the same layer blocks when that arc passes strictly within one cell of its centre in both in-plane coordinates
(inside the open square of half-side 1 around it), which fails `sweep`. The decision is exact: the square is clipped to
the arc's 90° wedge, and the arc enters it exactly when the clipped polygon's least squared distance from the axis is
below ρ² and its greatest above ρ², every coordinate a rational number of small integers. A cube may neither pass
through nor clip a cube that does not turn with it, its parent on the axis included. A failed turn leaves the pose as it
was. (The first rule, a band around the arc inside the arc's box, let a cube orbit through its parent at ρ = 1; an
independent 1 000-step sampling of the arc found it during implementation, and the rule above agrees with that sampling
in every unambiguous case.)

## Matching and the truth metric

The target is a set of n distinct cells. The level allows the orientations `fixed` (the identity), `upright` (the 4
quarter turns about +y) or `any` (the 24 rotations; never a mirror image). The canonical form of a cell set is the
smallest sorted cell list among its allowed rotations, each translated so its smallest x, y and z are 0; its hash is the
SHA-256 of that list's text. After every accepted turn the level is won when the occupied cells' canonical form equals
the target's; otherwise a budget (1 … 40) fully spent fails `budget`. The truth metric — occupancy, the canonical hash
and the covered count (the most cubes one allowed rotation and translation of the target covers) — is reported after
every action (`VoxelOrigamiShapeReport`) and never decides on its own.

## Play, records and the puzzle contract

The play (`VoxelOrigamiPlay`) follows loading → tutorial (when the level has one) → playing ⇄ paused → won or failed →
result. Turns are validated in the order stage, previous fingerprint, action (`r02-g15.stage`, `r02-g15.stale`,
`r02-g15.action`: an unknown hinge, a step other than ±1, an idle hinge); every accepted turn spends one action and
appends a record with previous and next fingerprints (SHA-256 of the schema, the level fingerprint, the quarter turns,
the actions spent, the stage and the failure). Undo and redo restore exact states; undo from failed returns to playing
before the failing turn and refunds its action (recorded); a won level is final. A trace replays to the same states.
Levels are JSON schema 1 with sorted keys and a fingerprint, re-checked on decode (`r02-g15.level`,
`r02-g15.newer-schema`, `r02-g15.malformed`). `VoxelOrigamiRules` expresses the rules as an R02-F23 `PuzzleRules`
(moves: every hinge that would swing a cube, ascending, then −1, +1) for the level certification of R02-G15-02.

## Levels, the solver and witness files (feature 442, R02-G15-02)

- **Manifest.** The 100 planned levels of the archived design (`VoxelOrigamiManifest`): number, seed, band 1 … 5 (20
  each), moves budget 8 … 19 and control emphasis; the emphasis chooses the orientations (`rotate assembly` → `any`,
  `lock shape` → `fixed`, the others → `upright`).
- **Generator.** Candidate c of an entry draws from `SeedDerivation.derive(seed, index: c)`: the cube count by band
  (5 … 6, 6 … 7, 7 … 8, 8 … 9, 9 … 10), a hinge tree with a collision-free rest pose (redrawn up to 50 times), a
  collision-free solution pose, the target (the solution's cells under a drawn allowed rotation and a drawn shift), and a
  scramble of clear turns by band (2 … 4, 4 … 6, 6 … 9, 8 … 12, 10 … 14) that gives the start. The first candidate whose
  minimal plan lies in its band's range (1 … 2, 2 … 3, 3 … 4, 4 … 5, 5 … 6 turns) is kept; at most 256, then
  `generation(n)`. The ranges were measured by a prototype on the real kernel first; the catalog needs at most 58
  candidates per entry and 4 640 turns tried.
- **Solver.** A breadth-first search over quarter-turn states (the exact case of the catalog's A-star): states expanded
  in the order reached, moves in hinge order, −1 then +1, each move filtered by the kernel's collision and exact sweep
  rule, states merged by their quarter turns; the first matching state is the plan, and every state reached at a
  smaller depth (counted) is the proof that nothing shorter matches. Work is bounded at 300 000 turns tried.
- **Witness files.** `docs/games/voxel-origami/levels/NNN.witness.json` (schema 1): the level, the turns, a state digest
  after every turn, the play fingerprints, the counterexample (the depth below the plan and its states, none matching),
  the difficulty and the candidates skipped; decoding re-checks everything by replay. The catalog digest over the 100
  level fingerprints is pinned, R02-F24's progression rule holds on the witness turn count, and a depth-first
  enumeration on the two levels with the fewest cubes per band confirms the minima.

## Hero renderer and experience (feature 443, R02-G15-03)

- **Scene.** Cell c is drawn at w(c) = (c − m)·s, with m the centre of the bounding box of the occupied cells and the
  target cells at the best allowed alignment (the rotation and translation of the kernel's covered count) and
  s = 1.5 / (e + 1) for the box's largest extent e. Painter's order by distance from the eye, farthest first, ties by
  kind (target outline, cube, hinge, pip, bar) then index, with depth testing off and back faces culled: the night
  backdrop, one wireframe cube of side 0.96 s per target cell, chamfered cubes of side 0.9 s at the kernel's cells turned
  by their orientations (an inner glyph on each face, solid on a target cell and hollow elsewhere, and (index mod 6) + 1
  dots on the cube's +z face), hinge marks 0.6 s × 0.12 s along the parent-to-cube axis (the chosen hinge striped hot
  pink), covered pips at y −1.05 and moves bars at y −1.2 (`VoxelOrigamiSceneGeometry`). A hinge mark sits on the face
  between its two cubes, lifted 0.55 s along the view ray towards the eye: it projects to the same point and is painted
  after both cubes, which would otherwise hide it.
- **Shading.** Two GLSL ES 3.00 programs (`VoxelOrigamiShaders`): the voxel program selects one of 14 material codes from
  uv.x and shades signed-distance edges from the local coordinate in uv.y; cube faces and bevels are frosted ivory
  (#EDE8DC toward #B9B2A3) lit from the face normal, every other material is emissive at its palette colour (night
  #0B0D16, turquoise #2EE6D6, hot pink #FF3C8C). A won level flares the target and lifts the cubes toward white through
  `u_won` without moving anything; a failure outlines the moving cube and the cube in its way in #FF6B4A and crosses the
  cell. The glow program draws the shells around lit cubes and target cells additively and last; its gain is clamped by
  `u_glowLimit`.
- **Tiers.** level-0: two bevel steps, edges 0.06 s, two glow shells; level-1: one step, 0.05 s, one shell; level-2: no
  bevel, 0.04 s, none. Positions are the same at every tier; the presenter logs tier changes with their reason.
- **Camera.** A fixed authored three-quarter view from eye (1.4, 1.1, 2.6) towards (0, −0.1, 0), fitted to the box
  x −0.95 … 0.95, y −1.25 … 0.95, z −0.95 … 0.95 with a 6 % margin per side (at least the specified 5 %) for aspects
  0.4 … 2.5.
- **Adapter.** `VoxelOrigamiExperienceCore` opens certified level (seed mod 100) + 1 from its table of each witness's
  skipped candidate and accepts `hinge.turn` [hinge, ±1], `play.undo`, `play.redo`, `level.next` and `hinge.choose`
  [hinge] (presentation only: a level opens with its first turnable hinge chosen); its digest
  ("r02-g15.voxel-origami.v1") is the level number and the play fingerprint, never the chosen hinge; snapshot schema 1
  `{level, records}`. The renderer reads only an immutable `VoxelOrigamiSceneSnapshot`, so nothing drawn can change the
  game (renderer purity).
- **Fallback and settings.** A shader failure draws the level-2 geometry unlit with the shared mesh renderer and keeps
  the reason; Reduce Motion draws the chain still at presentation time 0; Reduce Flashing caps the glow. Neither program
  has a time input, so meshes are rebuilt only when what they read changes. The presenter declares two frame probes (the
  top-left and bottom-right night corners) for the X gates.
- **Candidate.** Registered in `Catalog/registrations.json` (100 levels, digest b02e58ec…f611) and linked into the app as
  a candidate (`ExperienceRegistry.candidates`) until X-R02-G15; the scenario manifest holds 9 standard scenarios,
  `full-playthrough`, `hero`, 80 acceptance scenarios (R2-G15-QA-001 … 080) and 3 fixtures.

## Gestures and camera (feature 444, R02-G15-04)

- **Picking.** At touch-down every cube's eight corners (side 0.9 s, turned by its orientation) are projected through the
  drawn camera; a touch inside their convex outline, or within 8 points of it, hits the cube, and the front-most hit
  (the one the paint order draws last) wins (`VoxelOrigamiPicker`). Target wireframes, hinge marks, gauges and the
  backdrop are empty space; cube 0, the root, has no hinge.
- **Drag to turn.** Hinge h twists the subtree of cube h about the line from its parent, so cube h itself never moves.
  A drag on cube h follows its tracked cube: of the cubes hinge h swings, the one farthest from the hinge line (lowest
  index on ties; the centroid of a subtree symmetric about the line would not move). Its projected motion for a `+1` and
  a `−1` quarter turn gives two screen directions; the step whose direction has the larger projection of the finger's
  travel is pending from 24 points and sent on release as one `hinge.turn` — one quarter turn per drag
  (`VoxelOrigamiTurnPrediction`).
- **Taps.** A tap on a non-root cube chooses its hinge (`hinge.choose`, presentation only); a second tap on the same
  cube within 0.35 s and 22 points while playing turns it `+1`, or explains that nothing would move; two taps on empty
  space reset the view. Drags from the root, from an idle hinge or on a finished play explain why once and send nothing
  (`VoxelOrigamiGestureController`, thresholds as Moonlit Mechanism's: tap below 10 points and 0.5 s, drag from 16).
- **Orbit.** Two fingers orbit: yaw ±60° about the vertical axis through the box centre (90° per view width) and pitch
  −20° … +35° (60° per view height); a third finger re-bases the midpoint; "Reset view" or an empty double tap returns
  to the authored view. The camera refits so the box stays inside the view at every orbit and aspect, the eye outside
  the box; the meshes face the drawn eye, so an orbit change rebuilds them (a resize alone does not). Orbit, the chosen
  hinge and the pending turn are not saved (schema 1).
- **Panel.** Every move stays available without gestures (hinge − and +, turn − and +, undo, redo, next level, "Reset
  view"); all 100 certified levels are won through the panel alone in the host tests. Refused actions are shown in words
  and logged with their codes.

