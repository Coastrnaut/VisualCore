# Nocturne Garden (R02-G09) — rules

Experience `r02-g09.nocturne-garden` (free) of the one VisualCore app; package `Packages/ExperiencesRound02`, target
`NocturneGardenCore` (feature 381, R02-G09-01). The player arranges glowing blooms in a garden bed so that their shadows
form a target flower silhouette without spilling into forbidden outline regions. Everything here is pure, exact integer
logic; drawing, controls and sound come in later features of R02-G09.

## Bed, blooms and sun

- **Bed.** A grid of W × H cells (W 16 … 32, H 12 … 24); cell (column, row) counts from the left and from the ground row
  upward, and is stored as the row-major index row · W + column.
- **Blooms.** Six kinds, each a fixed original simple polygon with integer vertices whose foot is at the origin and whose
  stem rises along +y, within 3 × 6 cells at size 1: tulip (a cup of two upright petals), bell (a narrow crown over a
  flared rim), star (five spikes), fern (alternating leaflets), rose (a round full head) and lily (a trumpet with a wide
  mouth) (`NocturneGardenKind`). A bloom is planted with its foot at the corner (column, row) at size 1 … 3, the outline
  scaled by the size (`NocturneGardenBloom`).
- **Sun.** Four elevations, 1 (high) … 4 (low); the factor e / 2 (1/2, 1, 3/2, 2) stretches every shadow vertically about
  its bloom's foot.

## Shadow mask and measures

A cell is dark for a bloom when its centre lies inside or on the boundary of the bloom's cast polygon; with every
coordinate doubled the test is an exact integer winding number with an explicit on-segment check. The shadow mask is
the union of all blooms' dark cells within the bed (`NocturneGardenMask`). The **match** is |M ∩ T| / |M ∪ T| between
the mask M and the target T, compared with the level's required fraction p / q by cross multiplication (an empty union
never matches); the **leak** is the number of mask cells in the forbidden regions F; the **boundary deviation** (the
truth metric) is the symmetric Chebyshev Hausdorff distance between the boundary cells of M and T, reported after every
action and never deciding the outcome.

## Actions and verdict

`plant(kind, column, row, size)`, `move(bloom, column, row)`, `resize(bloom, size)`, `remove(bloom)` and
`sun(elevation)`; each accepted action spends one move. Refused without change: out of range (`r02-g09.action`), a kind
whose supply is used up (`.supply`), an action that changes nothing (`.noop`), the wrong stage (`.stage`) and a stale
fingerprint (`.stale`). Blooms are kept in canonical order (row, column, kind, size) and named "bloom 1" … in that order;
removing a bloom returns it to the supply. After an accepted action, in this order: **leak** (a leak above the allowance
fails the level, naming the move), **win** (match at least p / q and leak within the allowance), **budget** (moves spent
equal to the budget: failed). A win on the last move counts, and nothing is won before the first bloom.

## Stored form

Levels are JSON schema 1 with sorted keys (bed, target and forbidden cells, supply, sizes, elevations, opening sun,
budget, required match, leak allowance, tutorial, seed, id) and their fingerprint; decoding re-checks every rule and the
fingerprint and refuses damaged, edited and newer forms (`r02-g09.malformed`, `.newer-schema`).

## Content pipeline (feature 382, R02-G09-02)

- **Manifest.** `NocturneGardenManifest` holds the 100 planned levels of the archived design (number, planned seed, band
  1 … 5, move budget 8 … 19). The kernel's ranges already cover every generated level; only the refusals
  `r02-g09.generation` and `r02-g09.witness` were added.
- **Generator.** Candidate k of a level draws from `SeededRandom(seed: SeedDerivation.derive(plannedSeed, index: k))`:
  one bloom size from the band's sizes, a construction sun, the bloom count, the blooms (kind and anchor; each cast
  wholly in the bed and adding at least 3 new cells), the kept cells of the forbidden ring, a decoy kind (bands 3 … 5)
  and the opening sun. The target is the blooms' exact mask. Band profiles: beds 16 × 12 … 32 × 24, required match 4/5,
  17/20, 9/10, 19/20, 1/1, leak allowance 2, 2, 1, 1, 0, smallest move count 2 … 3, 3 … 4, 4 … 5, 5 … 6, 6 … 7 (so
  neighbouring levels keep the progression rule). A candidate is kept when the solver certifies it in its band's range
  and within the budget; at most 256 candidates, then `r02-g09.generation`.
- **Solver.** A winning mask needs at least `needed` = ⌈p·|T|/q⌉ target cells dark; one plant at sun e darkens at most
  `cover(e)` of them without leaking beyond the allowance on its own, so a win under sun e needs at least
  ⌈needed/cover(e)⌉ plants, plus a sun move when e is not the opening sun. `NocturneGardenSolver` takes the least of
  these over the allowed elevations as the lower bound L and finds a sequence of exactly L moves depth-first (sun move
  first, then plants by shape score), pruning on coverage, leak and the cells outside the target the match tolerates.
  A plant's cells are its kind's stamp shifted by the anchor (equal to the kernel's cells, checked by the tests). Work
  is counted in plant evaluations and bounded at 20,000. The whole catalog certifies in about 11 s on a debug host build.
- **Witnesses.** `docs/games/nocturne-garden/levels/NNN.witness.json` holds each level, its actions, the mask digest
  after every action, the play fingerprints, the smallest move count with its bound (elevation, needed, cover, sun
  move), the near miss (one action short: not won, shared cells below the need), the difficulty and the candidates
  skipped; decoding re-verifies provenance and replay and refuses damaged, newer or edited files (`r02-g09.witness`).
  The catalog digest is pinned in `NocturneGardenCatalogTests`.

## Experience and renderer (feature 383, R02-G09-03)

- **Adapter.** `NocturneGardenExperienceCore` opens certified level (seed mod 100) + 1 and accepts `bloom.plant [kind,
  column, row, size]` (kind 0 … 5 in the kernel's order), `bloom.move [bloom, column, row]`, `bloom.resize [bloom,
  size]`, `bloom.remove [bloom]`, `sun.set [elevation]`, `play.undo`, `play.redo` and `level.next`; values out of the
  declared ranges or fractional and kernel refusals change nothing. Each level is certified once per process, directly
  from its certified candidate (the witness's `skipped`, pinned by a test). Its digest is the level number and the play
  fingerprint; snapshot schema 1 `{level, records}` restores by replay.
- **Snapshot.** The presenter draws an immutable `NocturneGardenSceneSnapshot`: the bed size, the target, forbidden,
  shadow (the kernel's exact mask) and leaking cells, the blooms, the allowed sizes, the sun, stage, failure, moves,
  budget, level number and presentation time. The shadow drawn is the kernel's mask, never a shadow computed by the
  graphics. The panel's picks (kind, column, row, size, bloom) are presentation state of the controls.
- **Scene.** The bed stands upright as a pearlescent mist plane (cell size u = 2 / W, row 0 at the bottom); every mask
  cell is a black shadow quad with a feathered edge along the shadow's boundary; the target's boundary carries a gold
  rim, forbidden cells a coral hatch, leaking cells a cross after a leak failure. Each bloom stands in front of the mist
  at z = 0.35: its head is its kind's outline at 0.35·size·u (the lantern magnifies, so the small flower hides little
  of the large shadow it casts), extruded, dark with a glowing rim, on an L-system stem with leaf
  pairs. The lantern's height follows the sun; a row of budget bars below the bed shows the moves spent. The camera
  looks from +z, pitched 8° down, fitted per level to the bed widened by the largest head a bloom can have, the lantern
  and the gauge, with a 5 % margin for aspects 0.4 … 2.5.
- **Shaders.** GLSL ES 3.00 on the shared `ShaderMeshRenderer`: the garden program carries the material code (0 ground
  … 11 head rim) and shade in uv (on shadow vertices, the cover across the feather band) and draws the drifting mist
  layers, the shadow, the hatch and the botanical bodies with their rims, with a small sway; the glow program carries
  the colour in the normal slot. Reduce Motion passes time 0, so mist and sway stand still; Reduce Flashing caps the
  glow.
- **Tiers.** level-0: 3 mist layers, stem depth 3, feather 0.3 cell, 2 glow shells; level-1: 2, 2, 0.15, 1; level-2: 1,
  1, hard edges, none. Cells, heads, colours, the gauge and the camera never change between tiers; each tier change is
  logged with its reason. A program that fails to compile draws the level-2 geometry unlit and keeps its reason.
- **Candidate.** Registered in `Catalog/registrations.json` (100 levels, digest ce13750a…52dd) and linked into the one
  app; it stays unavailable until X-R02-G09. Its scenario manifest has the standard scenarios, `full-playthrough`,
  `hero`, three fixtures and the 80 acceptance rows R2-G09-QA-001 … 080 (row r opens level (7 × (r − 1)) mod 100 + 1);
  its scripted actions other than certified ones are a neutral plant (the first supplied kind at the smallest size at
  the first anchor that keeps the play in play) and sun moves, derived by playing them.

## Gestures (feature 384, R02-G09-04)

- **Picking.** `NocturneGardenPicker` casts the touch ray through the drawn camera: the lantern first (its projected
  centre within 22 points), then the blooms (the ray meets a head box at z = 0.37, or the projected foot or head centre
  lies within 22 points; nearest to the eye), then the bed cell under the ray on z = 0; off the bed is "outside".
- **Gestures.** `NocturneGardenGestureController` (event timestamps only): a tap (under 10 points, 0.5 s) on a bed cell
  plants the panel's kind and size there; a tap on a bloom chooses it; a bloom drag (from 16 points) keeps its grab
  offset and shows the exact would-be shadow (`NocturneGardenDragPreview`, the kernel's own cells, with its match and
  leak) as a pale dashed outline, then moves the bloom on release, or removes it when released off the bed; a vertical
  lantern drag changes the sun by one allowed elevation per 48 points; two fingers pinch a bloom (the allowed size
  nearest size·scale) or orbit (yaw ±35°, pitch 0° … 30°); a double tap on empty space or "Reset view" returns to the
  authored view. A finished play takes no action from a gesture and says so. Refusals are shown and logged with their
  reason codes.
- **Panel.** Every action stays in the panel; the sun is a picker with "Set sun", so the panel wins all 100 certified
  levels in their smallest move counts.

## Teaching and progression (feature 385, R02-G09-05)

- **Hints.** `NocturneGardenHints` plans from the current state with a solver entry point that starts at the planted
  blooms and the sun and looks for the fewest further moves within the moves and supply left: plants at the current
  sun, then a sun move first, then the removal of one bloom first, all within the solver's bound. The first move of the
  plan is the hint, in three levels: what to do ("Plant a rose"), with size and sun, then the exact cell. From the
  opening it reproduces the certified search, so following exact hints wins every level. The presenter runs the search
  off the main actor; any change of the play hides the hint.
- **Failures.** `NocturneGardenFailureExplanation` explains a leak with the kernel's own reason (the move, the action and
  the cells against the allowance) and a budget run with the moves and the match against the requirement, each with
  "Undo the last move or retry the level."
- **Tutorial.** Levels 1 … 3 show three instructions (plant; shape with moves, sizes and the lantern while avoiding the
  coral cells; reach the match before the moves run out), each advancing on accepted moves; it can be dismissed.
- **Progress.** Stars count the moves made, undone ones included (3 at the certified smallest count, 2 within two more);
  a campaign win opens the next level; `level.select`, `level.next`, `mode.daily [y, m, d]` (the level (days from
  2026-01-01 × 71) mod 100 + 1, from a date the presenter reads), `mode.practice` (budget 40, no stars or unlocks) and
  `mode.campaign`. Progress and mode are in the digest; the snapshot is schema 2 with a migration from schema 1.


## Polish and accessibility (feature 386, R02-G09-06)

Presentation only: no state, digest or snapshot field changes (schema 2 stays).

- **Feedback.** `NocturneGardenFeedbackPlan` is a pure function of the core before and after an accepted action (or of
  a refusal's code). An accepted plant, move, resize, removal, sun change, undo or redo is announced as `state` with what
  changed, the match, the leak and the moves left, with a `selection` haptic; a win or a failure as `outcome` only
  (`success` or `warning`, the failure explanation of feature 385); a level or mode change as `level` with no haptic; a
  refusal as `rejection` in words ("That level is not open yet.") with an `error` haptic, the same words in the panel; a
  revealed hint as `state`. The presenter routes plans through the shared `ExperienceFeedback` and keeps a feedback log.
- **Lights.** `NocturneGardenLights` eases the blooms' glow (0.7 playing, 1 won, 0.35 failed) and the leak crosses
  (1 while the failure is a leak) linearly over 0.15 s, 0.45 s under Reduce Flashing, where a started fade finishes
  before it may turn back. The scene multiplies the glow gain by the glow level and shades the crosses by the leak level;
  after an undo the crosses fade out over the last leaking cells. Under Reduce Flashing no element crosses half its
  range more than 3 times per second and every half-range fade takes at least 0.4 s (host-tested).
- **Sound.** `NocturneGardenSoundRecipe` builds an ambient loop from the planted blooms, the sun and the stage (root
  110 Hz × the sun's ratio, one partial per bloom up to four, an octave when won, halved gains when failed, the longest
  accepted loop with whole cycles: 16 s, or 15 s at sun 4). `NocturneGardenSound` plays it exactly while the panel's
  Sound toggle is on (off by default), the panel is on screen and the scene is active.
- **Panel.** Every control has a label and a value; the kind, column, row, size, bloom, sun and level pickers are
  adjustable steppers; the "Garden" summary element reads the moves left, the measures, the blooms and the target in
  words; text wraps, rows become columns at accessibility text sizes and the panel keeps a 520-point readable width.

## Persistence and replay (feature 387, R02-G09-07)

- **Saves.** The one app's shared saved-state store writes the experience snapshot atomically; this feature defines it:
  schema 3 `{level, mode, progress, records, sound, tutorial}`, migrated from schema 1 (`{level, records}`) through 2.
  The 2 → 3 step gives every result an empty trace, marks it unverified and turns the sound off. The digest
  ("r02-g09.nocturne-garden.v3") covers the level, the play, the progress and the mode, never the sound choice or the
  count of dropped results.
- **Reconcilable scores.** Each campaign or daily win stores its fewest moves made (undone moves included), its stars and
  the winning trace: the effective moves of the play (a move that was undone and not redone is left out). On restore,
  `NocturneGardenReconciliation` replays every traced result on a fresh play of its certified level and keeps it only if
  the play wins, the trace is no longer than the stored moves made and the stars equal the stars rule for them; a trace
  of more than 40 moves or with an illegal move never verifies. A lowered moves made can never claim fewer moves than the
  trace proves, and a raised one only worsens the score. Edited results are dropped and counted, and the presenter
  announces the count once; untraced results from older saves are kept as unverified; the frontier is restored as saved.
- **Replay.** `replay.start [level]` plays a verified result's trace from a fresh level, `replay.step` applies its next
  move and `replay.stop` returns to the campaign. During replay every other play action is refused ("Stop the replay
  first."), progress never changes and a replayed win claims no stars; the panel shows "Replay: move k of n" with Step
  and Stop.
- **Settings and determinism.** `settings.sound [0 … 1]` saves the sound choice, applied when the experience opens. The
  state reads no clock or random source: the seed, the certified catalog, the date given to `mode.daily` and the
  recorded actions decide everything, so a save restores and replays identically on every device.

## Regression net (feature 388, R02-G09-08)

- **Solver.** For all 100 levels, in tests of 10: the generated level equals its witness's level, the witness's moves
  replay to a win in its smallest move count within the budget with its per-move digests and fingerprints, and the
  solver returns exactly the witness's moves with the smallest move count equal to the lower bound's; its work stays
  within the solver's work bound. Ten kinds of alteration (a target cell, a forbidden cell, the budget, the leak
  allowance, the required match, a solution move, a witness move, a per-move digest or fingerprint, the smallest move
  count) each fail naming the level and the part. Work is counted, never timed.
- **Golden frames.** `NocturneGardenGolden` (test builds only; forbidden in the Release binary) describes 16 frames —
  levels 1, 21, 41, 61, 81 at three tiers after their certified solution's first min(smallest − 1, 2) moves, at time 0,
  plus the hero frame — at 1,152 × 768: every projected bloom-head centre and the lantern's centre (to 1/8 px, null off
  screen), the shadow cell count, the moves spent and the budget, the tier's detail and the palette. The descriptions
  and SHA-256 digests are pinned in `golden-frames.json`; a recomputed description passes on an equal digest or within
  one quantum with everything else equal, and the file is rewritten only with `NOCTURNE_GARDEN_WRITE_GOLDEN=1`. The
  simulator renders the same frames and checks them with the feature-383 frame tolerances.
- **Memory.** Twelve open-draw-warn-close cycles on the simulator keep the footprint within 16 MB of the first cycle
  (bound applied when the class runs alone) and leave the garden scene holding no GPU objects (`liveObjectCount` 0)
  after each close and memory warning.
- **Where it runs.** CI's host job has a named "Nocturne Garden regression (host)" step; locally,
  `python3 scripts/nocturne_garden_regression.py` runs the host and simulator parts with one summary line each.
