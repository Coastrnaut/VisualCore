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

## Hero renderer and experience (feature 503, R02-G21-03)

- **Snapshot.** `BinaryGardensSceneSnapshot` is all the renderer reads: the arrangement (rings, phases, luminosities,
  tilt), the ring radii, luminosity levels, maximum tilt and phase step, each world's light at every tick (flux, each
  star's share, band), window, lethal run and bloom result, the shown tick, and the stage, failure, actions and level.
- **The system.** One scale per level, k = 0.95 / R with R the largest ring or world radius; every orbit is a 48-gon
  through the kernel's own cosine-table points, so each body sits on a vertex of its drawn orbit. Drawn in painter's
  order with depth testing off (the window surface has no depth buffer): the backdrop with a hashed starfield, orbit
  rings, the tilt dial, trails of fixed tick positions, bodies back to front (cube-sphere worlds with their faces
  emitted far-first, star discs in vermilion and ice blue with luminosity pips), one gauge row per world (48 tick cells,
  comfort guide lines, the window bracket, the shown-tick marker, the bloom meter) and the actions bars; the glow is
  additive and last. A failure marks the failing element broken on a failed play; a won level blooms every world.
- **Lighting.** Each world is shaded by both stars' shares at the shown tick through a logarithmic response, with a
  sunrise band along each terminator over an ambient floor of 0.35, and seasonal banding by latitude: ice caps when
  lethal low, dim caps, open flowers when comfortable, a scorched belt when bright or lethal high.
- **Tiers.** `level-0`: 8 × 8 quads per cube face, 12 corona rays, 8-tick trails, 8 motes, 2 glow shells; `level-1`:
  5 × 5, 6 rays, 4-tick trails, 4 motes, 1 shell; `level-2`: 3 × 3 with the banding kept and no rays, trails, motes or
  glow.
- **Shaders.** GLSL ES 3.00 system and glow programs with 38 material codes in the uv stream (code + 0.4 · value, + 64
  when drawn broken); motes and coronas move by the time uniform times the motion uniform (0 under Reduce Motion);
  Reduce Flashing caps the glow.
- **Adapter.** `BinaryGardensExperienceCore` opens certified level (seed mod 100) + 1 from a table of each witness's
  skipped candidates, accepts `star.ring`, `star.phase`, `star.luminosity`, `orbit.tilt`, `light.run`, `play.undo`,
  `play.redo`, `level.next` and `clock.show` (declared 0 … 60; 0 and 49 … 60 refused with `r02-g21.tick`); the shown
  tick opens at 48 and is never digested; its digest is the level number and the play's fingerprint; snapshot schema 1.
- **Experience.** The presenter draws with the fixed camera, logs tier changes, falls back to the unlit level-2
  geometry when a program fails, and declares two backdrop probes; the panel chooses a star and steps its ring, phase
  (by the phase step), luminosity and the tilt, steps the shown tick and runs, undoes, redoes and moves on. The
  candidate is registered in the one app (not available until X-R02-G21) with its scenario manifest.

## Gameplay spatial interaction (feature 504, R02-G21-04)

- **Picking.** `BinaryGardensPicker` projects the drawn snapshot (the preview applied) through the drawn camera
  (`BinaryGardensSceneGeometry.camera(aspect:orbit:)`, the view orbit included) and tries the parts drawn last first:
  the actions bars (empty space), a gauge row's plate, the bodies front to back from the drawn eye (a star's luminosity
  pip row within 12 points, then its disc grown by 12 points; a world's disc grown by 12 points), a star ring within 12
  points of its projected 48-gon (later rings first), the tilt dial within 12 points (only when T_max > 0), the system
  disc, else empty space.
- **Gestures.** `BinaryGardensGestureController` turns touches into actions. A star drag of 16 points or more is a
  phase drag when its travel along the projected orbit tangent exceeds its travel across it, else a ring drag (the
  star's freedoms override); a pip or dial tap takes the nearest pip, a pip or dial drag counts 32 points per step.
  While dragging, the target is previewed (`BinaryGardensPreview`: the kernel's own report for the changed arrangement,
  or its refusal), the dragged star drawn as a ghost (material 38) and the changed gauge cells as ghost cells (39);
  lifting sends exactly one `star.ring`, `star.phase`, `star.luminosity` or `orbit.tilt` when the target is a change.
  A world tap inspects it (marks 40 and 41 and its words at the shown tick); a second tap clears it. Scrubbing a gauge
  row shows ticks (`clock.show`, presentation only). Two fingers orbit the view within yaw ±60° and pitch −20° … +35°;
  a double tap on empty space or "Reset view" returns to the authored view. A finished play explains itself in words;
  the preview, the inspection and the orbit never enter the digest, and an opening, `level.next`, a reset or a restore
  clears them; the presenter recognises a new play by the level number and the play's records (the shell gives
  no reset or restore hook, as for feature 494), so a reset or restore that leaves the shown play unchanged keeps the
  inspection and the orbit.
- **Panel parity.** The panel keeps every row and gains a Ring picker, a Luminosity picker, a phase target stepper by
  the phase step with "Set phase", a Tilt picker (when T_max > 0), "Inspect" with the inspected world's words and "Reset
  view"; each choice sends one action through the presenter, which shows refusals in words and keeps their bare codes in
  `refusalLog` (at most 64). A host test wins all 100 certified levels through the panel, one panel action per witness
  action.

## Teaching and progression (feature 505, R02-G21-05)

- **Hints.** `BinaryGardensHints` gives the certified witness's remaining actions while every one of the seven controls
  holds its starting or its certified value and the actions left cover them, so exact hints from every opening replay
  the witness (1 … 4 actions) and win all 100 levels with the certified count; otherwise it searches at most two legal
  arrangement moves from the current arrangement in the puzzle's fixed order, one before two, at most 2,000 arrangements
  judged. The hint escalates from the kind of change ("Move a star to another ring", "Shift a star's phase", "Change a
  star's brightness", "Tilt the orbit plane") to which star and which way ("Move star n outward", "Shift star n's phase
  forward", "Make star n dimmer", "Tilt the orbit plane less") to the exact action ("Move star n to ring r (ρ units)",
  "Set star n's luminosity to L", "Set the tilt to t of T steps"); a winning arrangement says to run the cycle; no plan
  says so and suggests undo or retry. The presenter runs the search off the main actor, once per play, with a
  generation counter so a stale search never owns the hint.
- **Failure text.** `BinaryGardensFailureExplanation` puts the run's failure in words: the world that froze or scorched
  and the tick (in the level's tick words), the world whose comfortable window was too short with the ticks needed, or
  the world that wilted or bleached with its total light and bloom band, worlds numbered from 1, each followed by
  "Undo the last action or retry the level." The panel and the description show this explanation; the one-line status keeps
  its short words ("Failed: …"), which the feature-503 render tests assert.
- **Tutorial.** Levels 1 … 3 show three instructions (adjust a star; balance every world's light, then run; what fails
  a run), each advancing when done (an accepted arrangement action, then a second one or the level's end, then the
  level's end); dismissible; undo, redo and showing a tick never move it back.
- **Progress.** Stars by actions spent (undone ones included) against the certified plan's actions (3 at most, 2
  within two more, else 1), level 1 open and a campaign win opening the next (no wrap after 100; a fresh opening of
  level N opens 1 … N), five bands of 20; the daily level is (days since 2026-01-01 × 13) mod 100 + 1 and is playable
  while still locked without opening it; practice raises the budget to 24 without stars or unlocks. The panel shows the
  band, the goal ("Win in at most k actions for 3 stars", "1 action" in the singular), the best stars, the modes and a stepper over the open levels. The snapshot is schema 2 (digest domain
  `r02-g21.binary-gardens.v2`) with a migration from schema 1; locked means not yet won, never paid for.

## Polish and accessibility (feature 506, R02-G21-06)

- **Feedback.** `BinaryGardensFeedbackPlan.after(old:new:)` turns each change of the adapter core into one
  announcement and one haptic through the shared route: a star moved to a ring ("Star n moved to ring r (ρ units)."),
  shifted in phase, its luminosity set, the tilt set, undo and redo, each followed by the worlds keeping their light,
  whether running now would win or fail and the actions left (`state`, selection); a won run (`outcome`, success, with
  the actions spent and stars outside practice), a failed run (the failure explanation, `outcome`, warning), a level or
  mode change (`level`) and refusals in sentences (`rejection`, error). The run plans only its outcome; showing a tick,
  previews and dismissing the tutorial plan nothing; a revealed hint is announced as `state`. The presenter keeps a
  feedback log beside the tier log and the refusal log.
- **Comfort.** `BinaryGardensLights` eases the glow (0.7 playing, 1 won, 0.35 failed), the won look and each world's
  bloom by the frame clock (0.15 s, 0.45 s under Reduce Flashing, no reversal mid-fade); the scene draws the eased
  levels (`u_won`, the glow gain, each world's shell factor in the glow mesh rebuilt at each 1/32 step, and in the
  unlit fallback the not-won and won colours blended by the won level, rebuilt per tenth), so no element crosses half
  its range more than three times a second. The corona rays and motes hold still under Reduce Motion or Reduce
  Flashing; a won run's motes appear with the outcome. When a frame's time is earlier than the last frame's (an off-screen still drawn after
  live frames), the lights settle at once, so a still never shows a half-finished fade.
- **Sound.** Off by default (a Sound toggle). Choosing a star plays its audition: the tone 220 Hz × 2^(n/12), n = 2 ×
  (7 − ring index), with a fifth when the star can change or a partial 3 Hz above when it cannot, 0.6 s. The ambient
  loop's root (110 Hz × 1, 9/8, 5/4, 4/3) comes from the actions left, up to four partials from the quarters of the
  worlds keeping their light, a brightness partial from the stars' luminosities, an octave when won and halved gains
  when failed; it plays only while wanted, on screen and active (`BinaryGardensSound`).
- **Panel.** A summary element, the star, ring, phase, luminosity, tilt and tick adjustable with VoiceOver (", locked"
  for a locked control), a value in words on every control, refusals in the feedback plan's sentences, rows that become
  columns at accessibility text sizes and a 520-point readable width on iPad; the same behaviour at every tier and in
  the fallback; a sent refusal reads in the feedback plan's sentence, while a refused preview (never sent
  and never announced) keeps feature 504's short words inside "That change would be refused: …".

## Persistence and replay (feature 507, R02-G21-07)

- **Saves.** The one app's shared saved-state store writes the snapshot atomically; schema 3 is `{"level", "mode",
  "progress", "records", "sound", "tutorial"}` (digest domain `r02-g21.binary-gardens.v3` over the level, the play
  fingerprint, the progress with its traces and the mode) and migrates from schema 1 and 2 (2 → 3: every result an
  empty trace, unverified, sound off). A result writes its trace and `verified` only when they are not empty or false,
  so untraced results keep their schema-2 form. The shown tick, the selected star, previews, the inspected world, the
  hint level and the view are presentation and are not saved.
- **Reconcilable scores.** A campaign or daily win stores the winning trace: the effective ring, phase, luminosity and
  tilt actions in order (an undone action left out unless redone), then the run. On restore
  `BinaryGardensReconciliation` replays every trace (at most 64 actions) on a fresh play of its certified level and
  keeps the result only when it wins, spends at most the recorded actions and its stars match the stars rule; the
  frontier is restored as saved. Dropped results are counted (`reconciliationDropped`, never digested) and announced
  once ("n saved results could not be checked and were removed.").
- **Replay.** `replay.start [level]` opens mode `replay(level)` for a level with a verified trace (else
  `r02-g21.no-replay`) with tick 48 shown, `replay.step` applies the next action and keeps the shown tick (finally the
  run; `r02-g21.replay-end` after it), `replay.stop` returns to the campaign; showing a tick, dismissing the tutorial
  and the sound setting stay allowed, other play actions are refused (`r02-g21.replay`), nothing is recorded and no
  stars are claimed. A save taken mid-replay restores only when its records are the start of that trace. The panel
  offers Replay, Step and Stop with the replay position.
- **Settings.** The sound choice is saved through `settings.sound [0 … 1]`, snapshotted but never digested, and applied
  when the experience opens.

## Regression net (feature 508, R02-G21-08)

- **Solver regression.** For all 100 levels the generated level equals its witness part by part, the witness replays
  to a win on exactly its final run (not before) with its per-action fingerprints, digests and report, and the minimal
  solver returns exactly the witness's actions with its depth counts, nearest miss and work, within its work bound of
  5,000 (counted, never timed); thirteen kinds of alteration on levels 1, 41 and 81 (a world's comfortable band, lethal
  bound, bloom band, required window or orbit, a ring radius, a luminosity level, a star's start, the lethal
  tolerance, the budget, a plan or witness action, a per-action fingerprint or digest, the counterexample's count) are
  each detected and named. Ten tests of ten levels.
- **Golden frames.** `BinaryGardensGolden` (debug and automation builds only; forbidden in Release) describes 17
  frames (levels 1, 21, 41, 61 and 81 at three tiers and level 25 at tier 0, after their certified actions but not the
  run, tick 24 shown, plus the hero frame) by projected positions in eighths of a pixel (the barycentre, the worlds,
  the stars, the first gauge plate, the first actions bar and, on level 25, the first tilt pip), element counts, the
  stars' controls, each world's light, the whole palette and the material table, pinned with SHA-256 digests in
  `golden-frames.json` (written after R02-G21-04 … 07 were recorded) and rewritten only with
  `BINARY_GARDENS_WRITE_GOLDEN=1`. The simulator renders the same frames and checks them with the feature-503
  tolerances; level 25's first tilt pip, which feature 503 never checked, must show a pixel at least 0.05 from the
  backdrop in luminance within the larger of 3 px and the pip's projected outer radius (the gauge-margin rule).
- **Memory.** Twelve open–draw–warn–close cycles on the simulator stay within 16 MB of the first (bound applied when the
  class runs alone) and release every GPU object of the scene.
- **Running it.** CI's round-two job (half b) has a "Binary Gardens regression (host)" step;
  `python3 scripts/binary_gardens_regression.py` runs the host and simulator parts with one summary.

## In-app integration (feature 509, R02-G21-09)

- **Identifiers.** Every panel element has an identifier `experience.r02-g21.binary-gardens.<name>`; the 56 names are
  pinned in `BinaryGardensControls.identifierNames` and each is used once (the failure explanation has its own
  `explanation`; the level line carries none). The star row is two buttons, "Star 1" and "Star 2", in one adjustable
  element: a segmented picker's segment taps never reached its selection under interface automation.
- **Interface tests.** `BGPlayUITests` opens the candidate in the one app, wins level 1 through the panel alone (choose
  star 2, lower its luminosity one level, then Run) with "Every world kept its window and bloomed." and "Best: 3 of 3
  stars", sees level 2 open and keeps the progress over a relaunch; `BGReplayUITests` replays the solved level to its
  end and stops back to the campaign. They run in the serial release-check chunk `d4`.
- **Stored examples.** `schemaOneExample()` (level 1 after star 2's ring change) and `schemaTwoExample()` (level 1
  solved with 2 actions and 2 stars) are registered with the app, which restores both into schema 3; app unit tests
  also open the candidate through the registry and engine, win level 1 and confirm it is not available without the
  testing argument.
- **Builds.** The app compiles in debug and release for the simulator with the game linked; the release symbol check
  confirms the test-only golden source and scenarios are absent.
