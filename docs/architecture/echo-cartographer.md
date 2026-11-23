# Echo Cartographer (R02-G11) — rules

Experience `r02-g11.echo-cartographer` (free) of the one VisualCore app; package `Packages/ExperiencesRound02`, target
`EchoCartographerCore` (feature 401, R02-G11-01). The player stands in a dark chamber of which only the entry is known.
Pulses sent from known open cells reveal the walls they strike and the floor they cross, and the hidden beacons answer
with echoes whose delays tell how far each one is along the open floor. From echoes taken at several cells the player
works out where every beacon must be and claims it, before the energy runs out. Everything here is pure, exact integer
logic; drawing, controls and sound come in later features of R02-G11.

## Chamber, rays and echoes

- **Chamber.** A grid of W × H cells (W, H 5 … 16); cell (x, y) has the index y · W + x; every cell is open or a wall
  (a whole unit square), and the border counts as a wall (`EchoCartographerChamber`). The entry is an open cell; 1 … 4
  beacons sit on distinct open cells other than the entry, each reachable from the entry by side steps through open
  cells.
- **Knowledge.** What the player knows of each cell: unknown, open or wall. It starts with only the entry open and only
  grows (`EchoCartographerKnowledge`).
- **Pulse.** From a cell known open, four rays in the order north (−y), east (+x), south (+y), west (−x). A ray steps
  cell by cell; every open cell it enters becomes known open and the first wall cell it enters becomes known wall (at
  the border nothing more is revealed). Its travel distance is the number of steps to the struck wall or border (1 when
  the neighbour is a wall).
- **Echoes.** Each beacon answers with its path length: the fewest side steps through open cells from the emitter (0 on
  the emitter), by breadth-first search. The echoes are reported sorted, without naming the beacon.
- **Delays.** Every ray and echo has a round-trip delay of 24 ticks of 0.008333 s per cell of distance (12 each way);
  delays animate the echoes in later features and never decide a rule.

## Actions and verdict

`pulse(x, y)` costs 1 energy. `claim(x, y)` locates the not-yet-located beacon within the level's tolerance (0 … 2 cells,
the larger of the column and row differences) that is nearest, then in the lowest row, then the lowest column; a hit
is free and makes the beacon's cell known open. A claim with no beacon within the tolerance is a miss: it costs the
level's miss cost (1 … 3), never more than the energy left, and reveals nothing. `mark(x, y)` toggles a free marker
(at most 8) that the player uses to triangulate; markers never decide anything. Refused without change: a cell outside
the chamber, a pulse from a cell not known open, a claim on a known wall, a ninth marker (`r02-g11.action`); a claim
within the tolerance only of beacons already located (`.noop`); the wrong stage (`.stage`) and a stale fingerprint
(`.stale`). After an accepted action, in this order: **win** (every beacon located, whatever energy is left), then
**energy** (energy zero with a beacon still hidden: failed, naming the action). Undo and redo spend nothing and restore
the exact earlier state, energy and knowledge included; undo from failed returns to playing; a won level is final.

## Measures

After every action the play reports each located beacon's localization error (the column-or-row distance between the
claim and the beacon) and their total, beside the last pulse's report; they never decide the outcome. Every ray and
echo distance agrees with an independent recomputation in the tests.

## Stored form

Levels are JSON schema 1 with sorted keys (width, height, walls and beacons as sorted cell indices, entry, tolerance,
energy, miss cost, difficulty, tutorial, seed, id) and their fingerprint; decoding re-checks every rule and the
fingerprint and refuses damaged, edited and newer forms (`r02-g11.malformed`, `.newer-schema`).

## Content pipeline (feature 402, R02-G11-02)

- **Manifest.** The 100 planned levels of the archived design (`EchoCartographerManifest`): number, planned seed, band
  1 … 5 (20 each) and energy 8 … 19.
- **Generator.** Candidate c of entry n draws from `SeededRandom(seed: SeedDerivation.derive(plannedSeed, index: c))`:
  width and height by band (6 … 7, 7 … 9, 8 … 10, 9 … 12, 10 … 14), each cell a wall with chance 1 in 5 (bands 1 … 2)
  or 1 in 4, the entry among the open cells, a region of at least 12 cells, 1 … 4 beacons by band drawn from the region.
  Tolerance 1, 1, 1, 0, 0 and miss cost 1, 1, 2, 2, 3 by band; tutorial on levels 1 … 3. A candidate is kept when its
  witness plan has a pulse count in the band's range (1 … 2, 2 … 3, 3 … 4, 4 … 5, 5 … 6) and at most energy − 1, and the
  witness wins through the play; at most 256 candidates (`r02-g11.generation`). The ranges were measured with a
  prototype before they were written down; over the catalog the band means are 1.95, 2.6, 3.15, 4.45 and 5.35 pulses.
- **Inference proof.** A placement (beacon-count cells of the region) fits when every pulse's sorted echoes are
  reproduced; `EchoCartographerSolver.fitting` counts fits by a pruned enumeration (capped at 1 000). The plan is greedy:
  pulse the known-open cell whose echo leaves the fewest fits (ties: lowest index) until exactly one fits — the true
  beacons. Work (enumeration nodes) is bounded at 400 000; the largest catalog plan used 14 282.
- **Witness files.** `docs/games/echo-cartographer/levels/NNN.witness.json` (schema 1, sorted keys): the level, the
  actions (pulses, then a claim on each beacon), an echo digest per pulse, the fits after each pulse, the play
  fingerprints, the counterexample (two placements that fit every pulse but the last), the difficulty and the
  candidates skipped. Regenerated only with `ECHO_CARTOGRAPHER_WRITE_WITNESSES=1`; decoding re-runs the replay, the
  counts and the plan (`r02-g11.witness`).
- **Catalog.** `PuzzleCatalog<EchoCartographerRules>.digest(id: "echo-cartographer", …)` over the 100 fingerprints is
  pinned; the standard progression rule holds on the witness pulse count; an independent brute force (relaxed path
  lengths, every subset) re-checks the proof on the two smallest regions of each band.

## Hero renderer and experience (feature 403, R02-G11-03)

- **Scene.** The chamber floor is the plane y = 0; with s = 1.8 / max(W, H), cell (x, y) is centred at
  X = (x + 0.5 − W / 2)·s, Z = (y + 0.5 − H / 2)·s. Only what the player knows is drawn: opal floor tiles on known open
  cells, the entry diamond, marker rings, known walls as dark blocks 0.92·s wide and 0.5·s high with sonar-mint edge
  strips, located beacons as cyan pillars and the energy gauge in front of the chamber; unknown cells show the abyss
  ground and unlocated beacons are never drawn (`EchoCartographerSceneSnapshot` holds neither). The last pulse adds its
  rays, an expanding cyan pulse ring (one cell per 0.1 s), echo rings that return at each echo's delay and a flare on
  every wall it struck when the ring reaches it (`EchoCartographerSceneGeometry`, `EchoCartographerShaders`).
- **Order and shading.** Depth testing is off (the shared mesh renderer's path): the flat layers come first, then the
  blocks and pillars back to front by row from the far side (each row from the outside in, for the centred camera),
  then the gauge; tiles, rings and edges are shaded by signed distance from per-vertex local coordinates.
- **Tiers.** level-0: rings, flare trails and two glow shells; level-1: rings and one shell; level-2: none. Cells,
  markers, pillars, rays, colours and the gauge are identical at every tier; the presenter logs tier changes.
- **Camera.** A fixed authored view from above and in front (eye (0, 2.4, 1.9)) fitted to the box x −1 … 1,
  z −1 … 1.1, y 0 … 0.8 with a 5 % margin for aspects 0.4 … 2.5.
- **Adapter.** `EchoCartographerExperienceCore` opens certified level (seed mod 100) + 1 from its table of certified
  candidates and accepts `cell.pulse`, `cell.claim`, `cell.mark` [x, y], `play.undo`, `play.redo` and `level.next`; its
  digest is the level number and the play fingerprint; snapshot schema 1 `{level, records}`.
- **Fallback and settings.** A shader failure draws the level-2 geometry unlit and keeps the reason; Reduce Motion draws
  the rings and flares at rest; Reduce Flashing caps the glow.
- **Candidate.** Registered in `Catalog/registrations.json` (100 levels, digest a32a593b…dca9) and linked into the app
  as a candidate (`ExperienceRegistry.candidates`) until X-R02-G11; the scenario manifest holds the standard scenarios,
  `full-playthrough`, `hero`, 80 acceptance scenarios and three fixtures.
