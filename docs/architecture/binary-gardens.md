# Binary Gardens (R02-G21)

Experience `r02-g21.binary-gardens` (free), a puzzle of twin suns over tiny garden worlds: the player moves each star to
a nearer or farther distance ring, shifts where along its orbit it stands, turns its brightness up or down and tilts the
orbit plane, then commits the light window, so that every garden world keeps a comfortable stretch of light across a
full cycle without freezing, scorching, wilting or bleaching. Code lives in `Packages/ExperiencesRound02/BinaryGardens`;
this page grows with each feature of R02-G21. Every orbit is a quantized analytic circle and every rule is decided
exactly on integers; the catalog's "numerical gravitation in fixed steps" and its 0.008333 s timestep belong to the
presentation of later features.

## Rule kernel (feature 501, R02-G21-01)

- **One cycle.** 48 phase steps of 7.5°; every speed is a whole number of steps per tick, so tick 48 returns to the
  start. Angles come from a fixed integer cosine table at scale 1024 (quarter wave 1024, 1015, 989, 946, 887, 812, 724,
  623, 512, 392, 265, 134, 0, the rest by symmetry); positions are integers at scale 2^20 and squared distances at
  2^40, all within 64-bit integers.
- **Bodies.** Exactly two stars share one angular speed (1 … 3 steps per tick); each has a ring (2 … 8 increasing radii
  of 1 … 40 units), a phase 0 … 47 and a luminosity (1 … 4 levels of 1 … 64). The orbit plane tilts 0 … T_max steps
  (T_max 0 … 6). The stars keep a minimum separation σ (0 … 16 units) at every tick. One to five worlds orbit in the
  base plane (radius 1 … 60, phase 0 … 47, speed −4 … 4).
- **Light.** Each star gives ⌊1000·L·2^40 / max(D, r_min²·2^40)⌋ milliflux to a world at squared distance D (clamp
  radius r_min 1 … 8); the two shares add. Each world has four bounds 0 ≤ lethal low < comfortable low ≤ comfortable
  high < lethal high ≤ 200 000, a required window W (1 … 48) and a bloom band for the flux summed over the cycle.
- **The judge.** The lethal walk covers ticks 1 … 48 + E (tolerance E 0 … 12; a tick past 48 repeats the next cycle, so
  a run straddling the boundary counts whole): at each tick, worlds in ascending order, a run longer than E fails
  `frozen` or `scorched` by the band of the tick that exceeds it, naming the walk tick. Without that, worlds are judged
  one at a time: a longest cyclic comfortable window shorter than W fails `unstable`, then a summed flux below or above
  the bloom band fails `wilted` or `bleached`; otherwise the level is won.
- **Actions.** `ring`, `phase`, `luminosity` and `tilt` each spend one action of a budget of 1 … 24 and must change an
  adjustable control while keeping the separation (refused `r02-g21.action`, or `r02-g21.budget` with none left); the
  run spends nothing and ends the level won or failed. The light report (flux at every tick with each star's share and
  band, each world's window with its start tick, cyclic lethal run, integral and bloom result, the minimum separation
  and its earliest tick, the first failure and the predicted outcome) and its words follow every action. Undo and redo
  are exact.
- **Life and stored form.** Stages loading, tutorial, playing, paused, won, failed, result; records with previous and
  next fingerprints replay a play exactly; the level's stored form is JSON schema 1 with sorted keys and a SHA-256
  fingerprint, re-checked on decode in a fixed order (`r02-g21.malformed`, `.newer-schema`, `.level`). The rules are an
  R02-F23 `PuzzleRules` (`BinaryGardensPuzzle`) over arrangements, with at most 120 moves.

## Content pipeline (feature 502, R02-G21-02)

- **Phase step.** A level may restrict star phases to multiples of a step g (1, 2, 3, 4, 6, 8, 12, 16 or 24); g = 1 is
  the default and is left out of the stored form, so every feature-501 level keeps its bytes and fingerprint.
- **Manifest.** 100 planned levels (`BinaryGardensManifest`), 20 per band with budgets 8 … 19 and the five control
  emphases; the catalog's "81" is the original milestone, 001 … 080 extend it and 081 … 100 are the parity expansion.
- **Generator.** `BinaryGardensGenerator` draws a winning arrangement first from the band's profile and sets each
  world's bounds from its winning run in exact integers, then a starting arrangement; candidates are seeded per index
  (at most 64) and skipped when the separation cannot be kept, a bound would be 0, the kernel refuses the level, the
  level is reducible, it repeats the previous level or the solver's minimal plan is not the band's length 1, 2, 3, 3, 4.
- **Solver.** `BinaryGardensSolver` searches breadth-first over the puzzle's legal moves, skipping arrangements reached
  at any depth and expanding each depth in loss order, within a work bound of 5 000 arrangements judged (counted, never
  timed); its plan carries the arrangements counted at each smaller depth as the minimality proof and the nearest miss.
  Measured on the real catalog: 23 464 arrangements judged in all, at most 1 589 for one level.
- **Witnesses and digest.** `BinaryGardensWitness` writes `docs/games/binary-gardens/levels/NNN.witness.json` (schema
  1, sorted keys, compared byte for byte; rewritten only with `BINARY_GARDENS_WRITE_WITNESSES=1`), and the catalog
  digest `PuzzleCatalog<BinaryGardensPuzzle>.digest(id: "binary-gardens", …)` is pinned in a test. The pipeline's five
  sources live in `Core/Content`, so the kernel's own scans stay unchanged.

