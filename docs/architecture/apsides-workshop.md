# Apsides Workshop (R02-G18)

Experience `r02-g18.apsides-workshop` (free), a puzzle of one orbiter around a star in a miniature sky: the player
tunes the orbit — its eccentricity and periapsis direction with one knob, its size with another — then plays one
revolution, so that the orbit sweeps the prescribed sky sectors with their shares of area and puts its apsides where
the targets ask, in order, without striking an exclusion planet. Code lives in
`Packages/ExperiencesRound02/ApsidesWorkshop`; this page grows with each feature of R02-G18. Kepler's equation is solved
in deterministic integer fixed point and every rule is then decided exactly on integer positions; the catalog's
0.008333 s timestep is a presentation clock of later features.

## Rule kernel (feature 471, R02-G18-01)

- **Sky and orbit.** The star sits at the origin (radius 2 lattice units); one lattice unit is 256 sky units and the
  sky reaches 64 lattice units. An orbit is a size a of 8 … 48 lattice units, an eccentricity step k of 0 … 15
  (e = k/20) and a periapsis direction step d of 0 … 23 (15° each); it is valid when a(20 − k) ≥ 60 (the periapsis at
  least 3 lattice units out) and a(20 + k) ≤ 1280 (the apoapsis inside the sky).
- **Kepler's equation.** One revolution has T ticks (even, 16 … 96); tick t has mean anomaly M = (2π · t) / T. With
  2^30 as one, integer sine, cosine and square root, Newton's iteration starts at E = M + e·sin M and takes at most 8
  steps, stopping at a residual of 2^−24; otherwise 48 bisection steps on [M − e, M + e] decide E. Every residual stays
  within 2^−22. The position (a(cos E − e), a·√(1 − e²)·sin E) is turned by 15d° from an exact quarter-turn table and
  rounded to whole sky units, half away from zero; periapsis is tick 0, apoapsis tick T/2.
- **Sectors and shares.** Eight sectors of 45° counterclockwise from +x, each owning the boundary ray it begins,
  decided from the signs of x and y and |x| against |y|. The swept area is one triangle star → P(t) → P(t + 1) per tick
  (its doubled area the integer cross product), counted for the sector of P(t); a share is a sector's area over the
  whole in tenths of a percent, rounded down. The periapsis lies in sector ⌊d/3⌋ at a(20 − k) twentieths of a lattice
  unit, the apoapsis in sector ⌊(d + 12)/3⌋ mod 8 at a(20 + k).
- **Planets and the judge.** An exclusion planet (centre −64 … 64, radius 1 … 8, clear of the star) is struck when its
  centre comes strictly closer than its radius to a tick segment, decided with integer dot and cross products; grazing
  is safe. Targets (1 … 6) are sweeps (a sector and a share band) or apsis targets (periapsis or apoapsis, a sector and
  a distance range); each has an event tick (a sweep's first tick in its sector, or T; periapsis 0; apoapsis T/2).
  Playing fails `contact` at the first strike (lowest tick, then planet); otherwise the targets are walked in order:
  an earlier event tick than the previous target's fails `order`, a share outside its band `share`, an apsis in another
  sector `apsis-sector`, at a distance outside its range `apsis-distance`; all met wins.
- **Actions.** `periapsis(k, d)` and `size(a)` each spend one action (refused `r02-g18.action` when out of range,
  unchanged or invalid; `r02-g18.budget` with no action left); `play` spends nothing and ends the level won or failed
  with the named failure. The orbit report (positions, shares, apsis readings, the largest residual, each target's
  deviation, the first unmet target and the predicted outcome) and its words are reported after every action. Undo and
  redo are exact; undo from failed returns to playing before the play; a won level is final.
- **Life and stored form.** Stages loading, tutorial, playing, paused, won, failed, result; records with previous and
  next fingerprints replay a play exactly; the level's stored form is JSON schema 1 with a SHA-256 fingerprint,
  re-checked on decode (damaged, edited, newer and older forms refused; reversed bands, duplicate targets, a planet over
  the star and a starting orbit that is invalid or already wins are refused). The rules are an R02-F23 `PuzzleRules`
  over orbits.
