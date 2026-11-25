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

## Content pipeline (feature 462, R02-G17-02)

- **Manifest.** `CelestialEclipseLabManifest` holds the 100 planned levels of the archived design (number, planned seed,
  band 1 … 5, moves budget 8 … 19, control emphasis), 20 per band.
- **Generator.** Candidate c of an entry draws from `SeededRandom(seed: SeedDerivation.derive(seed, index: c))`: the
  body count, a depth rank per body (a Fisher–Yates shuffle), each body's period 4 … 8, centre, semi-axes, direction
  and tilt — its orbit positions read from a fixed integer table of cos and sin × 1000, so no floating point enters a
  rule — and radius 1 … 4 (body 0 fixed); the horizon; winning phases; the target as the first eclipse events of the
  winning timeline with windows of 0 … 2 ticks either side; then some movable bodies moved away. A candidate is kept
  when the level rules accept it, its target sequence differs from the previous level's and the solver certifies a
  minimal plan in its band's range (1 … 2, 2 … 3, 3 … 4, 3 … 4, 4 … 5 phase changes); at most 256 candidates.
- **Solver.** A later phase change of a body overrides an earlier one, so the settings reachable with d changes are the
  phase vectors differing from the start on d movable bodies; the solver tries them by depth (subsets, then phases, in
  lexicographic order), judging each with a pair-interval table built once per level (every pair's intervals for every
  pair of phases, merged in timeline order and walked by the kernel's judge). The first win is minimal; the settings
  judged at each smaller depth are the counted proof; work is bounded at 60 000 settings.
- **Witnesses and catalog.** `docs/games/celestial-eclipse-lab/levels/NNN.witness.json` (schema 1, sorted keys): the
  level, the actions and the run, a state digest after every action, the play fingerprints, the terminal timeline with
  visibility classes, the counterexample, the difficulty and the candidates skipped; decoding re-checks everything by
  replay. The catalog digest over the 100 fingerprints is pinned; the progression rule holds and band means never fall.

## Hero renderer and candidate experience (feature 463, R02-G17-03)

- **Snapshot and purity.** `CelestialEclipseLabSceneSnapshot` copies what the renderer may read: the bodies, the current
  phases, every body's lattice position at the shown tick, the eclipses under way at that tick with their classes, the
  target, the predicted intervals and matched count, the failure, the shown tick, the chosen body, the stage, actions
  left, budget, level number and presentation time. The renderer never holds the kernel.
- **The sky.** Lattice positions map to world space by w(v) = (v − m) · s, m the centre of the bounding box of every
  orbit position widened by each body's radius, s = 1.5 / (e + 1). Drawn back to front by camera distance: the ink-navy
  backdrop with sparse specks, the orbital rings with notches ((index mod 6) + 1) and square frames for fixed bodies,
  the ivory body spheres with layered shading, the shadow lens of every eclipse under way (the exact intersection of the
  two projected circles, generated as geometry between the back and the front body, so the crescent seen is the overlap
  judged), corona-gold halos for total and annular eclipses, the dashed chosen ring, and below the sky the timeline
  (window brackets, matched diamonds, the failing cross, the playhead) and the actions bars. The shared mesh renderer
  binds only position, normal and uv, which is why the crescent is geometry rather than a shader mask.
- **Tiers.** `level-0` spheres of 24 × 16 segments and 2 glow shells, `level-1` 16 × 12 and 1 shell, `level-2` flat
  20-sided discs and no glow; everything else is identical at every tier.
- **Experience.** `CelestialEclipseLabExperienceCore` adapts the kernel (`orbit.phase`, `clock.run`, `play.undo`,
  `play.redo`, `level.next`, `orbit.choose`, `clock.show`; digest = level number and play fingerprint; snapshot schema
  1) and opens certified level (seed mod 100) + 1 from the witnesses' candidate indices. The iOS target
  `CelestialEclipseLabExperience` has the presenter (tier log, fallback, Reduce Motion and Reduce Flashing, probes), the
  GL sky scene and a minimal control panel. Registered as a candidate (not available) until X-R02-G17, with the scenario
  manifest of 94 scenarios including the 80 acceptance rows.

## Gameplay spatial interaction (feature 464, R02-G17-04)

- **Picking.** At touch-down every planet is projected through the drawn camera; a planet is hit within its projected
  disc radius grown by 8 points, the front-most (painted last) first. The time dial is the projected box of the
  timeline strip and its window brackets grown by 8 points; anything else is empty space.
- **Gestures.** A tap on a planet chooses it (any stage). Dragging a movable planet along its orbital ring (16 points
  or more, while playing) previews the orbit position nearest to the finger: a dashed ghost of the planet and the
  predicted timeline of that phase; lifting sets the phase there as one undoable action, or nothing when it is the
  current phase. A fixed planet, or a finished play, explains itself in words instead. Dragging or tapping the timeline
  shows the nearest projected tick (presentation only). Two fingers orbit the view within yaw ±60° and pitch −20° …
  +35°; an empty double tap or "Reset view" returns to the authored view. Second fingers, cancels and finished plays
  send no kernel action.
- **Panel parity.** Phase − and + move a previewed pending offset (no action spent) and "Set phase" commits it as one
  action, so every certified level can be won through the panel within its budget; a host test wins all 100.

## Teaching and progression (feature 465, R02-G17-05)

- **Hints.** From the current phases the solver searches the fewest phase changes that win within the actions left
  (`plan(_:from:)`; the certifying search is the same entry at the starting phases). The hint escalates from the planet
  ("Move planet b next") to the way and distance ("… k steps forward", the shorter way round, forward on a tie) to the
  exact phase ("Set planet b to phase p"); already-ordered phases say "run the clock"; no plan says so and suggests undo
  or retry. Following exact hints from every opening and then running wins all 100 levels within their budgets.
- **Failure text.** The run's failure is put in words with the planets, the target (numbered from 1) and the ticks: an
  unwanted eclipse first, a target outside its window, or the horizon reached before the sequence was complete.
- **Tutorial.** Levels 1 … 3 show three instructions (move a planet along its orbit; make the targets happen in order
  and run; what fails a run), each advancing when done; dismissible; undo never moves it back.
- **Progress.** Stars by actions spent against the certified plan (3 at most, 2 within two more, else 1), level 1 open
  and a campaign win opening the next, five bands of 20; the daily level is (days since 2026-01-01 × 29) mod 100 + 1;
  practice raises the budget to 24 without stars or unlocks. The snapshot is schema 2 with a migration from schema 1.

## Polish and accessibility (feature 466, R02-G17-06)

- **Feedback.** `CelestialEclipseLabFeedbackPlan.after(old:new:)` turns each change of the adapter core into one
  announcement and one haptic through the shared route: a phase change ("Body j set to phase p." then the eclipses in
  order, whether a run now would win and the actions left, `state`, selection), undo and redo, a won run (`outcome`,
  success, with stars outside practice), a failed run (the failure explanation, `outcome`, warning), a level or mode
  change (`level`) and refusals in words (`rejection`, error). The run, which always ends the level, plans only its
  outcome; choosing a body or showing a tick plans nothing. The presenter keeps a feedback log.
- **Comfort.** `CelestialEclipseLabLights` eases the glow (0.7 playing, 1 won, 0.35 failed) and the won look by the
  frame clock (0.15 s, 0.45 s under Reduce Flashing, no reversal mid-fade); the scene draws the eased levels (`u_won`,
  the glow gain, and in the unlit fallback the not-won and won colours blended by the won level), so no element crosses
  half its range more than three times a second. Reduce Motion and Reduce Flashing hold the halo pulse at 1, so the sky
  is still between actions.
- **Sound.** Off by default (a Sound toggle). Choosing a body plays its audition: body j's tone 220 Hz × 2^(2j/12)
  with its fifth when it takes part in an eclipse of the predicted timeline, or with a partial 3 Hz above when it does
  not, 0.6 s. The ambient loop comes from the actions left (the root), the quarters of the target matched in order (the
  partials) and the stage; it is rebuilt only when that recipe changes and plays only while wanted, on screen and
  active.
- **Panel.** A summary element ("a actions left. <progress>. Chosen: body j at phase p. Level: <level>."), the chosen
  planet and its pending phase adjustable with VoiceOver, a value in words on every control, refusals in the feedback
  plan's words, rows that become columns at accessibility text sizes and a 520-point readable width on iPad.

## Persistence and replay (feature 467, R02-G17-07)

- **Saves.** The one app's shared saved-state store writes the snapshot atomically; schema 3 is `{"level", "mode",
  "progress", "records", "sound", "tutorial"}` and migrates from schema 1 and 2 (2 → 3: every result an empty trace,
  unverified, sound off). The chosen planet, the shown tick, a pending phase and the camera are presentation and are
  not saved.
- **Reconcilable scores.** A campaign or daily win stores the winning trace — the effective phase changes in order
  (an undone change left out unless redone), then the run — with the result. On restore
  `CelestialEclipseLabReconciliation` replays every trace on a fresh play of its certified level and keeps the result
  only when it wins, spends at most the recorded actions and its stars match the stars rule; the frontier is restored
  as saved. Dropped results are counted (`reconciliationDropped`, never digested) and announced once.
- **Replay.** `replay.start [level]` opens mode `replay(level)` for a level with a verified trace, `replay.step`
  applies the next action (a phase change, finally the run), `replay.stop` returns to the campaign; other play actions
  are refused (`r02-g17.replay`), nothing is recorded and no stars are claimed. A save taken mid-replay restores only
  when its records are the start of that trace.
- **Settings.** The sound choice is saved through `settings.sound [0 … 1]`, snapshotted but never digested, and
  applied when the experience opens.

