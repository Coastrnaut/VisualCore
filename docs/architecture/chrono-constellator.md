# Chrono Constellator (R02-G06) — rules

Experience `r02-g06.chrono-constellator` (free) of the one VisualCore app; package `Packages/ExperiencesRound02`, target
`ChronoConstellatorCore` (feature 351, R02-G06-01). A few stars each travel round their own fixed loop of cells on a small
sky grid. The player edits a timeline — where on its loop each star starts and short holds in which a star waits — and
replays it; the level is won when every star stands on its own target on the same tick, without two stars ever meeting
on one cell, within the tick limit. Everything here is pure, exact integer logic; drawing, controls and sound come in
later features of R02-G06.

## Sky and stars

- **Grid.** 5 … 12 columns by 5 … 10 rows, indexed row-major.
- **Stars.** Two to five; star i has the fixed shape ring, cross, diamond, triangle or square and is described in words,
  number and shape (`ChronoConstellatorLevel.description(ofStar:)`), so stars are told apart without colour. Each star
  has a loop of 4 … 32 distinct cells in travel order (consecutive cells, and the last and the first, are 4-neighbours),
  a default start phase and a target cell on its loop. Targets are pairwise distinct; loops may share cells, which is
  where stars can collide.
- **Limits.** An edit budget of 1 … 20 and a tick limit of 1 … 1,200 ticks of 1/120 s (10 s).

## The timeline

`ChronoConstellatorTimeline` holds each star's start phase φ and its holds (star, start s ≥ 1, length 1 … 60, ending by
the tick limit); a star's holds neither overlap nor touch. Star i stands at tick t on

    loop_i[(φ_i + t − h_i(t)) mod L_i]

where h_i(t) counts its held ticks among ticks 1 … t. Positions follow from this formula alone, so any tick can be
computed directly (rewind, scrubbing, the solver's phase search) and stepping tick by tick gives the same cells. The
edits in use are the stars whose phase differs from the level's default plus the holds; an edit that would bring them
above the budget is refused. The timeline's own SHA-256 fingerprint (phases and holds) is the signed snapshot replays
are compared by.

## Verdict

After every tick t ≥ 1, in this order: **collision** (two stars on one cell; the failure names the lower-numbered pair
and the cell), **win** (every star on its own target), **time** (t reaches the tick limit). Nothing is judged at tick 0,
so a level is never won before the replay starts. Because targets are distinct, a win and a collision never coincide;
two stars swapping neighbouring cells on one tick do not collide.

## Play

`ChronoConstellatorPlay` moves through loading, tutorial, playing, paused, won or failed and result. `phase(star,
offset)`, `hold(star, start, length)` and `release(star, start)` edit the timeline and are accepted only at tick 0;
`step(n)` replays 1 … 1,200 ticks and stops at the deciding tick; `rewind` returns to tick 0 with the timeline kept (also
from failed, as an honest retry). Steps and rewinds spend nothing. An action is checked in this order — stage, previous
fingerprint, range, edits only at tick 0, the edit's own rule (same phase, overlapping hold, missing hold), budget — and
refused without change (`r02-g06.stage`, `.stale`, `.action(…)`, `.budget`). Every accepted action, undo and redo
appends a record with the previous and next play fingerprints (SHA-256 of the schema, level fingerprint, tick,
timeline fingerprint, edits in use, stage and failure). Every action can be undone and redone (snapshots); undo works in
playing, paused and failed (a failed play returns to playing), and a won play is final. A record trace replays to the
same records and outcome (`ChronoConstellatorPlay.replay`); pauses are not records, but the stage is in every
fingerprint, so the replay pauses or resumes where a record's previous fingerprint says so.

## Stored form and contract

Levels are JSON schema 1 with sorted keys and their fingerprint; decoding re-checks every rule and the fingerprint and
refuses damaged, edited and newer forms (`r02-g06.malformed`, `.newer-schema`). `ChronoConstellatorRules` expresses the
game as an R02-F23 `PuzzleRules`: at tick 0 the moves are each phase change, each hold on the grid of starts 1 … 32 and
lengths 1 … 32 that the play accepts, each release, then a single step of the tick limit; after tick 0 only a rewind.

## Content pipeline (feature 352, R02-G06-02)

- **Manifest.** `ChronoConstellatorManifest` holds the archived design's 100 levels (number, planned seed, band, move
  budget 8 … 19); the chapter header's "78 stages" is a milestone figure only.
- **Generator.** Candidate k of a level draws from `SeededRandom(seed: SeedDerivation.derive(plannedSeed, index: k))`: per
  band a grid of 6 × 5, 6 × 5, 7 × 6, 7 × 6 or 8 × 7 with 2, 3, 3, 4 or 5 stars; each star a rectangle loop of 2 … 5 by
  2 … 4 cells, clockwise or reversed; distinct targets; random default phases; a tick limit of 120 … 360. A candidate is
  kept when the solver certifies a smallest edit count in the band's range (1; 2; 2; 3; 3 … 4) with at least the band's
  number of collision-blocked windows (0; 1; 2; 2; 3) and the witness wins while the default timeline does not; at most
  512 candidates (the worst level needs 88).
- **Solver (integer-tick phase search).** m(T) counts the stars off target at tick T under the default timeline; each
  edit acts on one star, so m* = min m(T) is a lower bound on every winning timeline. The windows are the ticks with
  m(T) = m*; a window's phase-only timeline re-phases exactly the stars off target, and it is blocked when two stars meet
  on the way. The first unblocked window proves the count exactly. An independent brute force (every phase-only timeline
  of fewer edits, plus one hold on the small levels) agrees on levels 1, 11, … 91.
- **Witnesses.** `docs/games/chrono-constellator/levels/NNN.witness.json` (schema 1): the level, the actions, the win
  tick, a 16-hex position digest per tick, the play fingerprints, the lower bound and windows, the unedited and near-miss
  counterexamples, the difficulty and the skipped candidates; decoding re-solves and refuses any difference. The catalog
  digest over the 100 fingerprints is pinned (`6483b20e…`).

## Experience and renderer (feature 353, R02-G06-03)

- **Adapter.** `ChronoConstellatorExperienceCore` opens certified level (seed mod 100) + 1 (each level generated once
  per process, on first use) and accepts `star.phase [star, phase]`, `star.hold [star, start, length]`,
  `star.release [star, start]`, `time.step [ticks]`, `time.rewind`, `play.undo`, `play.redo` and `level.next`; values
  out of range or fractional and kernel refusals change nothing. Its digest is the level number and the play
  fingerprint; snapshot schema 1 `{level, records}` restores by replay.
- **Snapshot.** The presenter draws an immutable `ChronoConstellatorSceneSnapshot` (grid, every star's loop, target,
  cell and the cells of its last 24 ticks, the timeline's phases and holds, stage, failure, tick, tick limit, edits left,
  level number and presentation time); it never holds the kernel, so no drawing result can change the game.
- **Scene.** The grid lies in the xz-plane with cell size u = 2 / max(columns, rows): the indigo field (#0B0A24) with
  faint grid lines, silver tracks (0.08·u wide) along each loop, star nodes (radius 0.3·u at height 0.25·u) drawn with
  their shapes (ring, cross, diamond, triangle, square), rose target rings (outer radius 0.42·u) with the same shape,
  lit while the star stands on them, hold bars, an amber diagonal cross on a collision cell, and the current-tick mark
  (a silver bar along the near edge, tick / tick limit of the grid's width). Each star trails a
  history ribbon over the tier's last R ticks, rising 0.04·u per tick of age, its alpha 1 − age/R, with a gentle shimmer
  from presentation time only. The camera looks from +z, pitched 55° down, fitted to the bounding sphere of the grid and
  the ribbons' full height with a 5 % margin for aspects 0.4 … 2.5.
- **Shaders.** GLSL ES 3.00 on the shared `ShaderMeshRenderer`: the field program carries the material code and shade in
  uv; the glow program carries the colour in the normal slot and the age in ticks and glow weight in uv, and computes
  the ribbon fade itself. Reduce Motion holds the shimmer still; Reduce Flashing caps the glow at 0.5.
- **Tiers.** level-0: ribbons of 24 ticks, 4 segments per tick, 2 glow shells; level-1: 12, 2, 1; level-2: 6, 1, 0.
  Stars, targets, tracks and the camera never change between tiers; each tier change is logged with its reason. A
  program that fails to compile draws the level-2 geometry unlit and keeps its reason. Depth testing is off on this
  path, so the draw order is the layering and back faces are culled.
- **Candidate.** Registered in `Catalog/registrations.json` (100 levels, digest 6483b20e…6ffc) and linked into the one
  app; it stays unavailable until X-R02-G06. Its scenario manifest has the standard scenarios, `full-playthrough`,
  `hero`, three fixtures and the 80 acceptance rows R2-G06-QA-001 … 080 (row r opens level (7 × (r − 1)) mod 100 + 1).
