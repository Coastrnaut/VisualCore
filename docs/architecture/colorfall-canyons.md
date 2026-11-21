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
