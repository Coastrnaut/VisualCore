# Mushroom Weather (R02-G20)

Experience `r02-g20.mushroom-weather` (free), a puzzle of a midnight miniature forest floor: the player places spore
pods that breathe out moisture, opens or closes canopy vents and shifts the moonlight, then lets the weather run, so that
every mushroom colony holds its preferred humidity band to the end, without a sensitive colony drying out or any cell
turning to mold. Code lives in `Packages/ExperiencesRound02/MushroomWeather`; this page grows with each feature of
R02-G20. Humidity is a whole number of units per cell and every rule is decided exactly on integers, with a ledger that
accounts for every unit; the catalog's 0.016667 s timestep is a presentation clock of later features.

## Rule kernel (feature 491, R02-G20-01)

- **Floor and units.** A grid of 6 … 12 rows by 6 … 14 columns of floor and blocked cells with a closed boundary;
  humidity is a whole number of units per floor cell, starting 0 … M, where the mold bound M is 1000 … 10000.
- **One cycle.** Three synchronous steps. Diffusion: one flow per pair of orthogonally adjacent floor cells,
  (hₐ − h_b)·D/64 truncated toward zero (D 1 … 12), so water is never created or lost by rounding and, since
  4·12/64 < 1, no cell goes negative. Evaporation: ⌊h·rate·(4 + L)/4096⌋ with each cell's rate 0 … 200 (vent cells
  use their open or closed rate) and the moonlight level L 0 … 3. Release: each pod adds r (1 … 40), or g (r … 80) once
  grown. The ledger of every cycle (before, released, evaporated, after) balances exactly.
- **Growth and colonies.** A pod adds its cell's humidity to its integral after each cycle and is grown from the next
  cycle once the integral reaches G (100 … 200000). A colony (1 … 6) has a band low … high and, if sensitive, a
  survival floor; it is in band in a cycle when low ≤ h ≤ high after that cycle.
- **The judge.** The run walks cycles 1 … T (20 … 200): the lowest-numbered sensitive colony below its floor fails
  `dried`, otherwise the first cell above M in row-major order fails `mold`; after the run the level is won exactly
  when every colony is in band for each of the last K cycles (5 … T), otherwise `unstable` names the colony with the
  shortest final run.
- **Actions.** `place(slot, cell)` puts a pod (on a floor cell without a colony or another pod) into one of 1 … 6 slots
  or moves it, `remove(slot)` empties one, `vent(index, open)` and `moonlight(level)` change a vent or the light; each
  spends one action (refused `r02-g20.action` when out of range, unchanged or on a forbidden cell, or removing an empty
  slot; `r02-g20.budget` with no action left); `run` spends nothing and ends the level won or failed with the named
  failure. The weather report (humidity by cycle, the ledger, growth cycles, each colony's final and longest run and
  first cycle out of band, the first failure and the predicted outcome) and its words are reported after every action.
  Undo and redo are exact; undo from failed returns to playing before the run; a won level is final.
- **Life and stored form.** Stages loading, tutorial, playing, paused, won, failed, result; records with previous and
  next fingerprints replay a play exactly; the level's stored form is JSON schema 1 with a SHA-256 fingerprint,
  re-checked on decode (damaged, edited, newer and older forms refused; cells off the floor or shared, a pod on a
  colony, a sensitive colony below its floor or a cell above M at the start, and a starting arrangement that already
  wins are refused). The rules are an R02-F23 `PuzzleRules` (`MushroomWeatherPuzzle`) over arrangements.
