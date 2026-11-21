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

## Teaching and progression (R02-G02-05)

- **Hints.** The solver's breadth-first search runs from the current dials over the level's winning settings (computed
  once when the level opens, about 0.1 s); a precomputed successor table keeps each search under a millisecond. The
  first action of the shortest remaining solution gives three levels: the dial, raise or lower, the exact value. Hints
  are unlimited, change nothing and do not affect stars; "No solution fits in the actions left" when the remaining
  solution is longer than the actions left.
- **Failures.** The kernel's verdict in words: the touched obstacle and the lap position (⌊100 · tick / 4,096⌋ %), or the
  checkpoint not reached in order, with Undo (which rewinds the failing action) and Retry.
- **Tutorial.** On levels 1 … 3 in campaign mode: turn the hint's dial, then the checkpoint and sphere rule, then "ask for a
  hint"; dismissable; undo never moves it back and it is not in the digest. Levels 1 and 2 are won in one action, so a
  perfect play shows only the first instruction.
- **Progress and modes.** Stars 3 / 2 / 1 against the certified shortest; campaign wins open the next level; the daily
  level is (days since 2026-01-01 × 41) mod 100 + 1 from the local date the presenter sends; practice raises the
  allowance to 64 and records nothing. Snapshot schema 2 (`level`, `mode`, `progress`, `records`, `tutorial`) with a
  migration from schema 1.

## Polish and accessibility (R02-G02-06)

- **Announcements and haptics.** `LissajousLabyrinthFeedbackPlan` turns each change into one announcement and one
  haptic: the dial, its value, the checkpoints in order and the actions left (`state`, selection); wins with stars and
  failures with their explanation (`outcome`, success or warning); level and mode changes (`level`); refusals in words
  (`rejection`, error). An action that ends the play plans only the outcome.
- **Fades.** `LissajousLabyrinthLights` eases each checkpoint, obstacle and the win glow (0.15 s, 0.45 s under Reduce
  Flashing, where a started fade finishes before turning back); a new level, or an off-screen still drawn at its own
  time, settles at once. Reduce Motion holds the tracer head still.
- **Sound.** `LissajousLabyrinthSoundRecipe` makes an 8-second ambient loop from the figure's own ratio (110 Hz × a and
  × b, a fifth, phase-shaped gains, an octave when won, halved when failed); `LissajousLabyrinthSound` plays it while the
  Sound toggle is on, the panel is on screen and the scene is active, and rebuilds it only at level openings, play ends
  and when turned on.
- **Panel.** Labels and values on every control, button rows that become columns at accessibility text sizes, a
  520-point readable width; hearing, feeling and VoiceOver on hardware are D1–D3 observations.

## Persistence and replay (R02-G02-07)

- **Saved state.** Snapshot schema 3 (`level`, `mode`, `progress`, `records`, `tutorial`) in the app's shared store
  (atomic write, quarantine, newer schemas refused); migrations 1 → 2 → 3, where 2 → 3 gives every result an empty trace
  and `verified: false`. The state reads no clock and no random source.
- **Reconcilable scores.** A campaign or daily win stores its winning trace (the play's net changes). On restore
  `LissajousLabyrinthReconciliation` replays each trace on a fresh play of its certified level and keeps the result only
  if it wins in exactly the recorded actions with the recorded stars; the number dropped is announced once. The frontier
  is restored as saved (Aurora Loom's lesson: raising it would open levels for an honest daily win).
- **Replay.** `replay.start [n]`, `replay.step`, `replay.stop` play a verified trace action by action; every other
  action except dismissing the tutorial is refused during replay, and replay never changes progress.

## Regression net (R02-G02-08)

- **Solver regression.** For all 100 levels: the generated level equals its witness, the witness replays to a win with
  its recorded fingerprints, and the solver finds exactly the certified shortest with at most 14,080 settings decided
  (counted, never timed); twelve kinds of alteration fail by name.
- **Golden frames.** `LissajousLabyrinthGolden` (test builds only) describes 16 frames at 1,152 × 768 — path samples,
  checkpoint band points with their state colours, obstacles, dial rings and knobs — pinned with SHA-256 digests in
  `golden-frames.json`; an unequal digest falls back to one 1/8-pixel quantum, a hand-edited entry fails, and the file is
  rewritten only with `LISSAJOUS_LABYRINTH_WRITE_GOLDEN=1`. The simulator renders the same frames and checks them.
- **Memory.** Twelve open-draw-warn-close cycles keep the footprint within 16 MB of the first (asserted when the class runs
  alone) and leave the scene with no renderers after each warning and close.
- **Running it.** CI's step "Lissajous Labyrinth regression (host)"; locally `python3 scripts/lissajous_labyrinth_regression.py`.

## In the app (R02-G02-09)

- **Stored examples.** `LissajousLabyrinthSchemaExamples` builds one saved state of schema 1 (level 1 with one action
  that does not win) and one of schema 2 (level 1 solved before traces existed); the registration stores both and the
  app's migration check restores them into schema 3.
- **Identifiers.** Every panel control carries `experience.r02-g02.lissajous-labyrinth.<name>` (the names are
  `LissajousLabyrinthControls.identifierNames`), beside its label and value.
- **Interface tests.** `LLPlayUITests` wins level 1 with the steppers and Apply, then relaunches and finds the stars and
  level 2 kept; `LLReplayUITests` replays the win to its end. They run as the serial chunk `k3` of
  `scripts/release_check.py`. Lissajous Labyrinth stays a candidate (`-vcCandidates`) until X-R02-G02.

## Device preparation (R02-G02-10)

- **Definition.** `docs/apps/lissajous-labyrinth/device-rows.json` names the device scenario set (the 11 standard and
  game scenarios and `fixture-level-1-solved`), the devices D1, D2, D3 tied to the ledger's DEV1/2/3-R02-G02 rows, and
  rows LL-D1 … LL-D8 (launch, frame pacing, memory and the stress session, gesture feel, sound and haptics, VoiceOver
  (non-gating), termination, the panel journeys), each covering the deferred device tasks of features 313–319.
- **Plan.** `docs/apps/lissajous-labyrinth/device-campaign.md` is the written twin for the owner and the campaign.
- **Check.** `python3 scripts/check_device_rows.py --experience r02-g02.lissajous-labyrinth` (release step
  `device-rows-r02-g02`). Every row is "pending device campaign"; no device is contacted before ImplementationLock-100.

## Failures

`LissajousLabyrinthError` reason codes: `r02-g02.level`, `r02-g02.move`, `r02-g02.stage`, `r02-g02.stale`,
`r02-g02.allowance`, `r02-g02.newer-schema`, `r02-g02.malformed`, `r02-g02.generation`, `r02-g02.witness`.

## Sources

The game design is VisualCore's own (archived round-two design); the code and the sine table are original. Nothing here
draws.
