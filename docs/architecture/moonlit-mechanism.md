# Moonlit Mechanism (R02-G14) — rules

Experience `r02-g14.moonlit-mechanism` (free) of the one VisualCore app; package `Packages/ExperiencesRound02`, target
`MoonlitMechanismCore` (feature 431, R02-G14-01). A train of interlocking gears stands in front of a lamp; each gear
carries open and solid blades whose shadows fall on a paper wall. Turning the handle turns the whole train; re-seating a
gear shifts it by one tooth against its neighbours; raising or lowering the lamp moves every shadow by its gear's depth.
The wall shows a sequence of key frames, each with a target symbol. A run steps the machine through the key frames and
wins when every meshing pair is aligned, every required key frame's target is covered within the stray allowance and no
key frame shadows a forbidden cell. Everything here is pure, exact integer logic; drawing, controls and sound come in
later features of R02-G14.

## Gears, the train and the wall

- **Gears.** 2 … 5; gear 0 is the driver; every other gear meshes with exactly one lower-index parent, so the train is a
  tree. Each gear has 6 … 20 teeth, a starting phase in whole teeth, a blade pattern (one bit per slot, at least one
  solid and one open), a depth 1 … 3, a centre on the wall and a slot table (per slot, the wall-cell offsets, within ±8,
  that a solid blade at that slot covers).
- **Meshes.** A pair (parent p, child c) has the divisor g = gcd(Tₚ, T_c), at least 2, and an alignment value a below
  it; the pair is aligned when (phaseₚ + phase_c) mod g = a. Its angular relation error is the cyclic distance from
  alignment (0 … ⌊g / 2⌋).
- **Wall.** W 8 … 24 × H 6 … 16 cells, numbered row by row; 2 … 5 lamp heights with a starting height.
- **Key frames.** 2 … 6, each with a handle-turn count (strictly increasing, the first ≥ 0), a non-empty target and a
  required flag (at least one required); 0 … 12 forbidden cells, disjoint from every target; a stray allowance 0 … 4;
  an action budget 1 … 40.

## Turns, re-seats, the lamp and shadows

- **Turn.** A gear's direction is +1 at an even distance from the driver and −1 at an odd one; a turn of ±1 moves every
  gear to (phase + direction · step) mod T. Meshing gears move by +s and −s, so a turn never changes an alignment.
- **Re-seat.** Moves one gear (never the driver) by ±1 tooth; it can break the alignment with its parent and children.
- **Lamp.** Steps the height by ±1 within range.
- **Shadow.** The blade at bit b of a gear at phase q sits at slot (b + q) mod T; a solid blade covers its slot's
  offsets from the gear's centre, moved down by height · depth rows (the light matrix as an integer shift that grows with
  depth); cells off the wall are dropped. A key frame's shadow is the union over every gear at the set-up's phases
  turned by the key frame's turns.

## Runs, failures and the truth metric

A run (one action) first checks every mesh in child order and is `jammed` by the first misaligned pair; it then walks
the key frames in order: a shadow on a forbidden cell fails `forbidden` (the lowest-numbered cell) at any key frame; at
a required key frame uncovered target cells fail `missing` and more stray cells than the allowance fail `stray`;
otherwise the level is won. After any other action, a budget fully spent without a win fails `budget`. The truth metric
— every pair's alignment error and every key frame's covered, missing, stray and forbidden counts — is reported after
every action (`MoonlitMechanismRunReport`) and never decides on its own.

## Play, records and the puzzle contract

The play (`MoonlitMechanismPlay`) follows loading → tutorial (when the level has one) → playing ⇄ paused → won or
failed → result. Actions are validated in the order stage, previous fingerprint, action (`r02-g14.stage`,
`r02-g14.stale`, `r02-g14.action`); every accepted action appends a record with previous and next fingerprints (SHA-256
of the schema, the level fingerprint, the phases, the lamp height, the actions spent, the stage and the failure). Undo
and redo restore exact states; undo from failed returns to playing (an honest retry, recorded); a won level is final.
A trace replays to the same states. Levels are JSON schema 1 with sorted keys and a fingerprint, re-checked on decode
(`r02-g14.level`, `r02-g14.newer-schema`, `r02-g14.malformed`). `MoonlitMechanismRules` expresses the rules as an
R02-F23 `PuzzleRules` (moves in the order turn −1, +1; every re-seat by gear, −1 then +1; lamp −1, +1 in range; run) for
the level certification of R02-G14-02.

## Content pipeline (feature 432, R02-G14-02)

- **Manifest.** The 100 planned levels of the archived design (`MoonlitMechanismManifest`): number, planned seed, band
  1 … 5 (20 each) and moves budget 8 … 19.
- **Generator.** Candidate c of entry n draws from `SeededRandom(seed: SeedDerivation.derive(plannedSeed, index: c))` and
  is built from a solution: a wall of 12 … 16 × 9 … 12 cells, the gear count and lamp heights by band (2 … 3 gears with
  2 … 3 heights up to 4 … 5 with 4 … 5), parents and tooth counts with a mesh divisor of at least 2, a solution set-up,
  blade patterns, depths, centres and slot tables (compass rays of 2 … 3 cells), alignment values taken from the
  solution, 2 … 5 key frames by band whose targets are the solution's casts, 2 … 6 forbidden cells outside every cast,
  and a scramble of 2 … 3 up to 7 … 9 random accepted actions that gives the start. Tutorial on levels 1 … 3. A
  candidate is kept when its start does not win and its minimal plan lies in the band's range (1 … 2 up to 5 … 6
  actions) and below the budget; at most 256 candidates (`r02-g14.generation`). The ranges were measured with a
  prototype on the real kernel before they were written down; over the catalog the band means are 1.90, 2.50, 3.50,
  4.50 and 5.30 actions.
- **Minimal plan and proof.** Actions commute, so a plan is a vector (net turns, net lamp steps, each gear's net
  re-seat) and its length is the vector's L1 norm. `MoonlitMechanismSolver.plan` tries the vectors by norm in a fixed
  order, skips those that leave the lamp out of range or a mesh misaligned (turns never change an alignment, and a
  jammed machine never wins), runs the kernel on the rest and returns the first winner; the vectors of smaller norms
  are the minimality proof. Work (runs) is bounded at 400,000; the largest catalog plan used 174 runs.
- **Witness files.** `docs/games/moonlit-mechanism/levels/NNN.witness.json` (schema 1, sorted keys): the level, the
  actions (turns, re-seats in gear order, lamp steps, then the run), a state digest of the phases and lamp height after
  each action, the play fingerprints, the counterexample (the norm one below the plan and the vectors of that norm
  tried, none winning), the difficulty and the candidates skipped. Regenerated only with
  `MOONLIT_MECHANISM_WRITE_WITNESSES=1`; decoding re-runs the replay and the solver (`r02-g14.witness`).
- **Catalog.** `PuzzleCatalog<MoonlitMechanismRules>.digest(id: "moonlit-mechanism", …)` over the 100 fingerprints is
  pinned; the standard progression rule holds on the witness action count; an independent breadth-first search through
  the play re-checks minimality on the two levels with the fewest gears in each band.

## Hero renderer and experience (feature 433, R02-G14-03)

- **Scene.** The paper wall is the plane z = −0.6; its cell size is s = min(1.8 / W, 1.2 / H) and cell (c, r) is
  centred at x = (c − (W − 1)/2)·s, y = 0.65 − (r − (H − 1)/2)·s. In painter's order (depth testing off): the night
  backdrop, the paper, the ink feathers (soft-edge tiers), the shown key frame's cast cells as ink squares of side
  0.92 s (the kernel's cast, never recomputed), the target borders, the missing cells dotted, the stray cells hatched,
  the forbidden cells crossed, the gauges (one key-frame card per key frame with its covered share lit and a gold border
  when required, one alignment pip per mesh, the moves bars), the gears back to front by depth (a translucent gold body,
  a toothed rim of radius 3.4 s with T teeth, the tooth-zero notch and the blade spokes at the drawn phases), the lamp's
  height ladder and the lamp at y = 1.30 + 0.03·height. Gears stay on their centre cells; the lamp moves only their
  shadows, as the kernel casts them (`MoonlitMechanismSceneGeometry`).
- **Shading.** Two GLSL ES 3.00 programs (`MoonlitMechanismShaders`): the clockwork program selects one of 22 material
  codes from uv.x and shades signed-distance edges from the local coordinate in uv.y; every material is emissive at its
  palette colour (night #070A14, paper #E8DFC8, ink #1A1822, gold #C9A24A, rim #E2C277, blade #B08A3C, lamp #8FB4E8).
  A won level brightens the paper through `u_won` without moving anything; a failure outlines the jammed teeth, the
  forbidden cell or the failing card in the broken colour. The glow program draws the shells additively and last; its
  gain is clamped by `u_glowLimit`.
- **Tiers.** level-0: 6 outline segments per tooth, soft edges, two glow shells; level-1: 4, soft edges, one shell;
  level-2: 2, hard edges, none. Positions of cells, gears and gauges are the same at every tier; the presenter logs tier
  changes with their reason.
- **Camera.** A fixed authored view from eye (0, 0.65, 2.4) towards (0, 0.55, −0.3), fitted to the box
  x −0.95 … 0.95, y −0.45 … 1.5, z −0.6 … 0.4 with a 6 % margin per side for aspects 0.4 … 2.5.
- **Adapter.** `MoonlitMechanismExperienceCore` opens certified level (seed mod 100) + 1 from its table of each witness's
  skipped candidate and accepts `handle.turn` [±1], `gear.reseat` [gear, ±1], `lamp.step` [±1], `machine.run`,
  `play.undo`, `play.redo`, `level.next` and `frame.show` [key frame] (presentation only: it changes the shown key frame,
  never the play); its digest ("r02-g14.moonlit-mechanism.v1") is the level number, the shown key frame and the play
  fingerprint; snapshot schema 1. The renderer reads only an immutable `MoonlitMechanismSceneSnapshot`, so nothing drawn
  can change the game (renderer purity).
- **Fallback and settings.** A shader failure draws the level-2 geometry unlit with the shared mesh renderer and keeps
  the reason; Reduce Motion draws the gears at the set-up phases of the shown key frame without a turning preview;
  Reduce Flashing caps the glow. Neither program has a time input, so meshes are rebuilt only when what they read
  changes. The presenter declares two frame probes (the top-left and bottom-right night corners) for the X gates.
- **Candidate.** Registered in `Catalog/registrations.json` (100 levels, digest 7de63603…9744) and linked into the app
  as a candidate (`ExperienceRegistry.candidates`) until X-R02-G14; the scenario manifest holds the standard scenarios,
  `full-playthrough`, `hero`, 80 acceptance scenarios and the fixtures.

## Gestures (feature 434, R02-G14-04)

- **Picking.** `MoonlitMechanismPicker` projects the targets through the drawn camera (orbit included) into view points:
  the lamp (centre within 22 points) or its ladder (within 22 points of the segment from the bottom rung to the top
  rung), then a key-frame card (inside its projected rectangle or its centre within 22 points; the nearest centre, ties
  to the lower index), then a gear (inside its projected outline circle of radius 3.75 s, the largest of eight projected
  directions, grown by 8 points; the front-most, drawn last, first); anything else is empty space.
- **Gestures.** `MoonlitMechanismGestureController` takes the host's pointer events with the view size and the drawn
  snapshot. A tap is below 10 points and lifted within 0.5 s; a drag moves at least 16 points. A gear drag accumulates
  the clockwise swept angle about the gear's projected centre (samples within 12 points skipped, wrap-around unwrapped)
  and turns the train by n = round(swept ÷ one tooth) handle turns of step direction(gear) × sign(n), capped at the
  actions left, so the dragged gear follows the finger tooth for tooth; a vertical lamp drag steps the lamp one rung per
  24 points. A gear tap chooses the gear; a double tap re-seats it by +1 (never the driver, which says why); a card tap
  shows its key frame; a lamp tap runs; a double tap on empty space resets the view. Pending turns and lamp steps are
  shown in words while dragging and sent on release, one action per step. Gestures send kernel actions only while
  playing; on a finished play the description says the play is over.
- **Orbit.** Two fingers orbit: yaw ±25° (90° per view width) and pitch −10° … +15° (60° per view height) about the
  authored view; the field of view refits so the authored box keeps a 5 % margin at every orbit and aspect 0.4 … 2.5.
  Orbit is presentation only: not saved, not in the digest; only the camera follows it, never the meshes.
- **Panel.** Every move remains on the panel ("Reset view" added); all 100 certified levels are won through panel
  actions alone (`MoonlitMechanismPanelWinTests`). Refusals are shown in words and their codes kept, with or without the
  engine's `action.rule.` prefix.
