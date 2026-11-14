# Determinism and conventions (feature 203, R02-F03)

This page states which operations of VisualCore replay identically, which do not, and the coordinate, unit and
handedness conventions every experience follows. It is the single reference for FR-R02F03-060 and FR-R02F03-061;
`python3 scripts/check_doc_names.py docs/architecture/determinism.md` proves that every public name it cites exists
in `docs/api/visualcore-public-api.txt` (FR-R02F03-062).

## 1. Step policy

Simulation advances in fixed steps; frame time never enters game rules directly.

- `FixedStepClock` turns variable frame deltas into a bounded number of fixed steps: the default step is 1/120 s,
  at most 8 steps run per frame (`FixedStepClock.maxSteps`), time beyond the cap is counted in
  `FixedStepClock.droppedTime`, NaN, infinite or negative deltas count as zero and are counted in
  `FixedStepClock.invalidDeltas`, and `FixedStepClock.alpha` is the fraction of a step left for render
  interpolation. `FixedStepClock.boundaryTolerance` makes 60 frames of 1/60 s give exactly 120 steps despite
  floating-point rounding.
- `FixedStepRunner` drives a `FixedStepSimulation` with that clock, counts completed steps in
  `FixedStepRunner.stepIndex`, pauses and resumes without catch-up, and applies a `ControlStream` of commands by step
  index, so a replay gives the same state however the frames were split.
- `TimeStepPolicy` clamps a frame interval to a variable step between 1/240 s and 1/30 s for code that does not
  replay (visual effects only); it is not used by game rules.
- `SceneClock` is presentation time for creative scenes: play, pause, scrub, speed 0…4×, half rate under Reduce
  Motion, a single delta capped at `SceneClock.maxDelta`, wrapping at the timeline duration. It is not a replay
  clock.
- An experience built on `ExperienceCore` declares its step length with `ExperienceCore.stepDuration` (default
  1/120 s, used clamped to 1/240…1/30 s) and is advanced one step at a time with an integer step index starting
  at 0. The step index, never accumulated seconds, is the time base of every rule and every digest.

## 2. Game rules use integers

Rules that decide an outcome (scores, moves, collisions on a grid, win and loss, level generation, timers) work on
integers: integer step counts instead of seconds, integer grid cells instead of positions, fixed-point integers where
a fraction is needed. Floating point is allowed for presentation (positions on screen, colours, easing, particles)
and for creative simulations whose digests are committed on the reference platform (section 3). A value that moves
from floating point into a rule is first quantized to an integer (section 5).

## 3. Trust boundary of floating-point and transcendental functions

- Basic IEEE 754 arithmetic (`+`, `-`, `*`, `/`, square root) on `Double` and `Float` is exactly rounded and gives
  the same bits for the same operations in the same order.
- Transcendental functions (`sin`, `cos`, `exp`, `log`, `pow`, `atan2`) come from the system math library. Their
  results are **identical on the reference host and on the simulators**, because both run the same arm64 build
  against the same library; this is what the committed scenario digests are measured on. On physical devices they
  are **observed, not assumed**: the device campaign that starts after `ImplementationLock-100` replays the committed
  scenarios and reports any difference.
- No fast-math: no target enables `-Ounchecked` or relaxed floating-point flags, and none may.
- Fused multiply-add contraction is **not assumed** either way. Code whose digest depends on the exact rounding of
  `a * b + c` writes the operation explicitly (one form or the other) instead of relying on the compiler.
- GPU floating point is outside the boundary: shader output never feeds a rule, except through the integer hash of
  section 6.

## 4. Randomness

- `SeededRandom` is the only generator for simulations: xoshiro256** seeded through `SplitMix64` from a 64-bit
  seed, conforming to `RandomNumberGenerator`. Its output is pure 64-bit integer arithmetic and therefore identical
  everywhere; `SeededRandom.double()` and `SeededRandom.float()` take the top 53 and 24 bits, `SeededRandom.int()`
  is rejection-sampled, `SeededRandom.normal()` uses Box–Muller (and so falls under section 3). The golden sequences
  of both generators are committed and never change.
- **Stream derivation** (`SeedDerivation`): every independent stream (a level, a layer, an emitter) gets its own
  sub-seed instead of sharing draws. A label derives `mix(seed XOR fnv1a64(label))` with the FNV-1a-64 hash of the
  label's UTF-8 bytes; an index derives `mix(seed XOR mix(index + 1))`; `mix` is the SplitMix64 finalizer.
  Derivations chain (seed → level → layer). `SeededRandom` can be created directly from a seed and a label or an
  index. Golden values are committed.
- **Owned choice algorithms** with fixed draw counts, so a replay never depends on the standard library's shuffle:
  a random index below n uses exactly one 64-bit draw (high half of the 128-bit product; bias at most n/2^64,
  accepted for exact replay); a pick uses 1 draw; a shuffle of n elements uses n − 1 draws (Fisher–Yates from the
  end); a weighted choice uses 1 draw scaled to the weight sum. Empty lists, negative or non-finite weights and a
  zero total are reported with `RandomChoiceError`, never answered with a value.
- **Saved state**: a generator's state is saved as a small Codable value with a format version (1), the seed and the
  four state words as 16-digit lower-case hexadecimal strings. Restoring refuses another version, a wrong word count
  or length, non-hex text and the all-zero state with `RandomStateError`.
- Existing hand-made offsets stay: A04 Particle Universe derives its scene seed with its own `seedStep` constant
  because its digests are committed. The derivation above is for new code.

## 5. Numeric hygiene

- `NumericHygiene` holds the pure helpers: replacing a non-finite value with a stated fallback, normalizing an angle
  to [−π, π), wrapping into [0, modulus), and quantizing a value to an integer count of grid steps (−0 written as
  0). Invalid input (non-finite values, a non-positive modulus or step, a result outside the integer range) is
  reported with a typed error, never answered with a value.
- `DigestBuilder` is the last line of defence: it rejects NaN and infinities with `DigestError` and writes −0 as 0,
  so no non-finite value and no sign of zero ever reaches a `StateDigest`.

## 6. Shader hash twin

`ShaderHash` is the CPU twin of the integer hash in the shader library file `vc/hash.glsl`: the PCG integer hash
`vc_pcg` and the value hashes `vc_hash11`, `vc_hash21` and `vc_hash22` built on it (float inputs taken by their bit
pattern as the shader does). The integer hash is exact on both sides and a simulator test compares 64 rendered
values bit for bit, so a game rule may sample the same noise field the GPU draws. The value hashes end in a float
division and are trusted only within section 3.

## 7. Replay

- An `ExperienceScenario` is a seed and a list of entries, each a number of fixed steps followed by an optional
  `ScriptedAction`; running it gives an `ExperienceScenarioResult` with the final `StateDigest` and step index.
  Scenarios exist only in debug and automation builds.
- A `ScenarioManifest` (`scenario-manifest.json` beside each experience) lists the experience's controls and its
  scenarios with the expected digests; seeds are written as decimal text. These digests are committed and must stay
  byte-identical: a change in a digest is a change in behaviour.
- Below the experience layer, `FixedStepRunner` replays a `ControlStream` of commands keyed by step index; equal
  streams on equal seeds give equal states however frames are split.

## 8. Transform conventions

- **Storage**: `Mat3` (2D affine) and `Mat4` (3D) are column-major like GLSL, element `m[c][r]`; `Mat4.floats`
  uploads straight into a `mat4` uniform. A product `a · b` applies `b` first.
- **2D**: y points up and positive rotation is counter-clockwise.
- **3D**: right-handed, the camera looks down −z (`Mat4.lookAt`), and `Mat4.perspective` maps depth to the OpenGL
  clip range −1…1.
- **Units**: time in seconds, angles in radians, screen coordinates in points (UIKit) and framebuffer coordinates in
  pixels (points × the screen scale).
- **UIKit conversion**: UIKit has its origin at the top left with y down; GL framebuffer coordinates have their
  origin at the bottom left with y up. A touch converts as x_gl = x_uikit × scale and
  y_gl = (height − y_uikit) × scale, with `height` the view height in points and `scale` the view's content scale.

## 9. Mesh digests

`Mesh.digest` (feature 205, R02-F05) is the SHA-256 (`StableHash`) of a little-endian stream: the four array counts,
every position, normal and texture-coordinate component as its IEEE-754 binary64 bit pattern (−0 written as +0), then
every index. Mesh builders and shapes use only arithmetic and the trusted functions of section 3, so the same
description gives the same digest on the host and on both simulator runtimes; committed digests are checked on all
three. A change in a digest is a change in geometry.
