# Data model: R02-G21-01

All values are integers (`Int`, 64-bit); stars are numbered 1 … 2 and worlds 1 … N in words and 0-based in code.

## Entities

| Entity | Fields | Rules |
|---|---|---|
| `BinaryGardensStar` | ring (index into the ring radii), phase θ 0 … 47, luminosity (index into the luminosity levels), ringAdjustable, phaseAdjustable, luminosityAdjustable (Bool) | indices in range; exactly two per level |
| `BinaryGardensWorld` | radius a 1 … 60, phase ψ 0 … 47, speed ν −4 … 4, lethalLow λ_lo, comfortLow c_lo, comfortHigh c_hi, lethalHigh λ_hi, window W 1 … 48, bloomLow B_lo, bloomHigh B_hi | 0 ≤ λ_lo < c_lo ≤ c_hi < λ_hi ≤ 200 000 milliflux; 0 ≤ B_lo ≤ B_hi ≤ 9 600 000; 1 … 5 per level |
| `BinaryGardensArrangement` | rings [2], phases [2], luminosities [2] (per star), tilt τ | indices in range; 0 ≤ τ ≤ T_max; keeps the separation at every tick 0 … 47 |
| `BinaryGardensLevel` | id, seed (UInt64), difficulty 1 … 5, ringRadii (2 … 8, strictly increasing, each 1 … 40), starSpeed ω 1 … 3, luminosityLevels (1 … 4, strictly increasing, each 1 … 64), stars [2] (starting values and flags), maxTilt T_max 0 … 6, startTilt 0 … T_max, minimumSeparation σ 0 … 16, clampRadius r_min 1 … 8, worlds (1 … 5), lethalTolerance E 0 … 12, budget 1 … 24, tutorial, fingerprint | refused `r02-g21.level` when any value is out of range or out of order, nothing is adjustable (all six star flags false and T_max = 0), the starting stars break the separation at a tick of 0 … 47, or the starting arrangement already wins; schema 1; sorted-key JSON; fingerprint = SHA-256 of a canonical text |
| `BinaryGardensPoint` | x, y, z at scale 2^20 | world (a·C[ψ]·1024, a·S[ψ]·1024, 0); star (ρ·C[θ]·1024, ρ·S[θ]·C[τ], ρ·S[θ]·S[τ]) |
| `BinaryGardensBand` | lethalLow, dim, comfortable, bright, lethalHigh | F < λ_lo; λ_lo ≤ F < c_lo; c_lo ≤ F ≤ c_hi; c_hi < F ≤ λ_hi; F > λ_hi |
| `BinaryGardensWorldLight` | per tick 1 … 48: flux, share of star 1, share of star 2, band; longest lethal run (cyclic, capped at 48) and its kind; window length and start tick; integral I; mean flux I/48 (kept as I); survives, windowHolds, bloom (below, inside, above) | flux = share₁ + share₂; share = ⌊1000·L·2^40 / max(D, r_min²·2^40)⌋ ≤ 64 000; I = Σ flux over ticks 1 … 48 |
| `BinaryGardensReport` (light report) | star positions [tick 1 … 48][2], world positions [tick 1 … 48][N], worlds [`BinaryGardensWorldLight`], minimum squared separation and its tick, failure (first, or nil), outcome (won / failed) | exact; computed after every action; never decides by itself (the play ends only on `run`) |
| `BinaryGardensFailure` | frozen(world, tick), scorched(world, tick), unstable(world, window, required), wilted(world, integral, low, high), bleached(world, integral, low, high) | codes `frozen`, `scorched`, `unstable`, `wilted`, `bleached`; tick is the walk tick 1 … 48 + E |
| `BinaryGardensAction` | ring(star, index), phase(star, step), luminosity(star, index), tilt(step), run | the four arrangement actions spend 1 action; run spends none and ends the level |
| `BinaryGardensStage` | loading, tutorial, playing, paused, won, failed, result | see transitions |
| `BinaryGardensPlay` | level, stage, arrangement, actions spent, report, failure, records, undo and redo stacks | fingerprint = SHA-256(schema, level fingerprint, arrangement, actions spent, stage, failure) |
| `BinaryGardensRecord` | schema (1), level seed, index (0, 1, …), kind (ring, phase, luminosity, tilt, run, undo, redo, begin, dismissTutorial, pause, resume, showResult), action (nil for events), previous and next fingerprints | appended for every accepted action and event; a replayed chain must start at the initial fingerprint and link every next to the following previous |
| `BinaryGardensPuzzle.Position` | arrangement, actions spent | moves: every legal arrangement action while actions are left; goal: the predicted run wins |

## Validation rules (actions)

Checked in this order, each refusal leaving the play unchanged:
1. `.stage` — the stage is not `playing` (an arrangement action or run while loading, in the tutorial, paused, won,
   failed or in the result).
2. `.stale` — the expected previous fingerprint differs from the play's fingerprint.
3. `.action` — star not 1 … 2 (index 0 … 1 in code); ring index outside the ring radii, phase outside 0 … 47,
   luminosity index outside the levels, tilt outside 0 … T_max; the control is locked (tilt locked when T_max = 0); the
   value is unchanged; the new arrangement breaks the minimum separation at a tick of 0 … 47.
4. `.budget` — no action left (actions spent = budget). `run` never checks the budget.

## State transitions

```text
loading --begin--> tutorial (level.tutorial)  |  loading --begin--> playing (no tutorial)
tutorial --dismissTutorial--> playing
playing --pause--> paused --resume--> playing
playing --ring|phase|luminosity|tilt--> playing (1 action spent, report recomputed)
playing --run--> won | failed (the judge of the current arrangement)
failed --undo--> playing (the arrangement before the run; actions spent unchanged)
won | failed --showResult--> result
playing --undo/redo--> playing (exact earlier/later arrangement, actions spent and fingerprint)
```

A won level is final (undo refused `.stage`); every action and event not listed is refused `.stage`. Redo after an undo
from failed re-runs the run and ends failed again with the same failure.

## Stored form (schema 1)

Sorted-key JSON with these top-level keys, in sorted order: `budget`, `clampRadius`, `difficulty`, `fingerprint`, `id`,
`lethalTolerance`, `luminosityLevels`, `maxTilt`, `minimumSeparation`, `ringRadii`, `schema` (1), `seed`, `starSpeed`,
`stars` (two, each with `luminosity`, `luminosityAdjustable`, `phase`, `phaseAdjustable`, `ring`, `ringAdjustable`),
`startTilt`, `tutorial`, `worlds` (each with `bloomHigh`, `bloomLow`, `comfortHigh`, `comfortLow`, `lethalHigh`,
`lethalLow`, `phase`, `radius`, `speed`, `window`). The fingerprint is SHA-256 of the canonical text of every other
field (schema included, fingerprint excluded). Decode: broken JSON, a missing field, a schema below 1 or a
fingerprint that does not match the canonical text → `r02-g21.malformed`; `schema` > 1 → `r02-g21.newer-schema`; any value that
the initializer refuses → `r02-g21.level`. Encoding then decoding returns an equal level with the same fingerprint.
