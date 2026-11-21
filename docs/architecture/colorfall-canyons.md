# Colorfall Canyons (R02-G05) — rules

Experience `r02-g05.colorfall-canyons` (free) of the one VisualCore app; package `Packages/ExperiencesRound02`, target
`ColorfallCanyonsCore` (feature 341, R02-G05-01). The player carves short sluices into a small canyon terrain and opens
or closes the valves of three springs of coloured light-fluid (cyan, coral, yellow), then lets time run; fluid runs
downhill cell by cell into basins. The level is won when every target basin holds its required fill and colour mix
without contamination or overflow within the tick limit. Everything here is pure, exact integer logic; drawing,
controls and sound come in later features of R02-G05.

## Terrain

- **Cells.** A grid of 4 … 12 columns by 4 … 10 rows, indexed row-major. Every cell has a height 0 … 15 and a ground:
  open, rock (never holds or passes fluid) or drain. One to three springs and one to four basins sit on distinct open
  cells; at least one drain exists and at least one basin has a required fill above 0.
- **Springs.** Each releases one colour, 1 … 4 units per tick while its valve is open, from a supply of 1 … 999 units.
- **Basins.** Each has a capacity (1 … 999), a required fill (0 … capacity), a required share of each colour in per
  mille (summing to 1,000) with a tolerance (0 … 500 per mille) and, when protected, a tolerated amount of wrong colour
  (a colour whose required share is 0). `ColorfallCanyonsBasin.description` states the mix in words and amounts.

## The tick

One tick is 1/60 s and is computed synchronously from the state at its start (`ColorfallCanyonsFluid.tick`):

1. Every open or spring cell with volume V > 0 passes r = min(V, flow rate) units (flow rate 1 … 8) to its downhill
   neighbour: the non-rock 4-neighbour with the lowest height strictly below its own, ties in the order east, south,
   west, north. A cell without one holds its fluid (a pool); basins and drains never pass fluid on.
2. The r units are shared between the colours by largest remainder of r · m_c / V (floors first, leftover units to the
   largest remainders, ties to the lower colour), so no unit is created or lost.
3. Every open spring with supply left adds min(release, supply) units of its colour to its own cell.
4. Fluid that reached a drain is counted as spilled.

Conservation is exact for each colour after every tick: released = held in cells (basins included) + spilled.

## Verdict

After every tick, in this order: **contamination** (a protected basin's wrong colour above its tolerated amount),
**overflow** (a basin above its capacity), **win** (every basin with a fill above 0 holds at least that fill and, for
each colour, |1,000 · m_c − share_c · V| ≤ tolerance · V; never at tick 0), **time** (the tick limit, 1 … 3,600,
reached). Failure is decided before win, so a contaminated or overflowing basin never wins.

## Play

`ColorfallCanyonsPlay` moves through loading, tutorial, playing, paused, won or failed and result. `carve(cell)` lowers
a carvable cell (open ground without a spring or basin, above height 0) by one and `valve(spring)` toggles a valve; each
spends one action of the budget (1 … 30). `step(n)` runs 1 … 600 ticks, spends nothing and stops at the deciding tick.
An action is checked in this order — stage, previous fingerprint, range or carvability, budget — and refused without
change (`r02-g05.stage`, `.stale`, `.action("range" | "not-carvable")`, `.budget`). Every accepted action, undo and
redo appends a record with the previous and next play fingerprints (SHA-256 of the schema, level fingerprint, tick,
heights, valves, supplies, every cell's colour masses, spilled amounts, actions spent, stage and failure). Every action
can be undone and redone (snapshots); undo works in playing, paused and failed (a failed play returns to playing), and a
won play is final. A record trace replays to the same records and outcome (`ColorfallCanyonsPlay.replay`); pauses are not records, but
the stage is in every fingerprint, so the replay pauses or resumes where a record's previous fingerprint says so (an
undo or redo made while paused).

## Stored form and contract

Levels are JSON schema 1 with sorted keys and their fingerprint; decoding re-checks every rule and the fingerprint and
refuses damaged, edited and newer forms (`r02-g05.malformed`, `.newer-schema`). `ColorfallCanyonsRules` expresses the
game as an R02-F23 `PuzzleRules`: a position is (fluid, actions spent, outcome); the moves are a carve of each carvable
cell, a toggle of each valve (while budget remains) and a single tick, so a certified solution (R02-G05-02) spells a
long step as single ticks; the play accepts both.

## Content pipeline (feature 342, R02-G05-02)

- **Manifest.** `ColorfallCanyonsManifest` holds the 100 planned levels of the archived design (number, planned seed,
  band 1 … 5, move budget 8 … 19), 20 per band.
- **Generator.** Candidate k of a level draws from `SeededRandom(seed: SeedDerivation.derive(plannedSeed, index: k))`: a
  mesa grid (bands 1–2: 6 × 5, band 3: 7 × 5, bands 4–5: 8 × 6) sloping down by two height steps per row with noise, rock
  (15 %), bottom-row drains (20 %), depressions that pool fluid, springs on the top two rows (1, 2, 2, 3, 3 by band), a
  flow rate and a tick limit. A planted plan then changes each spring's path once (the smallest carve depth 1 … 3 of a
  cell on or next to the path); basins go where the planted paths pool, and their targets are what the planted run
  leaves there. A candidate is kept when the planted plan wins, the unedited level does not, and the solver's smallest
  edit count is in the band's range (1 … 2, 2 … 3, 3, 3, 3); at most 512 candidates (`r02-g05.generation` beyond).
- **Solver.** `ColorfallCanyonsSolver` searches edit sets (carves plus valve toggles before the first tick, then letting
  time run) of size 0 … 3 in a fixed order and returns the first that wins, so the count is smallest. Each set is keyed
  by its routing and valves (a carve that changes no downhill choice changes nothing); every distinct key is simulated
  once with conservation asserted every tick. Exact speed-ups: carves no fluid can reach within the depth are left out,
  routing keys are updated incrementally with a Zobrist hash (compared in full on a hit), and the search runs an
  allocation-free copy of the kernel's tick that stops once nothing can move; the returned set is re-run through the
  kernel. The solver certifies plans made before the first tick, so a player who also edits during a run may do better.
- **Difficulty.** `ColorfallCanyonsDifficulty`: smallest edits, routings simulated, win tick, springs, basins, protected
  basins and carvable cells. Band means of the smallest count never fall and R02-F24's progression rule holds.
- **Witness files.** `docs/games/colorfall-canyons/levels/NNN.witness.json` (schema 1) store the level, the winning
  actions, the win tick, a digest of the cell masses after every tick, the totals at the win, the play fingerprints and
  two counterexamples (the unedited level and the witness without its last edit, both failing); edited, newer or
  non-replaying files are refused (`r02-g05.witness`). The catalog digest over the 100 level fingerprints is pinned.

## Experience and renderer (feature 343, R02-G05-03)

- **Adapter.** `ColorfallCanyonsExperienceCore` opens certified level (seed mod 100) + 1 (generated once per process) and
  accepts `canyon.carve [cell]`, `canyon.valve [spring]`, `time.step [ticks]`, `play.undo`, `play.redo` and `level.next`;
  its digest is the level number and the play fingerprint; snapshot schema 1 `{level, records}` restores by replay.
- **Snapshot.** The presenter draws an immutable `ColorfallCanyonsSceneSnapshot` (grid, current heights, grounds,
  springs with valves and supplies, basins and their targets, every cell's colour masses and downhill direction, stage,
  failure, tick, level number and presentation time); it never holds the kernel, so no drawing result can change the
  game.
- **Scene.** The grid lies in the xz-plane with cell size u = 2 / max(columns, rows); block tops at 0.06·h·u (carving
  lowers them at once), rock slabs raised, drains as dark pits, basins with pearl rims and three target arcs, springs as
  glowing emitters dimmed when closed or dry. Fluid is an emissive sheet per cell whose colour is the mass-weighted mix of
  cyan, coral and yellow and whose brightness follows the volume, with flow bands along the downhill direction (faster on
  falls of two steps or more) moving with presentation time only. Each colour also carries a pattern (cyan stripes,
  coral dots, yellow chevrons). The camera looks from the front, pitched 50° down, fitted to the bounding sphere of the
  tallest element with a 5 % margin for aspects 0.4 … 2.5.
- **Shaders.** GLSL ES 3.00 on the shared `ShaderMeshRenderer` (position, normal and uv streams): the terrain program
  carries the material and shade in uv; the fluid program carries the colour weights in the normal slot and the
  brightness and flow code in uv. Reduce Motion holds the bands still; Reduce Flashing caps the glow at 0.5.
- **Tiers.** level-0: 4 × 4 top subdivision, 3 flow bands, 2 glow shells; level-1: 2 × 2, 2, 1; level-2: 1 × 1, 1, 0.
  Positions never change between tiers; each tier change is logged with its reason. A program that fails to compile
  draws the level-2 geometry unlit and keeps its reason. Depth testing is off on this path, so back faces are
  culled (every face is wound counter-clockwise from its front) and the rows are drawn far to near: a block's far side
  never covers its own top, and nearer blocks cover farther ones.
- **Candidate.** Registered in `Catalog/registrations.json` (100 levels, digest 68eec7b5…f019) and linked into the one
  app; it stays unavailable until X-R02-G05. Its scenario manifest has the standard scenarios, `full-playthrough`,
  `hero`, three fixtures and the 80 acceptance rows R2-G05-QA-001 … 080.

