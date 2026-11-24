# Starlit Cartouche (R02-G16) — rules

Experience `r02-g16.starlit-cartouche` (free) of the one VisualCore app; package `Packages/ExperiencesRound02`, target
`StarlitCartoucheCore` (feature 451, R02-G16-01). A ship waits at a star of a drifting star chart and flies corridors
between stars; each leg draws a stroke of light between the two stars' points on a cartouche, an ancient symbol drawn
as strokes. The level is won when the trail has drawn exactly the symbol's strokes and the ship rests at the beacon in
time; a leg that crosses a hazard tube, misses a star's time window, strays off the symbol or arrives after the
deadline fails. Everything here is pure, exact integer logic on beats (one quantized launch tick, 30 presentation
ticks of 0.008333 s); drawing, controls and sound come in later features of R02-G16.

## Stars, orbits and corridors

- **Stars.** 4 … 12; star i cycles through an orbit of 1 … 4 lattice positions (coordinates −8 … 8), sitting at
  orbit[b mod length] at beat b, and has a glyph point on the 5 × 5 cartouche grid, distinct from every other star's,
  and a time window [open, close] with 0 ≤ open ≤ close ≤ 64.
- **Corridors.** At most 24 undirected corridors, each joining two different stars once, with a travel time of 1 … 3
  beats. A corridor is flyable at beat b when its stars' squared distance at b is at most r², r the level's range
  (1 … 12), so a leg may have to wait for its stars to drift close.
- **Hazard tubes.** At most 8; each names a corridor and a closed beat interval [from, to] during which it blocks it.

## Legs, failures and the win

The ship starts at the start star at beat 0 (its window contains 0). `leg(j, w)` waits w beats (0 … 8), departs at
t₀ = t + w along the corridor to j and arrives at t₁ = t₀ + travel. It is refused (`r02-g16.action`) for an unknown
star, the ship's own star, no corridor, a wait out of range and stars out of range at t₀. Otherwise it spends one action
and fails, in this order: `window` when t₀ is after the close of the star left, `hazard` when a hazard on the corridor
meets [t₀, t₁] (the lowest such hazard), `window` when t₁ is outside j's window, `deadline` when t₁ is after the level's
deadline (1 … 64) and `stroke` when the corridor is not one of the symbol's 1 … 12 strokes. A failed leg leaves the
route as it was. After an accepted leg the level is won when the drawn corridors equal the symbol (a retraced stroke
counts once) and the ship is at the beacon; otherwise a budget (1 … 16) fully spent fails `budget`. (Windows first had
to close by the deadline, which made the deadline failure unreachable; the chart tests found it during implementation,
and windows now close by beat 64.)

## The truth metric

After every action (`StarlitCartoucheRouteReport`): the ship's star and beat, the strokes drawn, the missing strokes,
the stray strokes, the glyph mismatch (missing + stray) and the hazard clearance (the fewest beats between a flown leg
and a hazard on its corridor, nil when none shares a flown corridor). It never decides on its own.

## Play, records and the puzzle contract

The play (`StarlitCartouchePlay`) follows loading → tutorial (when the level has one) → playing ⇄ paused → won or
failed → result. Legs are validated in the order stage, previous fingerprint, action (`r02-g16.stage`,
`r02-g16.stale`, `r02-g16.action`); every accepted leg appends a record with previous and next fingerprints (SHA-256 of
the schema, the level fingerprint, the ship's star and beat, the drawn strokes, the legs flown, the actions spent, the
stage and the failure). Undo and redo restore exact states; undo from failed returns to playing before the failing leg
and refunds its action (recorded); a won level is final. A trace replays to the same states. Levels are JSON schema 1
with sorted keys and a fingerprint, re-checked on decode (`r02-g16.level`, `r02-g16.newer-schema`,
`r02-g16.malformed`). `StarlitCartoucheRules` expresses the rules as an R02-F23 `PuzzleRules` (moves: every corridor
from the ship's star in index order, waits 0 … 8, flyable ones only) for the level certification of R02-G16-02.
