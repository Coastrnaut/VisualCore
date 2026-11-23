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
