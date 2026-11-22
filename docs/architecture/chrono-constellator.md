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
