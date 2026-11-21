# Wave Knot Keeper (R02-G03) — rules

Experience `r02-g03.wave-knot-keeper` (free) of the one VisualCore app; package `Packages/ExperiencesRound02`, target
`WaveKnotKeeperCore` (feature 321, R02-G03-01). The player reshapes a closed glowing rope one lattice step at a time,
never passing it through itself except inside the level's crossing gates, until its projected crossings and knot
signature match the target. Everything here is pure, exact integer logic; drawing, controls and sound come in later
features of R02-G03.

## Rope

- **Control points.** A level's rope is a closed polygon of 6 … 16 distinct control points with integer coordinates in
  −16 … 16 on each axis; segment i joins point i to point i + 1, the last to the first. The drawn spline of later
  features passes through these points; every rule uses the polygon.
- **Simple.** No two non-adjacent segments meet and no two adjacent segments fold back over each other. A level's start
  must be simple; legal moves keep the rope simple.
- **Tension.** The sum over the segments of the squared length, an integer. A move that would raise it above the level's
  bound is refused (`r02-g03.move("tension")`).

## Moves

A move steps one control point P one unit along ±x, ±y or ±z to P′. It must stay in bounds and not land on another point.
With neighbours A and B, it sweeps the triangles A-P-P′ and P-P′-B; it is refused (`r02-g03.move("crossing")`) when a
segment that does not end at P meets either triangle, except that the segment ending at A may touch A-P-P′ at A alone and
the segment starting at B may touch P-P′-B at B alone. Inside a crossing gate (an inclusive integer box holding both P and
P′) strands may pass. All of it is decided with integer orientation determinants (`WaveKnotKeeperGeometry`); two
coplanar figures meet exactly when their projections onto all three coordinate planes meet.

## Verdict

The rope is projected onto the xy-plane. Every pair of non-adjacent segments whose projections cross at one point
interior to both counts one crossing, signed by the right-hand rule: +1 when the cross product of the over-strand's and
the under-strand's xy directions is positive (the over-strand has the larger z at the crossing), −1 otherwise. The
summary is the crossing count and the writhe (the sum of signs). A projection is degenerate when a non-adjacent pair
touches at an endpoint, overlaps collinearly or crosses at equal z; a degenerate projection never wins. The level is won
exactly when the projection is not degenerate and the summary equals the target. A level whose start already wins is
refused.

## Play

`WaveKnotKeeperPlay` moves through loading, tutorial, playing, paused, won or failed and result. A move is checked in
order: stage, previous fingerprint, point index, bounds, coincidence, sweep, tension, allowance; a refused move changes
nothing. The verdict follows every accepted move, undo and redo; spending the last move without a win fails the level with
the final summary as its explanation. Undo steps the point back and refunds the move, redo re-applies it, a new move
clears redo. Every accepted action appends a `WaveKnotKeeperRecord` with the previous and next fingerprint, so a trace
replays to the same states everywhere. The fingerprint is the SHA-256 hex of the schema, the level fingerprint, the
points, the moves spent and the stage.

## Levels and puzzle contract

`WaveKnotKeeperLevel` is immutable and fingerprinted (SHA-256 of its canonical JSON with sorted keys, schema 1): id,
seed, band 1 … 5, points, 0 … 4 gates, target (crossings 0 … 32, writhe −32 … 32 of matching parity), tension bound,
allowance 1 … 64 and tutorial. Decoding re-checks every rule and the fingerprint; damaged, edited and newer forms are
refused. `WaveKnotKeeperRules` expresses the game as the R02-F23 `PuzzleRules` contract: a state is the rope, the legal
moves are listed point by point and direction by direction, and a state is solved when it wins the level.

## Content (R02-G03-02)

- **Manifest.** `WaveKnotKeeperManifest` holds the 100 planned levels of the archived design (number, seed, band 1 … 5,
  budget 8 … 19).
- **Generator.** Candidate k of a level draws from `SeedDerivation.derive(seed, index: k)`: a solved rope of 5 + band
  points at seeded angles of a fixed 32-direction integer table (with `band` neighbour swaps so the projection crosses
  itself), gates on rope points (bands 1 … 5: 0, 0, 1, 1, 2), then a scramble walk of 1, 2, 2, 3, 4 legal moves that
  prefers moves changing the signature. The tension bound covers the walk plus slack; the allowance is the budget. A
  candidate is kept when its shortest solution lies in the band's range (1, 1–2, 1–2, 2, 2–3) and both counterexamples
  exist; at most 64 candidates, else `r02-g03.generation`.
- **Solver.** A breadth-first search over legal ropes to depth 3 (at most 3,661 ropes expanded for 10 points), the first
  shortest sequence in the rules' move order, plus the first explored rope with a refused crossing.
- **Witness files.** `docs/games/wave-knot-keeper/levels/NNN.witness.json` (schema 1): the level, the moves, the play
  fingerprints, the terminal summary, a near miss and a refused crossing, the difficulty and the skipped candidates.
  Decoding replays everything and re-runs the solver; `WAVE_KNOT_KEEPER_WRITE_WITNESSES=1` regenerates the files. The
  catalog digest is pinned in the tests.

## Renderer and experience (R02-G03-03)

- **Snapshot.** `WaveKnotKeeperSceneSnapshot` is the only thing the renderer reads: the rope's points, the gates, the
  target, the projection summary and each proper crossing with its over-strand (`WaveKnotKeeperCrossingMark`), the
  stage, the selected point and the presentation time. Nothing drawn reaches the kernel.
- **Geometry.** `WaveKnotKeeperSceneGeometry` builds a closed glass tube along the control polygon (world = kernel ×
  1/8, radius 0.1, straight segments with quadratic corner arcs, parallel-transport frames), so the drawn crossings are
  the rules' crossings; glow shells, handle icospheres and gate cubes; the camera looks down −z tilted 20° and fits the
  figure with a margin for aspects 0.4 … 2.5. Crossing weights in the rope mesh drive ember caustic pulses on
  over-strands.
- **Shaders.** `WaveKnotKeeperShaders` (GLSL ES 3.00): the rope program (pearl and sapphire glass with a fresnel rim,
  ember pulses at 0.5 Hz, glow-shell mode) and the solid program (handles and gates with an edge term).
- **Tiers.** level-0 … level-2: tube sides 16/10/6, corner samples 8/4/2, glow shells 2/1/0; coordinates never change.
  A shader failure falls back to the minimal tube drawn unlit and records the reason.
- **Adapter.** `WaveKnotKeeperExperienceCore`: `point.move [point, direction]`, `point.select`, `play.undo`,
  `play.redo`, `level.next`; digest = level number + play fingerprint; snapshot schema 1 `{level, records}`. The
  experience is a registered candidate (`-vcCandidates`) until X-R02-G03, with a 94-scenario manifest.

## Failures

`WaveKnotKeeperError` reason codes: `r02-g03.level`, `r02-g03.move`, `r02-g03.stage`, `r02-g03.stale`,
`r02-g03.allowance`, `r02-g03.newer-schema`, `r02-g03.malformed`.

## Sources

The game design is VisualCore's own (archived round-two design); the code is original. Nothing here draws.
