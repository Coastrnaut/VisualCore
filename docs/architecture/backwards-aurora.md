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
