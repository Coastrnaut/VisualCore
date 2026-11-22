# Faceted Forge (R02-G08) — rules

Experience `r02-g08.faceted-forge` (free) of the one VisualCore app; package `Packages/ExperiencesRound02`, target
`FacetedForgeCore` (feature 371, R02-G08-01). A glowing convex crystal is to be split into target pieces. The player
picks a piece, chooses a cutting plane from a fixed set of directions and an integer depth, and commits the cut: the
piece splits into two convex pieces. The level is won when the pieces' shares of the crystal and their face counts match
the target exactly within the cut budget. Everything here is pure, exact rational logic; drawing, controls and sound
come in later features of R02-G08.

## Directions, planes and the crystal

- **Directions.** 13 directions with components in {−1, 0, 1}, named in words: the axes x, y, z, the six face
  diagonals (x+y, x−y, x+z, x−z, y+z, y−z) and the four body diagonals (x+y+z, x+y−z, x−y+z, −x+y+z)
  (`FacetedForgeDirection.all`).
- **Half-spaces.** sign·(n·p) ≤ sign·depth with an integer depth −24 … 24: sign +1 is the side below the plane
  n·p = depth, sign −1 the side above (`FacetedForgeHalfSpace`).
- **The crystal** is the intersection of 4 … 14 half-spaces, a closed solid inside the box −6 … 6 on every axis; the
  level adds the cut budget (1 … 12), the sliver limit (a share 0 < s < 1/2) and the target (at least two entries of a
  share and a face count 4 … 26, shares summing to one).

## Exact pieces

`FacetedForgePiece` is given by its bounding half-spaces and keeps only those that are faces. Its corners are the
points where three planes meet and every plane holds; a corner solves three planes whose normals have components in
{−1, 0, 1}, so its denominator divides 12, and every predicate runs on the corners scaled to integers. A face is a plane
with at least three corners, ordered anticlockwise around the outward normal; the volume is the sum of signed
tetrahedra from the first corner over a fan of each face (`FacetedForgeFraction`, checked 64-bit fractions; an
overflow refuses the action). After every cut the volumes sum to the crystal's and every edge lies on exactly two faces
(the truth metric). Pieces are kept in canonical order: volume descending, then face count descending, then the sorted
corners (`FacetedForgePiece.canonical`).

## Cuts and verdict

`cut(piece, direction, depth)` splits piece k into its below and above halves; it is refused (`r02-g08.miss`) unless a
corner of the piece lies strictly on each side of the plane, so no degenerate face can arise. After a cut, in this
order: **sliver** (a new piece whose share is strictly below the sliver limit fails the level, naming the piece and the
cut; equal is allowed), **win** (the multiset of (share, face count) equals the target), **budget** (cuts spent equal to
the budget: failed). A win on the last cut counts, and nothing is judged before the first cut.

## Play

`FacetedForgePlay` moves through loading, tutorial, playing, paused, won or failed and result. Every accepted cut spends
one cut; a refused action spends nothing. An action is checked in this order — stage, previous fingerprint, range, miss
— and refused without change (`r02-g08.stage`, `.stale`, `.action("range")`, `.miss`). Every accepted action, undo and
redo appends a record with the previous and next play fingerprints (SHA-256 of the schema, level fingerprint, pieces,
cuts, stage and failure). Every cut can be undone and redone; undo works in playing, paused and failed (a failed play
returns to playing) and gives the cut back, and a won play is final. A record trace replays to the same records and
outcome (`FacetedForgePlay.replay`).

## Stored form and contract

Levels are JSON schema 1 with sorted keys and their fingerprint; decoding re-checks every rule and the fingerprint and
refuses damaged, edited and newer forms (`r02-g08.malformed`, `.newer-schema`). `FacetedForgeRules` expresses the game
as an R02-F23 `PuzzleRules`: while playing, the moves are every non-degenerate cut — pieces in canonical order,
directions 0 … 12, depths ascending.
