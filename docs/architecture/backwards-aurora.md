# Backwards Aurora (R02-G10) — rules

Experience `r02-g10.backwards-aurora` (free) of the one VisualCore app; package `Packages/ExperiencesRound02`, target
`BackwardsAuroraCore` (feature 391, R02-G10-01). An aurora is drawn as a wave along a timeline, and some sections of it
run backwards. The player chooses a section by its two ends and reverses it in time until every checkpoint shows its
true height and every seam bends within the limit. Everything here is pure, exact integer logic; drawing, controls and
sound come in later features of R02-G10.

## Wave, bends and seams

- **Wave.** N samples (N 12 … 32) at positions 0 … N − 1, each a signed integer height in −64 … 64 (one unit is 1/64
  of the aurora's half-height) (`BackwardsAuroraWave`).
- **Bend.** At every interior position k (1 … N − 2) the bend is the exact second difference
  b(k) = s(k − 1) − 2·s(k) + s(k + 1). The wave is **smooth** when every |b(k)| ≤ L, the level's bend limit (1 … 64).
- **Reversal.** Reversing the section [i, j] (i < j) reverses the order of its samples and changes nothing else. The
  bends strictly inside the section are carried along in reverse order, so only the bends at the **seam positions**
  i − 1, i, j and j + 1 (where they are interior) can take new values.
- **Target and checkpoints.** The target wave holds exactly the opening wave's heights in another order (a reversal only
  reorders samples). Checkpoints are 2 … 8 positions; checkpoint k is matched when the wave's height there equals the
  target's.
- **Measures.** The distance Σ|s(k) − t(k)| / Σ|t(k)| as an exact fraction (0/1 when the target is all zero) and the
  worst bend max |b(k)| are reported after every action and never decide the outcome.

## Actions and verdict

`reverse(start, end)`; each accepted reversal spends one. Refused without change: an end outside the wave, start not
before end, or a section length outside the level's shortest … longest (`r02-g10.action`); a section that reads the
same both ways (`.noop`); the wrong stage (`.stage`) and a stale fingerprint (`.stale`). After an accepted reversal, in
this order: **tear** (a seam bend with |b| above the breaking limit B, L … 128, fails the level, naming the reversal and
the lowest breaking seam position), **win** (every checkpoint matched and the wave smooth), **budget** (reversals spent
equal to the budget: failed). A bend equal to L is smooth and one equal to B does not tear; a win on the last reversal
counts. Undo and redo spend nothing; undo from failed returns to playing; a won level is final.

## Stored form

Levels are JSON schema 1 with sorted keys (opening and target waves, checkpoints, bend and breaking limits, shortest and
longest section, budget, difficulty, tutorial, seed, id) and their fingerprint; decoding re-checks every rule (an
opening wave that already wins is refused) and the fingerprint and refuses damaged, edited and newer forms
(`r02-g10.malformed`, `.newer-schema`).

## Content pipeline (feature 392, R02-G10-02)

- **Manifest.** The 100 planned levels of the archived design (`BackwardsAuroraManifest`): number, planned seed, band
  1 … 5 (20 each) and reversal budget 8 … 19.
- **Generator.** Candidate c of an entry draws from `SeededRandom(seed: SeedDerivation.derive(seed, index: c))`: the
  wave length by band (14 … 16, 18 … 22, 22 … 26, 26 … 30, 30 … 32), a gently curving target (slope changing by at most
  1 per sample), the bend limit L at the target's worst bend, k reversals by band (2 … 3 up to 6 … 7) and up to 16
  placements of k separated sections (no shared or touching seams). A placement is kept when no section is a
  palindrome and all four seam bends of each section, reversed alone, exceed L. The opening is the target with every
  section reversed, so it has exactly 4k bad bends. Checkpoints sit inside band + 1 of the sections where the opening
  differs from the target; the breaking limit is 128 in bands 1 … 2 and L + 48, L + 32, L + 16 (at most 128) above.
  At most 256 candidates per entry (`BackwardsAuroraGenerator`).
- **Proof.** A reversal gives new values only to its at most four seam bends, so the bad bends (|b| > L) fall by at most
  4 per reversal and no win comes in fewer than ⌈β / 4⌉ reversals. The solver (`BackwardsAuroraSolver`) searches
  reversible sections depth-first with iterative deepening from that bound, never past a tear, and counts its work
  (at most 20,000 reversals evaluated). Every catalog level is certified at exactly k.
- **Witnesses.** `docs/games/backwards-aurora/levels/NNN.witness.json` holds each level, its reversals, a sample digest
  and play fingerprint after each, the bound, the near miss and the difficulty (`BackwardsAuroraWitness`); the catalog
  tests compare them byte for byte and pin the catalog digest.

## Hero renderer and experience (feature 393, R02-G10-03)

- **Scene.** The timeline stands upright as the plane z = 0: sample k at x = −1 + (k + 0.5)·2/N, y = 0.6·s / 64. The
  deep-ocean-cyan ribbon is a strip through the kernel's exact samples (each segment in 4 straight steps; never a
  smoothed curve), with trailing aurora layers behind it; the target is a pale lilac ghost trail; checkpoints are ticks
  with rings at the true height, filled when matched; bends above the limit carry kink crosses and a torn seam a larger
  cross; the chosen section is a band with dashed edges; a row of bars shows the reversals spent. A fixed camera from
  +z fits x −1 … 1, y −0.95 … 0.75 with a 5 % margin for aspects 0.4 … 2.5 (`BackwardsAuroraSceneGeometry`).
- **Materials.** GLSL ES 3.00 in `BackwardsAuroraShaders`: a shimmer and direction-coded pulse beads travel along the
  ribbon with presentation time (left to right, right to left inside the chosen section), trailing layers fade, and a
  glow program adds shells around the ribbon; Reduce Motion holds the time at 0 and Reduce Flashing caps the glow.
- **Tiers.** `level-0`: 3 aurora layers, 2 pulses, 2 glow shells; `level-1`: 2, 1, 1; `level-2`: the ribbon alone, no
  pulses, no glow. Samples, markers, colours and positions are the same at every tier; the presenter logs each change.
- **Purity.** The presenter draws an immutable `BackwardsAuroraSceneSnapshot` made by the adapter
  (`BackwardsAuroraExperienceCore`); no tier, time or failed shader changes the kernel's digest or verdict. A failed
  program falls back to the level-2 geometry drawn unlit.
- **Experience.** Controls `wave.reverse [start, end]`, `play.undo`, `play.redo`, `level.next`; the panel's chosen
  section is presentation state; levels open from their certified candidates; snapshot schema 1 `{level, records}`.
  Registered as a candidate (`r02-g10.backwards-aurora`) until X-R02-G10.

## Gestures (feature 394, R02-G10-04)

- **Picking.** The touch ray through the drawn camera meets the timeline plane: an end of the chosen section (22-point
  target) wins over the band, the band over a sample column (`BackwardsAuroraPicker`).
- **Tap segment ends.** A tap on a sample (or on the band) moves the start when left of the section, the end when right
  of it, and the nearer end when inside; dragging an end moves it, never past the other. The section is presentation
  state; no tap sends a kernel action.
- **Swipe to reverse.** A mostly sideways drag from the band sends one `wave.reverse` of the section on release while
  playing; a refusal (a palindrome, a length outside the level's sections) is shown with its reason and logged.
- **Timeline freeze preview.** A press held 0.5 s on the band, and every swipe while it lasts, shows the kernel's own
  reversal as a pale dashed ribbon with the bends above the limit and the seam that would tear, and a line in words; the
  shimmer and pulses hold still; lifting a held press sends nothing (`BackwardsAuroraFreezePreview`).
- **Orbit.** Two fingers orbit (yaw ±35°, pitch −15° … +20°) with the distance refitted at every aspect 0.4 … 2.5; a
  double tap or "Reset view" returns to the authored view. Orbit, section and preview are never saved and never reach
  the kernel (`BackwardsAuroraGestureController`).
- **Panel.** Every level can be won with the start and end steppers and Reverse alone.

## Teaching and progression (feature 395, R02-G10-05)

- **Hints.** `BackwardsAuroraHints` plans from the current wave with a solver entry point
  (`solve(_:from:reversalsLeft:workBound:)`): the certification's iterative deepening and seam-count pruning, started
  at the play's wave and bounded by the reversals left and 20,000 reversals evaluated. The first reversal of the plan is
  the hint, in three levels: its length ("Reverse a section of 4 samples"), then where it starts, then both ends. From
  the opening it is exactly the certification, so following exact hints wins every level. When no plan is found within
  the bound the hint says so ("No way to fold the aurora back was found in the reversals left …"); a state that can
  still win but needs a deeper search than the bound is reported the same way (24 of the 200 seeded test states). The
  presenter runs the search off the main actor; a stale search owns nothing; any change of the play hides the hint.
- **Failures.** `BackwardsAuroraFailureExplanation` names the tearing reversal, its section and the seam with its bend
  against the breaking limit, or the reversals spent with the checkpoints matched and the worst bend against the limit,
  each followed by "Undo the last reversal or retry the level."
- **Tutorial.** Levels 1 … 3 show three instructions (mark a section's ends; swipe to reverse, hold to preview, never
  tear; match every checkpoint before the reversals run out), each advancing on an accepted reversal and ending with the
  level; undo and redo never move it back; it can be dismissed. The tutorial levels' certified solutions take two
  reversals, so a perfect play goes from the second instruction straight to the end.
- **Progress.** Stars count the reversals made, undone ones included (3 at the certified smallest count, 2 within two
  more); a campaign win opens the next level; `level.select`, `level.next` (no wrap), `mode.daily [y, m, d]` (the level
  (days from 2026-01-01 × 73) mod 100 + 1, from a date the presenter reads; a daily win records stars and opens
  nothing), `mode.practice` (budget 40, no stars or unlocks) and `mode.campaign`. No level is gated by payment. Progress
  and mode are in the digest, the tutorial step only in the snapshot; the snapshot is schema 2
  (`{level, mode, progress, records, tutorial}`) with a migration from schema 1.
- **Panel.** The tutorial with Dismiss, Hint (each press reveals the next level), the goal with the level's band and best
  stars, the failure explanation with Undo and Retry, Campaign / Daily / Practice and a stepper over the open levels, all
  as wrapping text in the panel, never over the aurora.

## Polish and accessibility (feature 396, R02-G10-06)

- **Announcements.** `BackwardsAuroraFeedbackPlan` is a pure function of the old and new core: an accepted reversal
  "Reversed samples i to j." with the checkpoints matched, the worst bend against the limit and the reversals left;
  "Undone." / "Redone." with the same measure (`state`); a win with the reversals made and the stars, or a failure with
  its explanation (`outcome`); a level or mode change with the band, the mode and the tutorial instruction (`level`);
  refusals in words (`rejection`); a revealed hint as `state`. A reversal that ends the play plans only the outcome.
- **Haptics.** Selection for an accepted reversal, undo or redo, success for a win, warning for a failure, error for a
  refusal, through the shared `ExperienceFeedback` route and the person's switch.
- **Lights.** `BackwardsAuroraLights` eases the glow (0.7 playing, 1 won, 0.35 failed), the won lift, the tear cross and
  the freeze preview over 0.15 s, 0.45 s under Reduce Flashing (a started fade finishes first). The won lift and glow
  ride their existing uniforms; `u_tearLight` and `u_previewLight` scale the tear cross's and the preview ribbon's
  alphas, so a fade rebuilds no geometry. The cross stays on the last torn seam and the preview on its last samples
  while they fade out. The shimmer (0.25 cycles per second) and pulses (at most 0.24 beads per second) stay below 3 per
  second and stand still under Reduce Motion.
- **Sound.** An optional ambient loop (`BackwardsAuroraSoundRecipe`): a 110 Hz root stepped by the worst bend against the
  limit, one partial per matched checkpoint up to four, an octave when won, halved when failed, whole cycles in the loop;
  rebuilt only when the recipe changes; plays exactly while the Sound toggle is on, the panel is on screen and the scene
  is active (`BackwardsAuroraSound`).
- **Panel.** Every control has a label and a value in words; the start and end steppers are adjustable and name the
  sample and its height; the "Aurora" summary element reads the reversals left, the checkpoints, the bends and the
  section; Dynamic Type up to the accessibility sizes with rows that become columns, system colours and a 520-point
  readable width on iPad.

## Persistence and replay (feature 397, R02-G10-07)

- **Traces.** Every campaign or daily win stores the winning play's effective reversals (an undone reversal left out
  unless redone; `BackwardsAuroraReconciliation.netTrace`) with the fewest reversals made (undone ones still counted)
  and the stars; a better result replaces a worse one, ties keep the earlier trace; practice and replay record nothing.
- **Reconciliation.** On restore every traced result is replayed on a fresh play of its certified level (campaign
  budget) and kept only when it wins with a trace no longer than the recorded reversals made (at most 40) and stars that
  match the stars rule; edited results are dropped, counted in `reconciliationDropped` and announced once; untraced
  results from older saves are kept as unverified; the frontier is restored as saved.
- **Schema 3.** `{level, mode, progress, records, sound, tutorial}` with the digest "r02-g10.backwards-aurora.v3"
  (the sound choice and the dropped count never digested); migrations 1 → 2 → 3 (2 → 3: empty traces, unverified,
  sound off); schema 4 or newer is refused by the shared store, which writes atomically and quarantines unreadable
  files.
- **Replay.** `replay.start [level]` plays the best verified trace from a fresh level, `replay.step` one reversal at a
  time, `replay.stop` back to the campaign; every other play action is refused with `r02-g10.replay` (refusals in
  words); a replayed win claims no stars. The panel shows "Replay best solution", then the position with Step and Stop.
- **Settings.** The Sound toggle is saved through `settings.sound [0 … 1]` and applied when the experience opens.
