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

## Content pipeline (feature 492, R02-G20-02)

- **Kernel extension.** The budget range widens to 1 … 24 (the manifest's budgets reach 19), and a level may list 2 … 8
  pod sites (floor cells without a colony): with sites every pod, starting or placed, must stand on one (the play
  refuses "not a site"; the puzzle contract lists placements on sites only). A level without sites omits the field, so
  feature 491's levels keep their stored form and fingerprints.
- **Manifest.** `MushroomWeatherManifest` holds the 100 planned levels of the archived design (number, planned seed,
  band 1 … 5, budget 8 … 19, control emphasis), 20 per band.
- **Generator.** Candidate c of an entry draws from `SeededRandom(seed: SeedDerivation.derive(seed, index: c))`: the
  floor (rows, columns and blocked cells of the band), the starting humidity, the diffusion, rates, pod rules, growth
  threshold, mold bound, length and required cycles, the colonies, the vents and sites near the colonies and a winning
  arrangement of the band's plan size; the colonies' bands are the winning run's last K cycles widened by the band's
  margin, and sensitive floors are min(low·3/4, the run's minimum). A candidate is skipped when it is invalid, already
  won at the start, reducible, equal in floor and colonies to the previous level, or when the solver's minimal plan is
  not the band's plan. Band profiles grow from 6 … 7 × 6 … 7 floors with one vent, two slots, two colonies, four sites
  and a plan of 2 (band 1) to 8 … 9 × 8 … 10 floors with three vents, four slots, five colonies, six sites and a plan of
  5 (band 5). Levels start with no pod; at most 64 candidates per entry (the catalog needs at most index 2).
- **Solver.** From a start with no pod the distance of an arrangement is its pod count plus the vents toggled plus one
  for a changed moonlight. The solver judges depth 0, 1, 2 …, every depth after 0 ordered by the band loss of each
  arrangement's parent (ties in the fixed order); the first win is minimal and every smaller depth, judged in full, is
  the proof. Work is counted (at most 1,115 arrangements per catalog level, bound 1,500). The nearest miss is the
  smallest loss among the smaller depths.
- **Certificates.** `docs/games/mushroom-weather/levels/NNN.witness.json` (schema 1) holds each level with its sites,
  its actions and the run, a state digest after every action, the play fingerprints, the terminal report (ledger
  totals, each colony's final and longest run and first cycle out of band, cycles run), the counterexample and the
  difficulty; decode replays and rebuilds every stored value. The tests rebuild all 100 byte for byte in 20 groups of 5
  and pin the catalog digest. Witness lengths are 2, 3, 3, 4 and 5 by band, under R02-F24's progression rule.

## Hero renderer and experience (feature 493, R02-G20-03)

- **Snapshot.** `MushroomWeatherSceneSnapshot` is all the renderer reads: the floor (rows, columns, blocked cells), the
  humidity of every cell at each cycle of the predicted run of the current arrangement, the cycles run and the shown
  cycle, the mold bound, each colony's band, survival floor, final and longest run and whether it is in band at the shown
  cycle, the pods with their growth cycles, the sites, the vents with their states, the moonlight, and the stage,
  failure, actions and level.
- **The forest.** Cell (r, c) sits at ((c − (C − 1)/2) · s, ((R − 1)/2 − r) · s) with s = min(1.8 / C, 1.6 / R), so every
  level fills the same box. Drawn premultiplied in a fixed element order with depth testing off (the window surface has
  no depth buffer, as for every round-two game): the still backdrop, the moon with four phase ticks (L + 1 filled), moss
  floor squares, logs and stones on blocked cells, fronds at the richer tiers, mist squares sized by h/M, site rings,
  lathed stalks and translucent caps with moisture beads by h/M and band rings, lathed pods (grown pods larger with a
  second ring), droplets and motes on fixed paths, slatted vent frames, one gauge row per colony and the actions bars;
  the glow is additive and last. A failure marks the failing element broken on a failed stage (a dried colony's cap
  wilts with a broken band ring, a moldy cell gets a broken patch, an unstable colony's marker and run bar turn broken);
  a won level lights every cap without moving anything.
- **Tiers.** `level-0`: lathes of 16 segments, 12 droplets per pod, fronds, 8 motes, 2 glow shells; `level-1`: 10
  segments, 6 droplets, fronds, 4 motes, 1 shell; `level-2`: flat caps and pods, no droplets, fronds, motes or glow.
- **Shaders.** GLSL ES 3.00 forest and glow programs with 29 material codes in the uv stream (code + 0.4 · value, + 32
  when drawn broken; quads span ±1.25 of their shape so the fringe is transparent); droplets and motes move by the time
  uniform times the motion uniform (0 under Reduce Motion); Reduce Flashing caps the glow.
- **Adapter.** `MushroomWeatherExperienceCore` opens certified level (seed mod 100) + 1 from a table of each witness's
  candidate index, accepts `pod.place`, `pod.remove`, `vent.set`, `moon.set`, `weather.run`, `play.undo`, `play.redo`,
  `level.next` and `clock.show` (a cycle outside the run is refused with `r02-g20.cycle`); its digest is the level
  number and the play's fingerprint (never the shown cycle); snapshot schema 1.
- **Experience.** The presenter draws with the fixed camera, logs tier changes, falls back to the unlit level-2
  geometry when a program fails, and declares two backdrop probes; the control panel chooses a slot and a site, places
  and removes pods, toggles each vent, chooses a moonlight level and sets it with one action, steps the shown cycle and
  runs, undoes, redoes and moves to the next level. The candidate is registered in the one app (not available until
  X-R02-G20) with its scenario manifest (the standard scenarios, a three-level playthrough, the hero, fixtures and the
  80 acceptance rows R2-G20-QA-001 … 080).

## Gameplay spatial interaction (feature 494, R02-G20-04)

- **Picking.** `MushroomWeatherPicker` projects the parts through the drawn camera (the view orbit included) and tries
  them in the order drawn last first: a vent within its projected frame grown by 12 points, a pod within its projected
  radius grown by 12 points (later slots first), a site within its projected ring radius grown by 12 points, the moon
  within its projected radius grown by 12 points, then the cycle scrubber (a track at y −0.9 between the floor and the
  gauges) within a 14-point band, then the floor inside its projected rectangle; anything else is empty space.
- **Gestures.** `MushroomWeatherGestureController` turns touches into actions. A tap on an empty site while playing
  places a pod in the first free slot (`pod.place`), or says that every slot is used; a tap on a vent sends its other
  state (`vent.set`). Dragging a pod (16 points or more, while playing) previews the weather with the pod on the site
  nearest the finger within 24 points, or removed when the finger leaves the floor: the previewed mist, caps and gauges
  come from the kernel's own run, and the dragged pod is drawn as a ghost (material 29). Lifting sends one `pod.place`
  or one `pod.remove` when the target is a change, otherwise nothing. Dragging the moon up or down previews the
  moonlight level start + round(−dy / 40), clamped 0 … 3, and lifting sends one `moon.set` when it differs. Dragging the
  scrubber shows the cycle nearest the finger (`clock.show`, presentation only, in any stage). Two fingers orbit the
  view within yaw ±60° and pitch −20° … +35° (the camera refits to keep the box with the moon in view); a double tap off
  the floor or "Reset view" returns to the authored view. A finished play explains itself in words; second fingers and
  cancels send no kernel action; the preview and the orbit never enter the digest.
- **Panel parity.** The panel keeps every action (slot, site, Place, Remove, vent toggles, moonlight − / + with Set
  moonlight, cycles, Run, Undo, Redo, Next level) and gains "Reset view"; its kernel buttons send through the presenter,
  which shows and logs refusal codes with or without the engine's prefix. A host test wins all 100 certified levels
  through the panel, one panel action per witness action.

## Teaching and progression (feature 495, R02-G20-05)

- **Hints.** `MushroomWeatherHints` gives the certified witness's next remaining action while the arrangement lies on
  the way to the witness's (pods a subset, toggled vents a subset, the moonlight the start's or the witness's) and the
  actions left cover the rest, so exact hints from every opening replay the witness (up to 5 actions) and win all 100
  levels within their budgets; otherwise it searches at most two pod, vent or moonlight actions from the current
  arrangement, one before two, at most 1,500 arrangements judged. The hint escalates from the kind of change ("Change a
  spore pod", "Change a vent", "Change the moonlight") to where ("Use the site at row r, column c", "Use vent n",
  "Make the moonlight brighter") to the exact action ("Put pod n on the site at row r, column c", "Close vent n", "Set
  the moonlight to level l"); a winning arrangement says to run the weather; no plan says so and suggests undo or retry.
  The presenter runs the search off the main actor, once per play.
- **Failure text.** `MushroomWeatherFailureExplanation` puts the run's failure in words: the sensitive colony that dried
  out and the cycle, the cell that grew mold and the cycle, or the colony with the shortest final run, its length and
  the cycles required (singular for one), colonies numbered from 1 and cells by row and column.
- **Tutorial.** Levels 1 … 3 show three instructions (put a pod on a marked site; keep every colony in its band by
  another pod, a vent or the moonlight, then run; what fails a run), each advancing when done (a placement, then a
  second action, then the level's end); dismissible; undo never moves it back.
- **Progress.** Stars by actions spent against the certified plan's actions (3 at most, 2 within two more, else 1),
  level 1 open and a campaign win opening the next (no wrap after 100), five bands of 20; the daily level is (days since
  2026-01-01 × 17) mod 100 + 1 and is playable while still locked without opening it; practice raises the budget to 24
  without stars or unlocks. The panel shows the band, the goal, the best stars, the modes and a picker of open levels.
  The snapshot is schema 2 (digest domain `r02-g20.mushroom-weather.v2`) with a migration from schema 1.

## Polish and accessibility (feature 496, R02-G20-06)

- **Feedback.** `MushroomWeatherFeedbackPlan.after(old:new:)` turns each change of the adapter core into one
  announcement and one haptic through the shared route: a pod placed ("Pod n placed at row r, column c."), moved or
  removed, a vent opened or closed, the moonlight set, undo and redo, each followed by the colonies staying in band,
  whether running now would win and the actions left (`state`, selection); a won run (`outcome`, success, "Every colony
  stayed in its band." with the actions spent and stars outside practice), a failed run (the failure explanation,
  `outcome`, warning), a level or mode change (`level`) and refusals in words (`rejection`, error). The run, which
  always ends the level, plans only its outcome; showing a cycle or dismissing the tutorial plans nothing; a revealed
  hint is announced as `state`. The presenter keeps a feedback log.
- **Comfort.** `MushroomWeatherLights` eases the glow (0.7 playing, 1 won, 0.35 failed) and the won look by the frame
  clock (0.15 s, 0.45 s under Reduce Flashing, no reversal mid-fade); the scene draws the eased levels (`u_won`, the
  glow gain, and in the unlit fallback the not-won and won colours blended by the won level, rebuilt per tenth), so no
  element crosses half its range more than three times a second. Motion is 0 under Reduce Motion or Reduce Flashing.
- **Sound.** Off by default (a Sound toggle). Each change of the panel's selection (slot or site; never a drag preview)
  plays the selected site's audition: the tone 220 Hz × 2^(n/12), n = 2 × site index, with a fifth when a pod can be
  placed there or a partial 3 Hz above when it cannot, 0.6 s. The ambient loop's root (110 Hz × 1, 9/8, 5/4, 4/3) comes
  from the actions left, up to four partials from the quarters of the colonies staying in band, a moonlight partial at
  the root × 3, an octave when won and halved gains when failed; it is rebuilt only when that recipe changes and plays
  only while wanted, on screen and active (`MushroomWeatherSound`).
- **Panel.** A summary element ("a actions left. <progress>. Selected: pod n, site at row r, column c. Level:
  <level>."), the slot, site and moonlight adjustable with VoiceOver, each vent toggle "open" or "closed", a value in
  words on every control, refusals in the feedback plan's words, rows that become columns at accessibility text sizes
  and a 520-point readable width on iPad.

## Persistence and replay (feature 497, R02-G20-07)

- **Saves.** The one app's shared saved-state store writes the snapshot atomically; schema 3 is `{"level", "mode",
  "progress", "records", "sound", "tutorial"}` (digest domain `r02-g20.mushroom-weather.v3`) and migrates from schema 1
  and 2 (2 → 3: every result an empty trace, unverified, sound off). The shown cycle, the panel's selection, a drag
  preview, the hint level and the camera are presentation and are not saved.
- **Reconcilable scores.** A campaign or daily win stores the winning trace — the effective pod, vent and moonlight
  actions in order (an undone action left out unless redone), then the run — with the result. On restore
  `MushroomWeatherReconciliation` replays every trace (at most 64 actions) on a fresh play of its certified level and
  keeps the result only when it wins, spends at most the recorded actions and its stars match the stars rule; the
  frontier is restored as saved. Dropped results are counted (`reconciliationDropped`, never digested) and announced
  once ("n saved results could not be checked and were removed.").
- **Replay.** `replay.start [level]` opens mode `replay(level)` for a level with a verified trace (else
  `r02-g20.no-replay`), `replay.step` applies the next action (finally the run; `r02-g20.replay-end` after it),
  `replay.stop` returns to the campaign; other play actions are refused (`r02-g20.replay`), nothing is recorded and no
  stars are claimed. A save taken mid-replay restores only when its records are the start of that trace. The panel
  offers Replay, Step and Stop with the replay position.
- **Settings.** The sound choice is saved through `settings.sound [0 … 1]`, snapshotted but never digested, and applied
  when the experience opens.

## Regression net (feature 498, R02-G20-08)

- **Solver regression.** For all 100 levels the generated level equals its witness, the witness replays to a win on
  exactly its final run (not before) with its per-action fingerprints and digests, and the minimal solver returns
  exactly the witness's actions with the counterexample's arrangements one action short and its nearest miss, within
  its work bound (counted, never timed); twelve kinds of alteration (a colony's band or survival floor, a starting
  humidity, the diffusion, a vent's rate, the pod release, the growth threshold, the mold bound, the budget, a plan or
  witness action, a per-action fingerprint or digest, the counterexample's count) are each detected and named. Ten
  tests of ten levels.
- **Golden frames.** `MushroomWeatherGolden` (debug and automation builds only; forbidden in Release) describes 16
  frames — levels 1, 21, 41, 61 and 81 at three tiers after their certified actions but not the run, shown at half the
  cycles run, plus the hero frame — by the projected floor centre, caps, moon, first gauge track and first actions bar
  in eighths of a pixel, element counts, the moonlight and the 21 palette colours, pinned with SHA-256 digests in
  `golden-frames.json` and rewritten only with `MUSHROOM_WEATHER_WRITE_GOLDEN=1`. The simulator renders the same frames
  and checks them with the feature-493 tolerances.
- **Memory.** Twelve open–draw–warn–close cycles on the simulator stay within 16 MB of the first (bound applied when the
  class runs alone) and release every GPU object of the scene.
- **Running it.** CI's round-two job (half b) has a "Mushroom Weather regression (host)" step;
  `python3 scripts/mushroom_weather_regression.py` runs the host and simulator parts with one summary.
