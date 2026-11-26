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

## Content pipeline (feature 472, R02-G18-02)

- **Manifest.** `ApsidesWorkshopManifest` holds the 100 planned levels of the archived design (number, planned seed,
  band 1 … 5, moves budget 8 … 19, control emphasis), 20 per band.
- **Generator.** Candidate c of an entry draws from `SeededRandom(seed: SeedDerivation.derive(seed, index: c))`: a
  period, a valid winning orbit, sweep targets from its shares and apsis targets from its apsides with bands of
  band-dependent half-widths, the targets ordered by event tick, planets placed beside its path and clear of it, then
  one or both levers moved away to make the start. Band profiles grow from one or two loose sweeps and one lever (band
  1) to three or four tight targets with one or two apsis targets, two or three planets and both levers (band 5).
  Adjacent levels never share their targets; at most 256 candidates per entry (the real catalog needs at most index 8).
- **Solver.** The orbits reachable with d tunings are the valid orbits that differ from the start in d levers (the knob,
  the size); depth 1 then depth 2 are searched in a fixed order, each orbit judged by the kernel's report with the apsis
  targets checked first from the orbit's steps. The first win is minimal; the orbits judged at smaller depths are the
  proof. Work is counted (at most 13 900 orbits in the catalog, bound 16 000). Two tunings go size first unless the
  winning eccentricity is lower, so every orbit in between is valid.
- **Certificates.** `docs/games/apsides-workshop/levels/NNN.witness.json` (schema 1) holds each level, its tunings and
  the play, a state digest after every action, the play fingerprints, the terminal report (shares, apsides, the largest
  Kepler residual, deviations) and the counterexample; the tests rebuild all 100 byte for byte and pin the catalog
  digest. Witness lengths average 1.0, 1.0, 1.25, 2.0 and 2.0 by band, under R02-F24's progression rule.

## Hero renderer and experience (feature 473, R02-G18-03)

- **Snapshot.** `ApsidesWorkshopSceneSnapshot` is all the renderer reads: the current orbit's steps and integer
  positions, the starting orbit's positions (the ghost loop), the orbiter at the shown tick, the shares, the apsis
  readings, the planets, a gauge per target (band, reading, deviation, met) and the stage, failure, actions and level.
- **The compass.** One fixed scale for every level (s = 0.9 / 16 384, the sky bound at radius 0.9), so tuning never
  rescales the picture. In painter's order with depth testing off: the midnight backdrop with sparse star specks, the
  swept-area wedges (one triangle per tick, deep rose in target sectors), the compass of eight spokes and a notched rim
  with target brackets, the ghost loop, the glacial orbit loop through every kernel position (refined between ticks on
  the analytic ellipse at the richer tiers, presentation only), the periapsis diamond and apoapsis square, hatched
  planets, the star, the orbiter, the target gauges and the actions bars; the glow is additive and last.
- **Tiers.** `level-0`: 24 × 16 spheres, 4 refinement points per tick, 2 glow shells; `level-1`: 16 × 12, 2 points, 1
  shell; `level-2`: flat discs, chords only, no glow. Everything else is identical at every tier.
- **Shaders.** GLSL ES 3.00 compass and glow programs with material codes in the uv stream (the shared mesh renderer
  binds only position, normal and uv); a won level brightens the orbit loop and lights every gauge mark; Reduce Motion
  holds the star's pulse at 1 and Reduce Flashing caps the glow.
- **Adapter.** `ApsidesWorkshopExperienceCore` opens certified level (seed mod 100) + 1, accepts `orbit.periapsis`,
  `orbit.size`, `orbit.play`, `play.undo`, `play.redo`, `level.next` and `clock.show`; its digest is the level number
  and the play's fingerprint (never the shown tick); snapshot schema 1.
- **Experience.** The presenter draws with the fixed camera, logs tier changes, falls back to the unlit level-2
  geometry when a program fails, and declares two backdrop probes; the minimal control panel steps the eccentricity,
  direction, size and shown tick and plays, undoes, redoes and moves to the next level. The candidate is registered in
  the one app (not available until X-R02-G18) with its scenario manifest (standard scenarios, fixtures and the 80
  acceptance rows R2-G18-QA-001 … 080).

## Gameplay spatial interaction (feature 474, R02-G18-04)

- **Picking.** At touch-down the parts are projected through the drawn camera and tried in order: the orbiter within
  its projected disc grown by 8 points, then the size handle (the apoapsis square) and the periapsis knob (the
  diamond) each grown by 12 points, then the orbit loop within a 10-point band; anything else is empty space.
- **Gestures.** Dragging the knob (16 points or more, while playing) previews the periapsis under the finger: the
  direction is the nearest 15° step of the finger's bearing from the star, and the eccentricity is the step that
  puts the periapsis at the finger's distance (a finger on the star keeps the current direction). Dragging the size
  handle previews the size that puts the apoapsis at the finger's distance. The preview is a dashed ghost loop with
  its gauges, drawn only for a valid orbit; an invalid one says why ("The periapsis would dip into the star", "The
  apoapsis would leave the sky"). Lifting sends one `orbit.periapsis [k, d]` or `orbit.size [a]` when the orbit is
  valid and differs, otherwise nothing. Dragging the orbiter cranks the shown tick to the nearest projected position
  (presentation only, in any stage). Two fingers orbit the view within yaw ±60° and pitch −20° … +35°; an empty
  double tap or "Reset view" returns to the authored view. A finished play explains itself in words; second fingers
  and cancels send no kernel action.
- **Panel parity.** Eccentricity, direction and size − and + move a pending orbit, previewed like a drag, with no
  action spent; "Set periapsis" and "Set size" commit it as one action each, only when valid and different. The
  pending orbit follows the current orbit after every accepted action. A host test wins all 100 certified levels
  through the panel within their budgets.

## Teaching and progression (feature 475, R02-G18-05)

- **Hints.** From the current orbit the solver searches the fewest tunings that win within the actions left
  (`plan(_:from:)`; the certifying search is the same entry at the starting orbit). The hint escalates from the lever
  ("Turn the periapsis knob next", "Change the size next") to the way and distance ("Raise the eccentricity by n steps
  and turn the periapsis m steps counterclockwise", the shorter turn, counterclockwise on a tie; "Grow the orbit by n
  units") to the exact setting ("Set the periapsis to eccentricity k, direction d°", "Set the size to a"); a winning
  orbit says "play the revolution"; no plan says so and suggests undo or retry. Following exact hints from every
  opening and then playing wins all 100 levels within their budgets.
- **Failure text.** The play's failure is put in words in the level's own terms: the planet struck and the tick, the
  target reached out of order, the share swept outside its band (one decimal of a percent), or the apsis in the wrong
  sector or at the wrong distance (hundredths of a unit), targets numbered from 1.
- **Tutorial.** Levels 1 … 3 show three instructions (shape and aim the orbit with the knob; bring every target into
  its band and play; what fails a revolution), each advancing when done; dismissible; undo never moves it back.
- **Progress.** Stars by actions spent against the certified plan (3 at most, 2 within two more, else 1), level 1 open
  and a campaign win opening the next, five bands of 20; the daily level is (days since 2026-01-01 × 23) mod 100 + 1;
  practice raises the budget to 24 without stars or unlocks. The snapshot is schema 2 (digest domain
  `r02-g18.apsides-workshop.v2`) with a migration from schema 1.

## Polish and accessibility (feature 476, R02-G18-06)

- **Feedback.** `ApsidesWorkshopFeedbackPlan.after(old:new:)` turns each change of the adapter core into one
  announcement and one haptic through the shared route: a periapsis tuning ("Periapsis set: eccentricity 0.ee,
  periapsis at d°.") or a size tuning ("Size set to a.") followed by the targets met in order, whether playing now
  would win and the actions left (`state`, selection), undo and redo, a won play (`outcome`, success, with stars
  outside practice), a failed play (the failure explanation, `outcome`, warning), a level or mode change (`level`) and
  refusals in words (`rejection`, error). The play, which always ends the level, plans only its outcome; showing a tick
  or dismissing the tutorial plans nothing. The presenter keeps a feedback log.
- **Comfort.** `ApsidesWorkshopLights` eases the glow (0.7 playing, 1 won, 0.35 failed) and the won look by the frame
  clock (0.15 s, 0.45 s under Reduce Flashing, no reversal mid-fade); the scene draws the eased levels (`u_won`, the
  glow gain, and in the unlit fallback the not-won and won colours blended by the won level), so no element crosses
  half its range more than three times a second. Reduce Motion and Reduce Flashing hold the star pulse at 1, so the
  sky is still between actions.
- **Sound.** Off by default (a Sound toggle). Each change of the pending orbit through the panel (− and + or the
  adjustable values; never a drag preview) plays its audition: the size tone 220 Hz × 2^(n/12), n = (48 − a) / 4
  rounded down, with a fifth (eccentricity step k ≤ 7) or a fourth (k ≥ 8) when the orbit can be set, or with a
  partial 3 Hz above when it cannot, 0.6 s. The ambient loop comes from the actions left (the root), the quarters of
  the targets met in order (the partials) and the stage; it is rebuilt only when that recipe changes and plays only
  while wanted, on screen and active.
- **Panel.** A summary element ("a actions left. <progress>. Pending: size a, eccentricity 0.ee, periapsis at d°.
  Level: <level>."), the pending eccentricity, direction and size adjustable with VoiceOver, a value in words on every
  control, refusals in the feedback plan's words, rows that become columns at accessibility text sizes and a
  520-point readable width on iPad.

## Persistence and replay (feature 477, R02-G18-07)

- **Saves.** The one app's shared saved-state store writes the snapshot atomically; schema 3 is `{"level", "mode",
  "progress", "records", "sound", "tutorial"}` and migrates from schema 1 and 2 (2 → 3: every result an empty trace,
  unverified, sound off). The shown tick, a pending orbit, a drag preview and the camera are presentation and are not
  saved.
- **Reconcilable scores.** A campaign or daily win stores the winning trace — the effective periapsis and size tunings
  in order (an undone tuning left out unless redone), then the play — with the result. On restore
  `ApsidesWorkshopReconciliation` replays every trace on a fresh play of its certified level and keeps the result only
  when it wins, spends at most the recorded actions and its stars match the stars rule; the frontier is restored as
  saved. Dropped results are counted (`reconciliationDropped`, never digested) and announced once.
- **Replay.** `replay.start [level]` opens mode `replay(level)` for a level with a verified trace, `replay.step` applies
  the next action (a tuning, finally the play), `replay.stop` returns to the campaign; other play actions are refused
  (`r02-g18.replay`), nothing is recorded and no stars are claimed. A save taken mid-replay restores only when its
  records are the start of that trace.
- **Settings.** The sound choice is saved through `settings.sound [0 … 1]`, snapshotted but never digested, and applied
  when the experience opens.
