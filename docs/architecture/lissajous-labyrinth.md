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

## Content: generator, solver and witnesses (R02-G02-02)

- **Manifest.** `LissajousLabyrinthManifest` holds the 100 planned levels of the archived design (number, seed, band,
  move budget 8 … 19), 20 per band.
- **Solver.** `LissajousLabyrinthSolver` decides all 14,080 legal settings (55 coprime frequency pairs × 256 phase
  pairs). x depends on (a, φ), y on b, z on ψ, so per checkpoint and obstacle it builds bit sets of the 4,096 ticks per
  axis value (the phases are bit rotations of phase 0). Sound prefilters drop settings that cannot visit the checkpoints
  in order or that start a segment inside an obstacle's inner cube; every other setting gets an exact fast decision that
  equals the kernel's `verdict == .won`: contact is tested with `segmentTouches` only on ticks whose segment's axis box
  meets the obstacle's box, and checkpoints are scanned in order over their box-hit ticks with `contains`. The tests
  check the decision against the kernel's verdict. The shortest solution is a breadth-first search over legal states
  (single-dial changes keeping the frequencies coprime) to the nearest winning setting, ties by (a, b, φ, ψ); work is the
  number of exact decisions.
- **Generator.** Candidate k of an entry draws from `SeededRandom(seed: SeedDerivation.derive(seed, index: k))`:
  amplitudes 2 … 4, frequency c, a target winning setting, checkpoints on its path at spread ticks, obstacles on other
  settings' paths that the target lap clears, and a start with up to the band's shortest number of dials changed. Bands
  1 … 5: 2/3/4/5/6 checkpoints of radius 512/448/384/320/256, 2/3/4/6/8 obstacles of radius 256 … 512, shortest 1–2, 2,
  2–3, 3, 3–4 actions. At most 64 candidates (`r02-g02.generation` otherwise); the allowance is the budget.
- **Difficulty.** Shortest, winning settings, clearance (smallest squared distance minus squared radius between the
  witness path's samples and any obstacle) and work. Band means: shortest 1.25, 2, 2.95, 3, 4; winning settings 785, 55,
  3.5, 1.5, 1. The catalog keeps the shared progression rule; its digest is pinned in `LissajousLabyrinthCatalogTests`.
- **Witnesses.** `docs/games/lissajous-labyrinth/levels/NNN.witness.json` (schema 1, sorted keys): the level, the
  actions, play fingerprints, the terminal visit ticks and clearance, the near miss (the smallest single legal dial change
  that loses, with its verdict) and the non-coprime counterexample refused by the rules. Decoding re-verifies everything
  and refuses newer, damaged or edited files (`r02-g02.witness`). Regenerate after an intended rule change:

```bash
LISSAJOUS_LABYRINTH_WRITE_WITNESSES=1 swift test --package-path Packages/ExperiencesRound02 --filter LissajousLabyrinthCatalogTests
```

## Renderer and experience (R02-G02-03)

- **Adapter.** `LissajousLabyrinthExperienceCore` adapts the kernel to the shared contract: the seed opens certified
  level (seed mod 100) + 1; actions `dial.set [dial 0 … 3, value 0 … 15]` (frequency A, frequency B, phase A, phase C;
  the kernel refuses values outside a dial's own range, unchanged values and non-coprime frequencies), `play.undo`,
  `play.redo`, `level.next`; the digest is the level number and the play's fingerprint; snapshot schema 1 `{level,
  records}`. Certified levels are generated once per process (about 0.1 s each in a debug build).
- **Snapshot.** `LissajousLabyrinthSceneSnapshot` copies the level, dials, stage, the lap's verdict and the checkpoints'
  visit ticks with a presentation time; the tracer head advances 60 ticks per second (0 under Reduce Motion).
- **Scene.** The lap's samples scaled by 1/1,024 form a camera-facing thread (tangent-space width 0.035) shaded cobalt
  to violet with a brighter trail behind the copper head, a small interference shimmer and depth fading (the front of
  the bounding sphere is up to 15 % brighter than the back, `LissajousLabyrinthShaders.depthFade`); checkpoints are copper rings (dim, next, visited in order);
  obstacles violet translucent icospheres with a rim, copper when the lap touches them; the camera fits the figure's
  bounding sphere for aspects 0.4 … 2.5 with a 5 % margin. Palette: night #070B1E, cobalt #2F5BD8, violet #8A4FE0,
  copper #D9824A. GLSL ES 3.00 in `LissajousLabyrinthShaders`, drawn with the shared `ShaderMeshRenderer`.
- **Tiers.** level-0: every sample, 2 glow passes, trail 512; level-1: every 2nd, 1, 256; level-2: every 4th, 0, 128.
  Drawn samples are exact kernel samples at every tier; the presenter logs tier changes with their reason.
- **Fallback and purity.** A failing program falls back to the minimal thread drawn unlit; the renderer reads only the
  snapshot, so no tier, time or failure changes the digest or verdict.
- **Candidate.** Registered in `Catalog/registrations.json` (content facts: 100 levels, the pinned digest) with a
  scenario manifest of the standard scenarios, `full-playthrough`, `hero`, three fixtures and the 80 acceptance rows
  R2-G02-QA-001 … 080; linked into the one app, not available until X-R02-G02.

## Touch controls and panel play (R02-G02-04)

- **Stage and rings.** `stageBounds(level:)` holds every path the level can draw (the amplitude box and every ball), so
  the four dial rings beside it (`LissajousLabyrinthHandles`: radius 0.18 R, 0.45 R apart, 1.35 R to the right along the
  authored camera, frequencyA, frequencyB, phaseA, phaseC from the top) never move while a dial turns. The camera fits
  the content sphere around stage and rings; since then the figure takes about two thirds of the width it had.
- **Turning.** A knob or a ring band (0.7 … 1.3 ring radius) is picked with R02-F22's rule; the turned angle accumulates
  on the ring plane (clockwise from the eye raises the value, 40° per frequency step, 22.5° per phase step); release
  sends one `dial.set` when the value changed. A second finger cancels the turn and orbits (azimuth ±40°, elevation
  10° … 60°); a double tap on empty space resets the view. The camera is presentation only.
- **Panel play.** Steppers set pending values; Apply sends one action per changed dial in the order frequencyA,
  frequencyB, phaseA, phaseC, with the frequencies swapped when only that keeps every intermediate pair coprime, and
  stops at a refusal or when the level ends. Every certified level is won this way in exactly its certified shortest
  number of actions (host test over all 100 levels).

## Failures

`LissajousLabyrinthError` reason codes: `r02-g02.level`, `r02-g02.move`, `r02-g02.stage`, `r02-g02.stale`,
`r02-g02.allowance`, `r02-g02.newer-schema`, `r02-g02.malformed`, `r02-g02.generation`, `r02-g02.witness`.

## Sources

The game design is VisualCore's own (archived round-two design); the code and the sine table are original. Nothing here
draws.
