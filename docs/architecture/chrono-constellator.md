# Chrono Constellator (R02-G06) — rules

Experience `r02-g06.chrono-constellator` (free) of the one VisualCore app; package `Packages/ExperiencesRound02`, target
`ChronoConstellatorCore` (feature 351, R02-G06-01). A few stars each travel round their own fixed loop of cells on a small
sky grid. The player edits a timeline — where on its loop each star starts and short holds in which a star waits — and
replays it; the level is won when every star stands on its own target on the same tick, without two stars ever meeting
on one cell, within the tick limit. Everything here is pure, exact integer logic; drawing, controls and sound come in
later features of R02-G06.

## Sky and stars

- **Grid.** 5 … 12 columns by 5 … 10 rows, indexed row-major.
- **Stars.** Two to five; star i has the fixed shape ring, cross, diamond, triangle or square and is described in words,
  number and shape (`ChronoConstellatorLevel.description(ofStar:)`), so stars are told apart without colour. Each star
  has a loop of 4 … 32 distinct cells in travel order (consecutive cells, and the last and the first, are 4-neighbours),
  a default start phase and a target cell on its loop. Targets are pairwise distinct; loops may share cells, which is
  where stars can collide.
- **Limits.** An edit budget of 1 … 20 and a tick limit of 1 … 1,200 ticks of 1/120 s (10 s).

## The timeline

`ChronoConstellatorTimeline` holds each star's start phase φ and its holds (star, start s ≥ 1, length 1 … 60, ending by
the tick limit); a star's holds neither overlap nor touch. Star i stands at tick t on

    loop_i[(φ_i + t − h_i(t)) mod L_i]

where h_i(t) counts its held ticks among ticks 1 … t. Positions follow from this formula alone, so any tick can be
computed directly (rewind, scrubbing, the solver's phase search) and stepping tick by tick gives the same cells. The
edits in use are the stars whose phase differs from the level's default plus the holds; an edit that would bring them
above the budget is refused. The timeline's own SHA-256 fingerprint (phases and holds) is the signed snapshot replays
are compared by.

## Verdict

After every tick t ≥ 1, in this order: **collision** (two stars on one cell; the failure names the lower-numbered pair
and the cell), **win** (every star on its own target), **time** (t reaches the tick limit). Nothing is judged at tick 0,
so a level is never won before the replay starts. Because targets are distinct, a win and a collision never coincide;
two stars swapping neighbouring cells on one tick do not collide.

## Play

`ChronoConstellatorPlay` moves through loading, tutorial, playing, paused, won or failed and result. `phase(star,
offset)`, `hold(star, start, length)` and `release(star, start)` edit the timeline and are accepted only at tick 0;
`step(n)` replays 1 … 1,200 ticks and stops at the deciding tick; `rewind` returns to tick 0 with the timeline kept (also
from failed, as an honest retry). Steps and rewinds spend nothing. An action is checked in this order — stage, previous
fingerprint, range, edits only at tick 0, the edit's own rule (same phase, overlapping hold, missing hold), budget — and
refused without change (`r02-g06.stage`, `.stale`, `.action(…)`, `.budget`). Every accepted action, undo and redo
appends a record with the previous and next play fingerprints (SHA-256 of the schema, level fingerprint, tick,
timeline fingerprint, edits in use, stage and failure). Every action can be undone and redone (snapshots); undo works in
playing, paused and failed (a failed play returns to playing), and a won play is final. A record trace replays to the
same records and outcome (`ChronoConstellatorPlay.replay`); pauses are not records, but the stage is in every
fingerprint, so the replay pauses or resumes where a record's previous fingerprint says so.

## Stored form and contract

Levels are JSON schema 1 with sorted keys and their fingerprint; decoding re-checks every rule and the fingerprint and
refuses damaged, edited and newer forms (`r02-g06.malformed`, `.newer-schema`). `ChronoConstellatorRules` expresses the
game as an R02-F23 `PuzzleRules`: at tick 0 the moves are each phase change, each hold on the grid of starts 1 … 32 and
lengths 1 … 32 that the play accepts, each release, then a single step of the tick limit; after tick 0 only a rewind.

## Content pipeline (feature 352, R02-G06-02)

- **Manifest.** `ChronoConstellatorManifest` holds the archived design's 100 levels (number, planned seed, band, move
  budget 8 … 19); the chapter header's "78 stages" is a milestone figure only.
- **Generator.** Candidate k of a level draws from `SeededRandom(seed: SeedDerivation.derive(plannedSeed, index: k))`: per
  band a grid of 6 × 5, 6 × 5, 7 × 6, 7 × 6 or 8 × 7 with 2, 3, 3, 4 or 5 stars; each star a rectangle loop of 2 … 5 by
  2 … 4 cells, clockwise or reversed; distinct targets; random default phases; a tick limit of 120 … 360. A candidate is
  kept when the solver certifies a smallest edit count in the band's range (1; 2; 2; 3; 3 … 4) with at least the band's
  number of collision-blocked windows (0; 1; 2; 2; 3) and the witness wins while the default timeline does not; at most
  512 candidates (the worst level needs 88).
- **Solver (integer-tick phase search).** m(T) counts the stars off target at tick T under the default timeline; each
  edit acts on one star, so m* = min m(T) is a lower bound on every winning timeline. The windows are the ticks with
  m(T) = m*; a window's phase-only timeline re-phases exactly the stars off target, and it is blocked when two stars meet
  on the way. The first unblocked window proves the count exactly. An independent brute force (every phase-only timeline
  of fewer edits, plus one hold on the small levels) agrees on levels 1, 11, … 91.
- **Witnesses.** `docs/games/chrono-constellator/levels/NNN.witness.json` (schema 1): the level, the actions, the win
  tick, a 16-hex position digest per tick, the play fingerprints, the lower bound and windows, the unedited and near-miss
  counterexamples, the difficulty and the skipped candidates; decoding re-solves and refuses any difference. The catalog
  digest over the 100 fingerprints is pinned (`6483b20e…`).

## Experience and renderer (feature 353, R02-G06-03)

- **Adapter.** `ChronoConstellatorExperienceCore` opens certified level (seed mod 100) + 1 (each level generated once
  per process, on first use) and accepts `star.phase [star, phase]`, `star.hold [star, start, length]`,
  `star.release [star, start]`, `time.step [ticks]`, `time.rewind`, `play.undo`, `play.redo` and `level.next`; values
  out of range or fractional and kernel refusals change nothing. Its digest is the level number and the play
  fingerprint; snapshot schema 1 `{level, records}` restores by replay.
- **Snapshot.** The presenter draws an immutable `ChronoConstellatorSceneSnapshot` (grid, every star's loop, target,
  cell and the cells of its last 24 ticks, the timeline's phases and holds, stage, failure, tick, tick limit, edits left,
  level number and presentation time); it never holds the kernel, so no drawing result can change the game.
- **Scene.** The grid lies in the xz-plane with cell size u = 2 / max(columns, rows): the indigo field (#0B0A24) with
  faint grid lines, silver tracks (0.08·u wide) along each loop, star nodes (radius 0.3·u at height 0.25·u) drawn with
  their shapes (ring, cross, diamond, triangle, square), rose target rings (outer radius 0.42·u) with the same shape,
  lit while the star stands on them, hold bars, an amber diagonal cross on a collision cell, and the current-tick mark
  (a silver bar along the near edge, tick / tick limit of the grid's width). Each star trails a
  history ribbon over the tier's last R ticks, rising 0.04·u per tick of age, its alpha 1 − age/R, with a gentle shimmer
  from presentation time only. The camera looks from +z, pitched 55° down, fitted to the bounding sphere of the grid and
  the ribbons' full height with a 5 % margin for aspects 0.4 … 2.5.
- **Shaders.** GLSL ES 3.00 on the shared `ShaderMeshRenderer`: the field program carries the material code and shade in
  uv; the glow program carries the colour in the normal slot and the age in ticks and glow weight in uv, and computes
  the ribbon fade itself. Reduce Motion holds the shimmer still; Reduce Flashing caps the glow at 0.5.
- **Tiers.** level-0: ribbons of 24 ticks, 4 segments per tick, 2 glow shells; level-1: 12, 2, 1; level-2: 6, 1, 0.
  Stars, targets, tracks and the camera never change between tiers; each tier change is logged with its reason. A
  program that fails to compile draws the level-2 geometry unlit and keeps its reason. Depth testing is off on this
  path, so the draw order is the layering and back faces are culled.
- **Candidate.** Registered in `Catalog/registrations.json` (100 levels, digest 6483b20e…6ffc) and linked into the one
  app; it stays unavailable until X-R02-G06. Its scenario manifest has the standard scenarios, `full-playthrough`,
  `hero`, three fixtures and the 80 acceptance rows R2-G06-QA-001 … 080 (row r opens level (7 × (r − 1)) mod 100 + 1).

## Touch controls (feature 354, R02-G06-04)

- **Orbit.** `ChronoConstellatorOrbit` (yaw ±40°, pitch 30° … 75°, authored 0° and 55°) and
  `ChronoConstellatorSceneGeometry.camera(_:aspect:orbit:)`: the distance is refitted so the sky stays inside the view
  with a 5 % margin at every orbit and aspect 0.4 … 2.5. Two fingers orbit (90° of yaw per view width, 60° of pitch per
  view height); a double tap on empty space or "Reset view" returns to the authored view. The orbit is presentation
  only: never in the digest, the snapshot or the kernel, and not saved.
- **Picking.** `ChronoConstellatorPicker` casts the touch ray through the drawn camera against the star node spheres
  (nearest hit), then the field plane: a hit within 0.25·u of the near edge is the timeline band (its x fraction), any
  other hit a cell; otherwise the nearest projected star within 22 points. `loopIndex` finds a star's loop cell under
  the finger or within 22 points; `tick` maps the plane hit's x fraction to round(tickLimit × fraction).
- **Gestures.** `ChronoConstellatorGestureController` (host-tested, event timestamps only): a star dragged at least 16
  points at tick 0 sends one `star.phase` to the loop index under the finger; a touch in the timeline band (or within
  22 points of the tick bar) scrubs: `time.step` forward, or `time.rewind` then `time.step` back (a won play scrubs
  nothing, and a failed play only scrubs back); a long press (0.5 s within 10 points) on a star at tick 0 toggles its standard hold (`star.hold [s, 1, 10]`
  or `star.release [s, 1]`); a tap on a star picks it in the panel. A second finger or a cancelled touch sends nothing.
  While a star is dragged its candidate cell gets a silver ring drawn with the field program and the description names
  it; a star gesture after tick 0 says that edits are made at tick 0. Refused actions are shown and their codes kept.
- **Panel.** Every gesture has a panel equivalent (star picker, phase − and +, holds, steps, run, rewind, undo, redo,
  next level, Reset view); a host test wins all 100 certified levels through panel actions alone.

## Teaching and progression (feature 355, R02-G06-05)

- **Hints.** `ChronoConstellatorHints.plan` reads the current play: run when the timeline already wins (the ticks to the
  win), rewind after tick 0, remove the first hold at tick 0, or the certified solver's phase changes from the current
  phases (accepted only within the edit budget and when the timeline then wins); a rewind or hold removal is offered only
  when the state it leads to has a plan, so a plan exists exactly when following the hints wins. Three levels reveal what,
  which star and exactly where; a won play has no hint, a failed play's hint offers undo, rewind or retry. Exact hints
  from the start win all 100 certified levels.
- **Failures.** `ChronoConstellatorFailureExplanation` names the colliding stars, cell and tick, or every star off its
  target at the tick limit with its cell and target.
- **Tutorial.** Levels 1 … 3: shift a star's start until the timeline wins, replay, align every star on the same tick;
  each step advances when done (a level won on its first replayed tick goes from replay to done), dismissible, never
  moved back by undo.
- **Progress.** `ChronoConstellatorProgress`: level 1 open, a campaign win opens the next, stars 3/2/1 by the edits in use
  against the certified smallest count (+2), five bands of 20. Daily level (days since 2026-01-01 × 59) mod 100 + 1
  from `mode.daily [y, m, d]` (the presenter reads the local date; the core reads no clock); practice raises the budget to
  20 and never records. The adapter adds `level.select`, `mode.daily`, `mode.practice`, `mode.campaign` and
  `tutorial.dismiss` (`r02-g06.locked`, `r02-g06.date`); `level.next` moves to the next open level. Snapshot schema 2
  `{level, mode, progress, records, tutorial}` with a migration from schema 1; digest v2 adds progress and mode.

## Polish and accessibility (feature 356, R02-G06-06)

- **Feedback.** `ChronoConstellatorFeedbackPlan.after(old:new:)` derives one announcement and one haptic from the old and
  new state: phase changes, holds, releases, steps, rewinds, undo and redo as `state` with a selection haptic ("Star k
  (shape) starts at row r, column c. n edits left." …), wins and failures as `outcome` (success or warning; a step that
  ends the level plans only the outcome), level and mode changes as `level`, refusals in words as `rejection` with an
  error haptic. The presenter routes plans through the shared `ExperienceFeedback` (the person's haptics switch, the
  shared rate limits) and keeps a feedback log; the panel shows refusals in the same words.
- **Comfort.** `ChronoConstellatorLights` eases each target ring (1 lit, 0.5 unlit), each star node (1 on target, 0.7
  off), the win glow and the collision mark over 0.15 s, or 0.45 s under Reduce Flashing where a started fade finishes
  before it turns back; the geometry draws the eased levels and the collision mark fades out at its remembered cell.
  The ribbon shimmer (0.35 Hz) is still under Reduce Motion; the glow is capped at 0.5 under Reduce Flashing. None of it
  reaches the state or the digest.
- **Sound.** `ChronoConstellatorSoundRecipe` builds a 12-second ambient loop from the stars on target and the stage (a
  110 Hz root, one partial per star on target, an octave on a win, halved gains on a failure); `ChronoConstellatorSound`
  plays it only while the Sound toggle is on, the panel is on screen and the scene is active.
- **Panel.** Every control has a label and a value; a summary element reads the tick, the edits left and every star; the
  star picker is adjustable and announces its pick; rows become columns at accessibility text sizes and the panel keeps
  a 520-point readable width on iPad.

## Persistence and replay (feature 357, R02-G06-07)

- **Saves.** The one app's shared store writes the experience's snapshot atomically; Chrono Constellator's payload is
  schema 3 `{level, mode, progress, records, sound, tutorial}`, migrating 1 → 2 → 3 (2 → 3: every result an empty
  trace and unverified, the sound off). The digest (v3) covers the level, the play, the progress with its traces and the
  mode; never the tutorial step, the sound choice or the count of dropped results. The state reads no clock and no
  random source: the seed, the certified catalog, the date given to `mode.daily` and the recorded actions decide it.
- **Reconcilable scores.** A campaign or daily win stores the winning trace — the net actions of the play
  (`ChronoConstellatorReconciliation.netTrace`: phase changes, holds, releases, steps and rewinds, an undone action
  left out unless redone) — as a verified result, replacing a stored one only when better. On restore every traced
  result is replayed on a fresh play of its certified level and kept only when it wins with exactly the recorded edits
  and stars (a trace over 64 actions or with an illegal action never verifies); untraced results from older saves are
  kept unverified; the frontier is restored as saved. The presenter announces the number dropped once.
- **Replay.** `replay.start [level]` replays a verified trace action by action (`replay.step`) and `replay.stop`
  returns to campaign; during replay other play actions are refused (`r02-g06.replay`), nothing is recorded and a
  replayed win claims no stars (`r02-g06.no-replay`, `r02-g06.replay-end` for the other refusals). The panel shows
  Replay, Step and Stop with the position.
- **Settings.** The sound choice (`settings.sound [0 … 1]`) is saved in the snapshot and applied when the experience
  opens.

## Regression net (feature 358, R02-G06-08)

- **Solver.** For all 100 levels, in tests of 10: the generated level equals its witness's level, the witness's actions
  replay to a win at its win tick with its per-tick digests and fingerprints, and the solver returns exactly the
  witness's phase changes with its lower bound, window, windows and blocked count; its work stays within the tick limit
  plus the window ticks. Twelve kinds of alteration (a star's loop cell, start phase or target, the budget, the tick
  limit, the grid size, a solution phase, a witness action, per-tick digest or fingerprint, the lower bound, the window)
  each fail naming the level and the part. Work is counted, never timed.
- **Golden frames.** `ChronoConstellatorGolden` (test builds only; forbidden in the Release binary) describes 16 frames —
  levels 1, 21, 41, 61, 81 at three tiers after their certified phase changes and 6 ticks, plus the hero frame — at
  1,152 × 768: projected star, target and loop-cell centres (to 1/8 px, null off screen), the tick, the tick mark's
  length (to 1/1,024 cell), the tier's detail and the palette. The descriptions and SHA-256 digests are pinned in
  `golden-frames.json`; a recomputed description passes on an equal digest or within one quantum with everything else
  equal, and the file is rewritten only with `CHRONO_CONSTELLATOR_WRITE_GOLDEN=1`. The simulator renders the same frames
  and checks them with the feature-353 frame tolerances.
- **Memory.** Twelve open-draw-warn-close cycles on the simulator keep the footprint within 16 MB of the first cycle
  (bound applied when the class runs alone) and leave the sky scene holding no GPU objects (`liveObjectCount` 0) after
  each close and memory warning.
- **Where it runs.** CI's host job has a named "Chrono Constellator regression (host)" step; locally,
  `python3 scripts/chrono_constellator_regression.py` runs the host and simulator parts with one summary line each.

## In-app integration (feature 359, R02-G06-09)

- **Identifiers.** Every panel control carries `experience.r02-g06.chrono-constellator.<name>`
  (`ChronoConstellatorControls.identifierNames`, 28 names: phase-down, phase-up, add-hold, remove-hold, step-1, step-10,
  run, rewind, undo, redo, next-level, reset-view, hint, dismiss-tutorial, failure-undo, failure-rewind, retry,
  campaign, daily, practice, play-level, replay, replay-step, replay-stop, star-picker, level-picker, sound, summary).
- **Interface tests.** `CRPlayUITests` wins level 1 through the panel (its certified solution: Phase + once on star 1,
  from phase 7 to 8 of its 10-cell loop, then Run; the win comes on tick 3: "Every star stands on its target",
  "Stars: 3 of 3", level 2 open) and keeps the progress over a relaunch; `CRReplayUITests` replays the win (two actions)
  to its end and stops. They run as serial chunk `o3`, each under 90 s. Level 1's certified phase changes, default
  phases and loop lengths are pinned in `CR` and checked against the Core by an app unit test.
- **Stored examples.** The registration stores schema-1 and schema-2 examples (`ChronoConstellatorSchemaExamples`),
  which the app restores into schema 3 (a schema-2 result without a trace is kept, unverified); Chrono Constellator
  stays a candidate (not available without `-vcCandidates`) until X-R02-G06.
- **Release.** The Release simulator build compiles without the test-only golden descriptions and scenarios.

## Device preparation (feature 360, R02-G06-10)

- **Contract, no device touched.** `docs/apps/chrono-constellator/device-rows.json` (schema 1 of feature 310) names the
  device scenario set (the 11 standard and game scenarios and `fixture-level-1-solved`), the devices D1 iPhone 15, D2
  iPad Pro 13-inch (M5) and D3 iPad (A16) on iPadOS 26.5 tied to DEV1/2/3-R02-G06, and rows CR-D1 … CR-D8: launch and
  first frame, frame pacing per tier, memory and thermal state with the stress session, touch feel and touch-to-frame
  (star drags, timeline scrubs, hold presses, orbit), sound and haptics, VoiceOver at the largest text size
  (non-gating), progress across a real termination, and the panel journeys. Every row is "pending device campaign"; the
  written plan is [`docs/apps/chrono-constellator/device-campaign.md`](../apps/chrono-constellator/device-campaign.md).
- **Check.** `python3 scripts/check_device_rows.py --experience r02-g06.chrono-constellator` (release step
  `device-rows-r02-g06`) proves every scenario exists, every row is complete and every {device} task of features
  351–359 and every UA-F13 measurement is covered.

