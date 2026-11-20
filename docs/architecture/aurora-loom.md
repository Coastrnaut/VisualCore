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

## Content: generator, solver and witnesses (R02-G01-02)

- **Manifest.** `AuroraLoomManifest.entries` holds the 100 planned levels of the archived design (number, planned seed,
  band, move budget; 20 per band). The move budget becomes the level's allowance.
- **Generator.** `AuroraLoomGenerator.generate` draws candidate k of an entry from
  `SeededRandom(seed: SeedDerivation.derive(seed, index: k))`: a winning (wave, phase) shared by the three ribbons, four
  distinct gate positions, target offsets of at most half the tolerance and a scramble of 1 … 6 controls. Every ribbon
  turns with Ω. `AuroraLoomBandProfile` sets Ω (16, 32, 64, 128, 256), the tolerance (160, 96, 64, 40, 24) and the shortest
  solution accepted (1–2 … 5–6) for bands 1 … 5. The first candidate the solver proves inside the band and the budget is
  kept (at most 64; otherwise `r02-g01.generation`). Ids are `aurora-loom-NNN`; levels 1 … 3 have a tutorial.
- **Solver.** Ribbons do not interact, so `AuroraLoomSolver.solve` solves each among its 256 settings: coordinate descent
  (wave, then phase, each the value with the smallest largest |residual|, at most 32 sweeps), then the exact grid, which
  proves the fewest changes (0, 1 or 2). The shortest solution is their sum; the witness moves go by ribbon, wave before
  phase; ties go to the lower (wave, phase). A ribbon turning with Ω has the same residual at every tick, so its score is
  read at tick 0 (exact). The method is `descent` when descent alone reached the optimum on every ribbon, else `grid`; the
  work is the number of settings evaluated.
- **Difficulty.** `AuroraLoomDifficulty` keeps the shortest solution, the work, the winning settings, the tolerance and Ω;
  `puzzleDifficulty` feeds R02-F24's `ProgressionRule.standard`, which the catalog keeps; band means of shortest and work
  do not fall.
- **Witnesses.** `AuroraLoomWitness` (schema 1) replays the solution on a play and stores the level, the actions, the
  fingerprint after `begin` (and the tutorial) and after each action, the terminal worst mismatch, a counterexample (ribbon
  0's phase one step on, which always loses because every tolerance is below one phase step of 256 units), the difficulty,
  the method and the skipped candidates. The 100 files are `docs/games/aurora-loom/levels/NNN.witness.json`; the catalog
  test compares them byte for byte and writes them only with `AURORA_LOOM_WRITE_WITNESSES=1`. Decoding replays the actions
  and refuses newer (`r02-g01.newer-schema`), damaged (`r02-g01.malformed`) and edited witnesses (`r02-g01.witness`).
- **Catalog digest.** `AuroraLoomGenerator.catalogDigest` is `PuzzleCatalog<AuroraLoomRules>.digest(id: "aurora-loom",
  identities:)` over the level fingerprints in manifest order, pinned in `AuroraLoomCatalogTests`.

## Renderer and experience (R02-G01-03)

- **Snapshot.** `AuroraLoomSceneSnapshot` is the only thing the renderer reads: the level, the six steps, the stage, the
  failure and the frame time in ticks. The adapter `AuroraLoomExperienceCore` (the shared `ExperienceCore`) makes it; no
  drawing result, tier or time reaches the kernel or the digest (renderer purity, R2-G01-INV-10).
- **Picture.** Each ribbon is drawn along the loom (x from −4 to +4 for s = 0 … 16) at height
  H · sin(2π θ / 4,096), θ = wave · s · 16 + phase · 256 + ω t, in its own lane in depth; the gates are rings across the
  loom and a gold marker on each ring shows the target's height. A ring and its marker brighten when all three ribbons
  meet that gate within the tolerance. The geometry (`AuroraLoomSceneGeometry`) uses R02-F08's Catmull-Rom curves,
  parallel-transport frames and ribbon meshes; the camera fits the whole loom for aspects 0.4 … 2.5 with a 6 % margin.
- **Materials.** `AuroraLoomShaders` (GLSL ES 3.00): wave displacement along the normal, bevel shading across the
  ribbon, interference shimmer along it, the palette (night #07121A, teal #1FD1B4, magenta #E0389C, acid gold #D8E83A)
  and an emissive glow drawn as additive halo passes. They are drawn by VisualCoreRendering's `ShaderMeshRenderer`, which
  draws a generated mesh with a caller-supplied program.
- **Tiers.** `level-0` (five layers, 128 segments, two glow passes), `level-1` (three, 64, one) and `level-2` (one, 32,
  none), richest first as the shared quality contract requires; every tier draws the same centre lines, gates and
  markers. The presenter logs each tier change with its reason.
- **Failures and settings.** A program that does not compile makes the scene draw the minimal layer with the shared unlit
  renderer and keep the reason; Reduce Motion holds the silk still; Reduce Flashing caps the glow gain; a memory warning
  releases the GPU objects, which the next frame rebuilds.
- **Candidate.** `r02-g01.aurora-loom` is registered in `Catalog/registrations.json` and linked into the one app as a
  candidate; it stays unavailable until X-R02-G01. A minimal panel (wave and phase steppers per ribbon, undo, redo, next
  level) drives the kernel until the gestures of R02-G01-04.

## Failures

`AuroraLoomError` reason codes: `r02-g01.level`, `r02-g01.move`, `r02-g01.stage`, `r02-g01.stale`,
`r02-g01.allowance`, `r02-g01.newer-schema`, `r02-g01.malformed`, `r02-g01.generation`, `r02-g01.witness`.

## Sources

The game design is VisualCore's own (archived round-two design); the code is original. Nothing here draws.
