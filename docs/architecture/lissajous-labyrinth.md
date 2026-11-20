# Lissajous Labyrinth (R02-G02) — rules

Experience `r02-g02.lissajous-labyrinth` (free) of the one VisualCore app; package `Packages/ExperiencesRound02`, target
`LissajousLabyrinthCore` (feature 311, R02-G02-01). The player tunes two coupled frequencies and two phases so a moving
point traces a closed three-dimensional path through every illuminated checkpoint, in order, without touching an obstacle.
Everything here is pure, exact integer logic; drawing, dials, gestures and sound come in later features of R02-G02.

## Numbers

- **Angles** are counts of 1/4,096 of a turn. `LissajousLabyrinthSine` is a fixed table of 4,096 integers,
  round(1,024 · sin(2πk/4,096)), stored as source and pinned by its SHA-256; cosine is the sine a quarter turn later.
- **The tracer** at tick n: x = A·S(a·n + 256·φ), y = B·S(b·n), z = C·S(c·n + 256·ψ + 1,024), with amplitudes A, B, C of
  1 … 4, the player's frequencies a, b of 1 … 9 (coprime), the level's frequency c of 1 … 9 and the player's phases φ, ψ of
  0 … 15 (sixteenths of a turn). Coordinates stay within ±4,096.
- **One lap** is 4,096 ticks of 1/240 s (the source's 0.004167 s, about 17 s). With coprime a and b the path closes after
  exactly 4,096 ticks: the fundamental period.

## Verdict

- **Checkpoints** (1 … 6, ordered) and **obstacles** (0 … 8) are balls: integer centres within ±5,000, radii 64 … 1,024.
- Scanning ticks 0 … 4,095, the next checkpoint is visited at the first sample inside or on it (at most one per tick).
- Every segment between consecutive samples, the closing one (4,095 → 0) included, is tested against every obstacle: it
  touches when its closest point is strictly inside the ball, decided exactly in integers without division
  (`segmentTouches`).
- `LissajousLabyrinthLap.verdict` is `won`, else the first contact (lowest tick, then lowest obstacle), else the first
  checkpoint not reached (`missed`). A level whose start already wins is refused.

## Play

`LissajousLabyrinthPlay` moves through loading, tutorial, playing, paused, won or failed and result. An action sets one
dial (`frequencyA`, `frequencyB`, `phaseA`, `phaseC`); it must name the current fingerprint, stay in range, change
something, keep the frequencies coprime and fit the allowance. The lap is judged after every accepted action, undo or redo;
spending the last action without a win fails the level with the verdict as its explanation. Undo refunds an action, redo
re-applies it, a new action clears redo. Every accepted action, undo and redo appends a `LissajousLabyrinthRecord` with the
previous and next fingerprint, so a trace replays to the same states everywhere. The fingerprint is the SHA-256 hex of the
schema, the level fingerprint, the four dials, the actions spent and the stage.

## Levels and solver contract

`LissajousLabyrinthLevel` is immutable and fingerprinted (SHA-256 of its canonical JSON, schema 1); decoding re-checks
every rule. `LissajousLabyrinthRules` expresses the rules as an R02-F23 `PuzzleRules` over the four dials (at most
9 × 9 × 16 × 16 states), so R02-G02-02 can generate and certify the catalog.

## Failures

`LissajousLabyrinthError` reason codes: `r02-g02.level`, `r02-g02.move`, `r02-g02.stage`, `r02-g02.stale`,
`r02-g02.allowance`, `r02-g02.newer-schema`, `r02-g02.malformed`.

## Sources

The game design is VisualCore's own (archived round-two design); the code and the sine table are original. Nothing here
draws.
