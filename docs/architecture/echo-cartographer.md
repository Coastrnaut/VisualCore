# Echo Cartographer (R02-G11) — rules

Experience `r02-g11.echo-cartographer` (free) of the one VisualCore app; package `Packages/ExperiencesRound02`, target
`EchoCartographerCore` (feature 401, R02-G11-01). The player stands in a dark chamber of which only the entry is known.
Pulses sent from known open cells reveal the walls they strike and the floor they cross, and the hidden beacons answer
with echoes whose delays tell how far each one is along the open floor. From echoes taken at several cells the player
works out where every beacon must be and claims it, before the energy runs out. Everything here is pure, exact integer
logic; drawing, controls and sound come in later features of R02-G11.

## Chamber, rays and echoes

- **Chamber.** A grid of W × H cells (W, H 5 … 16); cell (x, y) has the index y · W + x; every cell is open or a wall
  (a whole unit square), and the border counts as a wall (`EchoCartographerChamber`). The entry is an open cell; 1 … 4
  beacons sit on distinct open cells other than the entry, each reachable from the entry by side steps through open
  cells.
- **Knowledge.** What the player knows of each cell: unknown, open or wall. It starts with only the entry open and only
  grows (`EchoCartographerKnowledge`).
- **Pulse.** From a cell known open, four rays in the order north (−y), east (+x), south (+y), west (−x). A ray steps
  cell by cell; every open cell it enters becomes known open and the first wall cell it enters becomes known wall (at
  the border nothing more is revealed). Its travel distance is the number of steps to the struck wall or border (1 when
  the neighbour is a wall).
- **Echoes.** Each beacon answers with its path length: the fewest side steps through open cells from the emitter (0 on
  the emitter), by breadth-first search. The echoes are reported sorted, without naming the beacon.
- **Delays.** Every ray and echo has a round-trip delay of 24 ticks of 0.008333 s per cell of distance (12 each way);
  delays animate the echoes in later features and never decide a rule.

## Actions and verdict

`pulse(x, y)` costs 1 energy. `claim(x, y)` locates the not-yet-located beacon within the level's tolerance (0 … 2 cells,
the larger of the column and row differences) that is nearest, then in the lowest row, then the lowest column; a hit
is free and makes the beacon's cell known open. A claim with no beacon within the tolerance is a miss: it costs the
level's miss cost (1 … 3), never more than the energy left, and reveals nothing. `mark(x, y)` toggles a free marker
(at most 8) that the player uses to triangulate; markers never decide anything. Refused without change: a cell outside
the chamber, a pulse from a cell not known open, a claim on a known wall, a ninth marker (`r02-g11.action`); a claim
within the tolerance only of beacons already located (`.noop`); the wrong stage (`.stage`) and a stale fingerprint
(`.stale`). After an accepted action, in this order: **win** (every beacon located, whatever energy is left), then
**energy** (energy zero with a beacon still hidden: failed, naming the action). Undo and redo spend nothing and restore
the exact earlier state, energy and knowledge included; undo from failed returns to playing; a won level is final.

## Measures

After every action the play reports each located beacon's localization error (the column-or-row distance between the
claim and the beacon) and their total, beside the last pulse's report; they never decide the outcome. Every ray and
echo distance agrees with an independent recomputation in the tests.

## Stored form

Levels are JSON schema 1 with sorted keys (width, height, walls and beacons as sorted cell indices, entry, tolerance,
energy, miss cost, difficulty, tutorial, seed, id) and their fingerprint; decoding re-checks every rule and the
fingerprint and refuses damaged, edited and newer forms (`r02-g11.malformed`, `.newer-schema`).

## Content pipeline (feature 402, R02-G11-02)

- **Manifest.** The 100 planned levels of the archived design (`EchoCartographerManifest`): number, planned seed, band
  1 … 5 (20 each) and energy 8 … 19.
- **Generator.** Candidate c of entry n draws from `SeededRandom(seed: SeedDerivation.derive(plannedSeed, index: c))`:
  width and height by band (6 … 7, 7 … 9, 8 … 10, 9 … 12, 10 … 14), each cell a wall with chance 1 in 5 (bands 1 … 2)
  or 1 in 4, the entry among the open cells, a region of at least 12 cells, 1 … 4 beacons by band drawn from the region.
  Tolerance 1, 1, 1, 0, 0 and miss cost 1, 1, 2, 2, 3 by band; tutorial on levels 1 … 3. A candidate is kept when its
  witness plan has a pulse count in the band's range (1 … 2, 2 … 3, 3 … 4, 4 … 5, 5 … 6) and at most energy − 1, and the
  witness wins through the play; at most 256 candidates (`r02-g11.generation`). The ranges were measured with a
  prototype before they were written down; over the catalog the band means are 1.95, 2.6, 3.15, 4.45 and 5.35 pulses.
- **Inference proof.** A placement (beacon-count cells of the region) fits when every pulse's sorted echoes are
  reproduced; `EchoCartographerSolver.fitting` counts fits by a pruned enumeration (capped at 1 000). The plan is greedy:
  pulse the known-open cell whose echo leaves the fewest fits (ties: lowest index) until exactly one fits — the true
  beacons. Work (enumeration nodes) is bounded at 400 000; the largest catalog plan used 14 282.
- **Witness files.** `docs/games/echo-cartographer/levels/NNN.witness.json` (schema 1, sorted keys): the level, the
  actions (pulses, then a claim on each beacon), an echo digest per pulse, the fits after each pulse, the play
  fingerprints, the counterexample (two placements that fit every pulse but the last), the difficulty and the
  candidates skipped. Regenerated only with `ECHO_CARTOGRAPHER_WRITE_WITNESSES=1`; decoding re-runs the replay, the
  counts and the plan (`r02-g11.witness`).
- **Catalog.** `PuzzleCatalog<EchoCartographerRules>.digest(id: "echo-cartographer", …)` over the 100 fingerprints is
  pinned; the standard progression rule holds on the witness pulse count; an independent brute force (relaxed path
  lengths, every subset) re-checks the proof on the two smallest regions of each band.

## Hero renderer and experience (feature 403, R02-G11-03)

- **Scene.** The chamber floor is the plane y = 0; with s = 1.8 / max(W, H), cell (x, y) is centred at
  X = (x + 0.5 − W / 2)·s, Z = (y + 0.5 − H / 2)·s. Only what the player knows is drawn: opal floor tiles on known open
  cells, the entry diamond, marker rings, known walls as dark blocks 0.92·s wide and 0.5·s high with sonar-mint edge
  strips, located beacons as cyan pillars and the energy gauge in front of the chamber; unknown cells show the abyss
  ground and unlocated beacons are never drawn (`EchoCartographerSceneSnapshot` holds neither). The last pulse adds its
  rays, an expanding cyan pulse ring (one cell per 0.1 s), echo rings that return at each echo's delay and a flare on
  every wall it struck when the ring reaches it (`EchoCartographerSceneGeometry`, `EchoCartographerShaders`).
- **Order and shading.** Depth testing is off (the shared mesh renderer's path): the flat layers come first, then the
  blocks and pillars back to front by row from the far side (each row from the outside in, for the centred camera),
  then the gauge; tiles, rings and edges are shaded by signed distance from per-vertex local coordinates.
- **Tiers.** level-0: rings, flare trails and two glow shells; level-1: rings and one shell; level-2: none. Cells,
  markers, pillars, rays, colours and the gauge are identical at every tier; the presenter logs tier changes.
- **Camera.** A fixed authored view from above and in front (eye (0, 2.4, 1.9)) fitted to the box x −1 … 1,
  z −1 … 1.1, y 0 … 0.8 with a 5 % margin for aspects 0.4 … 2.5.
- **Adapter.** `EchoCartographerExperienceCore` opens certified level (seed mod 100) + 1 from its table of certified
  candidates and accepts `cell.pulse`, `cell.claim`, `cell.mark` [x, y], `play.undo`, `play.redo` and `level.next`; its
  digest is the level number and the play fingerprint; snapshot schema 1 `{level, records}`.
- **Fallback and settings.** A shader failure draws the level-2 geometry unlit and keeps the reason; Reduce Motion draws
  the rings and flares at rest; Reduce Flashing caps the glow.
- **Candidate.** Registered in `Catalog/registrations.json` (100 levels, digest a32a593b…dca9) and linked into the app
  as a candidate (`ExperienceRegistry.candidates`) until X-R02-G11; the scenario manifest holds the standard scenarios,
  `full-playthrough`, `hero`, 80 acceptance scenarios and three fixtures.

## Gestures (feature 404, R02-G11-04)

- **Picking.** At touch-down the touch ray through the drawn camera meets the floor plane y = 0: a marker whose ring
  centre projects within 22 points wins (the nearest, ties to the lower cell index), then the cell whose square holds
  the hit point inside the chamber; anything else is empty space (`EchoCartographerPicker`).
- **Tap to emit a pulse.** A tap (under 10 points, lifted before 0.5 s by event timestamps) on a cell known open sends
  one `cell.pulse` while playing; a tap on any other chamber cell moves the panel's cursor there and sends nothing.
- **Drag markers to triangulate.** A drag (16 points or more) from a cell without a marker places one where the finger
  lifts (`cell.mark`); a drag from a marker moves it (`cell.mark` on the old cell, then on the new one); releasing on
  its own cell, on a marked cell or outside the chamber sends nothing. The kernel refuses a ninth marker.
- **Hold to claim.** A press held still for 0.5 s and then lifted sends one `cell.claim` of the held cell; moving 10
  points after the hold armed cancels it. The cursor follows every placed, moved or claimed cell.
- **Orbit.** Two fingers orbit (yaw ±35°, pitch −15° … +20°) with the field of view refitted at every aspect 0.4 … 2.5;
  a double tap on empty space or "Reset view" returns to the authored view. Orbit and cursor are never saved and never
  reach the kernel (`EchoCartographerGestureController`); outside the playing stage gestures send no kernel action and
  a finished play says so; refusals are shown with their reason code and logged.
- **Panel.** Every certified level can be won with the column and row steppers, Pulse and Claim alone.

## Teaching and progression (feature 405, R02-G11-05)

- **Hints.** `EchoCartographerHints` plans from the current play: when the echoes heard leave exactly one beacon
  placement the plan is a claim on the lowest-index beacon not yet located; otherwise it continues the certification's
  greedy pulse rule from the current knowledge (`EchoCartographerSolver.continuation`), which must leave at least 1
  energy. Three levels: the kind (pulse or claim), its row, the cell. From a level's opening the continuation is the
  certified plan, so exact hints win every level; a hint never changes the state, and the presenter searches off the
  main actor.
- **Failure explanation.** `EchoCartographerFailureExplanation` names the action that spent the last energy (a pulse or
  a missed claim and its cell), the beacons located, the pulses sent and the claims missed, with undo or retry.
- **Tutorial.** Levels 1 … 3 show three instructions in order — pulse, narrow down with markers and pulses, claim — each
  advancing after an accepted pulse, a located beacon or the level's end; undo never moves it back; it can be dismissed.
- **Progress.** `EchoCartographerProgress`: level 1 open, a campaign win opens the next; stars by energy spent (undone
  records included): 3 at the certified plan's pulse count, 2 within + 2, else 1; five bands of 20; the daily level
  (days since 2026-01-01 × 79) mod 100 + 1 from the date the presenter reads; practice raises the energy to 60 and
  records nothing.
- **Adapter.** Controls `level.select`, `mode.daily`, `mode.practice`, `mode.campaign`, `tutorial.dismiss` (refusals
  `r02-g11.locked`, `r02-g11.date`); digest v2 adds progress and mode; snapshot schema 2 `{level, mode, progress,
  records, tutorial}` with a migration from schema 1.

## Polish and accessibility (feature 406, R02-G11-06)

- **Announcements and haptics.** `EchoCartographerFeedbackPlan` is a pure function of the old and new core: a pulse
  names its rays and echoes, a claim the located beacon or the energy a miss took, a marker its cell, undo and redo
  themselves, each followed by the progress words (`state`, selection haptic); a win names the energy spent and the
  stars and a failure its explanation (`outcome`, success or warning); level and mode changes (`level`); refusals in
  words (`rejection`, error haptic). An action that ends the play plans only its outcome.
- **Comfort.** `EchoCartographerLights` eases the chamber's glow (0.7 playing, 1 won, 0.35 failed) and the won
  brightening over 0.15 s, or 0.45 s under Reduce Flashing, where a started fade finishes before it turns back; the
  scene scales the glow gain and `u_wonLight` by them. The pulse and echo rings and the wall flares restart with every
  pulse, undo or redo, so Reduce Flashing draws them at rest, as Reduce Motion does.
- **Sound.** `EchoCartographerSoundRecipe`: a 110 Hz root stepped by the share of energy left, one partial per located
  beacon, an octave when won and halved gains when failed, looping whole; the presenter's Sound toggle (off by default)
  plays it only while the controls are on screen and the scene is active.
- **Panel.** Every control has a label and a value in words; the column and row steppers are adjustable and name the
  cell and what is known of it; a summary element reads the energy, the beacons located, the last echo, the chosen cell
  and the level; rows become columns at accessibility text sizes and the panel is at most 520 points wide.

## Persistence and replay (feature 407, R02-G11-07)

- **Saves.** Snapshot schema 3 `{level, mode, progress, records, sound, tutorial}` in the app's shared saved-state store
  (atomic writes, unreadable files moved aside, newer schemas refused); migrations 1 → 2 → 3 (2 → 3: results without
  traces, unverified, sound off). Digest v3 adds the traces with the progress; the sound choice and the dropped count
  never enter it.
- **Reconcilable scores.** A campaign or daily win stores its trace — the effective pulses, claims and marks of the
  winning play (`EchoCartographerReconciliation.netTrace`, an undone action left out unless redone) — as a verified
  result. On restore every traced result is replayed on its certified level and kept only when it wins, the energy it
  spends is at most the recorded energy spent and the stars match the rule; dropped results are counted and announced
  once; the frontier is kept as saved.
- **Replay.** `replay.start [level]` replays the best stored solution action by action (`replay.step`, `replay.stop`);
  other play actions are refused with "Stop the replay first."; a replayed win records nothing.
- **Settings.** `settings.sound [0 … 1]` saves the sound choice in the snapshot; the presenter applies it on opening.

## Regression net (feature 408, R02-G11-08)

- **Solver regression.** For all 100 levels, in ten groups of ten: the generated level equals its witness, the witness's
  actions replay to a win in exactly their count (pulses plus beacons) within the energy with the stored per-pulse echo
  digests and per-action fingerprints, and the solver re-finds exactly the witness's pulses with its placements, its
  placements before the last pulse and its counterexample, with work at most 400,000 (the largest is 14,282, level 99);
  ten kinds of alteration (a beacon cell, a chamber wall, the energy, the tolerance, the miss cost, a plan pulse, a
  witness action, an echo digest, a fingerprint, the placements count) each fail naming the level and the part. Work is
  counted, never timed.
- **Golden frames.** `EchoCartographerGolden` (test builds only; forbidden in the Release binary) describes 16 frames
  (levels 1, 21, 41, 61, 81 at tiers 0 … 2 after their first certified pulses and one marker, plus the hero frame) at
  1,152 × 768: the known floor tile centres, wall tops, marker rings, located pillars, the entry and the first gauge bar
  in 1/8 pixel, the counts and the palette, hashed with SHA-256 and pinned in `golden-frames.json`; a recomputed frame
  passes on an equal digest or within one quantum with equal counts and colours, and the file is rewritten only with
  `ECHO_CARTOGRAPHER_WRITE_GOLDEN=1`. On the simulator the same frames are rendered and checked against their
  descriptions with the feature-403 frame checks.
- **Memory.** Twelve open-draw-warn-close cycles keep the footprint within 16 MB of the first cycle when the class runs
  alone (measured growth 0.86 MB) and leave the chamber scene with no GPU objects after every close and memory warning.
- **Running it.** `python3 scripts/echo_cartographer_regression.py` runs the host part and the simulator classes with one
  summary line per part; CI runs the host part as "Echo Cartographer regression (host)".

## In-app integration (feature 409, R02-G11-09)

- **Identifiers.** Every panel control carries `experience.r02-g11.echo-cartographer.<name>`
  (`EchoCartographerControls.identifierNames`, 23 names: pulse, claim, mark, undo, redo, next-level, reset-view, hint,
  dismiss-tutorial, failure-undo, retry, campaign, daily, practice, play-level, replay, replay-step, replay-stop,
  column-picker, row-picker, level-picker, sound, summary).
- **Interface tests.** `ECGPlayUITests` wins level 1 through the panel (its certified actions: pulses from column 0, row
  3 and column 0, row 2, then a claim at column 1, row 2, each cell chosen by stepping the column and row steppers from
  the cursor's cell and tapping Pulse or Claim: "Every beacon is located.", "Stars: 3 of 3.", level 2 open) and keeps
  the progress over a relaunch; `ECGReplayUITests` replays the win (three actions) to its end and stops. They run as
  serial chunk `t3`, each under 90 s apart from the simulator's automation-session setup per launch. Level 1's certified
  actions, the cursor's starting cell (the entry, column 0, row 3) and the 6 × 6 chamber are pinned in `ECG` and
  checked against the Core by an app unit test. The namespace is `ECG` because `EC` is Effects Composer's.
- **Stored examples.** The registration stores schema-1 and schema-2 examples (`EchoCartographerSchemaExamples`, seed
  7), which the app restores into schema 3; Echo Cartographer stays a candidate (not available without
  `-vcCandidates`) until X-R02-G11.
- **Release.** The Release simulator build compiles without the test-only golden descriptions and scenarios.
