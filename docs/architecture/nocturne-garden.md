# Nocturne Garden (R02-G09) — rules

Experience `r02-g09.nocturne-garden` (free) of the one VisualCore app; package `Packages/ExperiencesRound02`, target
`NocturneGardenCore` (feature 381, R02-G09-01). The player arranges glowing blooms in a garden bed so that their shadows
form a target flower silhouette without spilling into forbidden outline regions. Everything here is pure, exact integer
logic; drawing, controls and sound come in later features of R02-G09.

## Bed, blooms and sun

- **Bed.** A grid of W × H cells (W 16 … 32, H 12 … 24); cell (column, row) counts from the left and from the ground row
  upward, and is stored as the row-major index row · W + column.
- **Blooms.** Six kinds, each a fixed original simple polygon with integer vertices whose foot is at the origin and whose
  stem rises along +y, within 3 × 6 cells at size 1: tulip (a cup of two upright petals), bell (a narrow crown over a
  flared rim), star (five spikes), fern (alternating leaflets), rose (a round full head) and lily (a trumpet with a wide
  mouth) (`NocturneGardenKind`). A bloom is planted with its foot at the corner (column, row) at size 1 … 3, the outline
  scaled by the size (`NocturneGardenBloom`).
- **Sun.** Four elevations, 1 (high) … 4 (low); the factor e / 2 (1/2, 1, 3/2, 2) stretches every shadow vertically about
  its bloom's foot.

## Shadow mask and measures

A cell is dark for a bloom when its centre lies inside or on the boundary of the bloom's cast polygon; with every
coordinate doubled the test is an exact integer winding number with an explicit on-segment check. The shadow mask is
the union of all blooms' dark cells within the bed (`NocturneGardenMask`). The **match** is |M ∩ T| / |M ∪ T| between
the mask M and the target T, compared with the level's required fraction p / q by cross multiplication (an empty union
never matches); the **leak** is the number of mask cells in the forbidden regions F; the **boundary deviation** (the
truth metric) is the symmetric Chebyshev Hausdorff distance between the boundary cells of M and T, reported after every
action and never deciding the outcome.

## Actions and verdict

`plant(kind, column, row, size)`, `move(bloom, column, row)`, `resize(bloom, size)`, `remove(bloom)` and
`sun(elevation)`; each accepted action spends one move. Refused without change: out of range (`r02-g09.action`), a kind
whose supply is used up (`.supply`), an action that changes nothing (`.noop`), the wrong stage (`.stage`) and a stale
fingerprint (`.stale`). Blooms are kept in canonical order (row, column, kind, size) and named "bloom 1" … in that order;
removing a bloom returns it to the supply. After an accepted action, in this order: **leak** (a leak above the allowance
fails the level, naming the move), **win** (match at least p / q and leak within the allowance), **budget** (moves spent
equal to the budget: failed). A win on the last move counts, and nothing is won before the first bloom.

## Stored form

Levels are JSON schema 1 with sorted keys (bed, target and forbidden cells, supply, sizes, elevations, opening sun,
budget, required match, leak allowance, tutorial, seed, id) and their fingerprint; decoding re-checks every rule and the
fingerprint and refuses damaged, edited and newer forms (`r02-g09.malformed`, `.newer-schema`).
