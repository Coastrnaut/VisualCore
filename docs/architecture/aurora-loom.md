# Aurora Loom rule kernel

Experience R02-G01 (`r02-g01.aurora-loom`). Feature 301 (R02-G01-01). Spec:
[specs/301-aurora-loom-playable-rule-kernel](../../specs/301-aurora-loom-playable-rule-kernel/spec.md).

## The rule

Three luminous ribbons must share a target harmony at four gates. A ribbon's phase along its length is
q(s, t) = k · s + ω · t + φ; the player sets k (wave) and φ (phase) in sixteen steps each. The level is won exactly
when every gate sample of every ribbon stays within the tolerance for two complete periods, and failed exactly when the
move allowance is spent without that; the failure names the ribbon, gate and tick furthest off. The outcome is decided
by integer arithmetic in the kernel, never by the renderer.

## Numbers

- A phase is a count of 1/4,096 of a turn, modulo 4,096. Gates sit at sixteenths of the ribbon (1 … 15).
- Wave step i adds i · s · 16 units at a gate at s sixteenths; phase step j adds j · 256 units; a ribbon turns ω units per
  tick (1/120 s); the target at gate g is Θ_g + Ω · n with Ω a power of two, so a period is P = 4,096 / Ω ticks.
- The residual is (ribbon − target) wrapped into −2,048 … 2,047; a sample is inside when |residual| ≤ tolerance.
- The win test runs ticks 0 … 2P − 1 for all three ribbons and four gates after every accepted move, undo or redo.

## Play

`AuroraLoomPlay` moves through loading, tutorial, playing, paused, won or failed and result. A move sets one control of
one ribbon; it must name the current fingerprint, stay in range, change something and fit the allowance. Undo refunds a
move, redo re-applies it, and a new move clears redo. Every accepted move, undo and redo appends an `AuroraLoomRecord`
with the previous and next fingerprint, so a trace replays to the same states everywhere. The fingerprint is the SHA-256
hex of the schema, the level fingerprint, the six steps, the moves spent and the stage.

## Levels and solver contract

`AuroraLoomLevel` is immutable and fingerprinted (SHA-256 of its canonical JSON); a level whose start already wins is
refused. `AuroraLoomRules` expresses the rules as an R02-F23 `PuzzleRules`, so R02-G01-02 can generate and certify the
catalog's levels.

## Failures

`AuroraLoomError` reason codes: `r02-g01.level`, `r02-g01.move`, `r02-g01.stage`, `r02-g01.stale`,
`r02-g01.allowance`, `r02-g01.newer-schema`, `r02-g01.malformed`.

## Sources

The game design is VisualCore's own (archived round-two design); the code is original. Nothing here draws.
