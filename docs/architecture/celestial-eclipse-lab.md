# Celestial Eclipse Lab (R02-G17)

Experience `r02-g17.celestial-eclipse-lab` (free), a puzzle of miniature bodies on their orbits seen from one side: the
player turns the movable bodies to new phases, then runs the clock, so that the eclipses (one body's disc passing in
front of another's) come in exactly the target order, each inside its window, with no other eclipse first. Code lives
in `Packages/ExperiencesRound02/CelestialEclipseLab`; this page grows with each feature of R02-G17. Every rule is
decided in exact integers on ticks of the miniature clock; the catalog's 0.008333 s timestep is a presentation clock of
later features.

## Rule kernel (feature 461, R02-G17-01)

- **Bodies.** 2 … 6 bodies, each on a periodic orbit of 4 … 24 lattice positions (coordinates −32 … 32), with a disc
  radius 1 … 8 and a fixed flag (at least one body movable). With phase p, a body is at tick t at orbit position
  (t + p) mod period. The projection drops z; a greater z is nearer the viewer.
- **Depth order.** Every pair of bodies keeps one front-to-back order at every tick (the front body's smallest z above
  the back body's largest z), checked when the level is built, so every eclipse names its front and back body; a target
  eclipse naming the back body of its pair as the front one is refused.
- **Eclipses.** Two bodies eclipse at a tick when the squared distance of their projected centres is strictly below the
  square of the sum of their radii; touching discs do not. An eclipse event is the first tick of each run; an interval
  runs to its last tick, and its visibility class is the deepest over its ticks: total (the front disc covers the back
  one), annular (the front disc lies inside the back one) or partial.
- **The judge.** The timeline orders the intervals by first tick, then front body, then back body. Walking the events:
  an event equal to the next target inside its window matches it; equal to the next target outside its window fails
  `window`; any other event fails `unwanted`; no events left with targets remaining fails `horizon`; events after the
  last match are ignored.
- **Actions.** `phase(body, offset)` sets a movable body's phase and spends one action (refused `r02-g17.action` for an
  unknown or fixed body or an offset outside the period or unchanged; `r02-g17.budget` with no action left); `run`
  spends nothing and ends the level won or failed with the named failure. The predicted timeline and its words are
  reported after every action. Undo and redo are exact; undo from failed returns to playing before the run; a won level
  is final.
- **Life and stored form.** Stages loading, tutorial, playing, paused, won, failed, result; records with previous and
  next fingerprints replay a play exactly; the level's stored form is JSON schema 1 with a SHA-256 fingerprint,
  re-checked on decode (damaged, edited, newer and older forms refused). The rules are an R02-F23 `PuzzleRules` over
  phase vectors.
