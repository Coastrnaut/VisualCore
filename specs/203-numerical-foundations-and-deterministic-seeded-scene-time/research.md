# Research: R02-F03 — Numerical foundations and deterministic seeded scene time

**Date**: 2026-11-13 · **Spec**: [spec.md](spec.md) · Section 13 disposition: **reuse** (`docs/catalog/shared-feature-map.json` round-02 F03).

## 0. Read-only audit (2026-11-13, `main` at `ebc51a2`; `Build/agent-notes/R02-F03-audit.md` re-verified)

| Source | Verified |
|---|---|
| `Packages/VisualCore/Sources/VisualCoreSimulation/FixedStepClock.swift`, `FixedStepRunner.swift`, `TimeStepPolicy.swift`, `SceneClock.swift` | exist; fixed-step accumulator with at most 8 steps per frame, dropped time, invalid-delta count, interpolation alpha; not changed by this feature |
| `VisualCoreSimulation/SeededRandom.swift` | `SplitMix64` (public `state`, `init(seed:)`, `next()` with the finalizer inline, no separate finalizer function); `SeededRandom: RandomNumberGenerator, Sendable, Equatable` with private `s0…s3`, public `let seed` (part of equality), `init(seed:)`, `next()`, `double()`, `float()`, `range(_:)`, `int(_:)` (rejection sampling), `normal(mean:deviation:)` |
| `Tests/VisualCoreSimulationTests/SeededRandomTests.swift` | golden sequence for seed 42 and the published SplitMix64 value; must keep passing unchanged |
| `VisualCoreMath/StableHash.swift` | SHA-256 (`sha256`, `sha256Hex`); not a fast 64-bit hash; unchanged |
| `VisualCoreExperience/StateDigest.swift` | `DigestBuilder` rejects non-finite values and writes −0 as 0; unchanged |
| `VisualCoreMath/Matrix.swift` | comments: column-major `m[c][r]`, counter-clockwise y-up 2D, right-handed with −z forward and the OpenGL depth range |
| `VisualCoreRendering/GLSL/vc/hash.glsl` | `vc_pcg(uint)` (`state = v*747796405u + 2891336453u; word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u; return (word >> 22u) ^ word`), `vc_hash11(float)`, `vc_hash21(vec2)`, `vc_hash22(vec2)` (bit patterns via `floatBitsToUint`, divide by 4294967296.0); no Swift twin exists |
| `ExperiencesCreative/ParticleUniverse/Experience/Adapter/ParticleCore.swift:38,179,262` | `seedStep = 0x9E37_79B9_7F4A_7C15` added by hand; its digests are committed, so it stays (FR-R02F03-013) |
| `Tests/VisualCoreRenderingTests/FullScreenShaderSceneTests.swift:26-33` | pattern for rendering a fragment shader with `FullScreenShaderScene` on a `RenderHost` and reading RGBA8 pixels with `readPixels()` — reused for the hash parity test |
| `docs/architecture/` | exists (no determinism document yet) |

**Correction to the clarifications:** the generator stores its `seed` and equality includes it, so the saved state
carries the seed too (spec FR-R02F03-031 updated).

## 1. Decisions

- **D1 Derivation** (clarification 1): `SeedDerivation` (enum namespace) in VisualCoreSimulation with `mix(_:)` (the
  SplitMix64 finalizer), `fnv1a64(_:)`, `derive(_:label:)`, `derive(_:index:)`; `SeededRandom.init(seed:label:)` and
  `init(seed:index:)`. Consumers: R02 puzzle/level generation (R02-F16, R02-F23), future experiences; A04 keeps
  `seedStep`. Alternative rejected: SHA-256 of the label (slower, needs Foundation crypto on every call).
- **D2 Owned algorithms** (clarification 2): extension methods on `SeededRandom` — `index(below:)` (one draw, high
  half of `next().multipliedFullWidth(by: n)`), `shuffle(_:)` (Fisher–Yates from the end, n − 1 draws),
  `shuffled(_:)`, `pick(_:)` and `weightedIndex(_:)` throwing a typed `RandomChoiceError`. Consumers: R02 deck and
  tile games, A01 composition variations.
- **D3 Saved state** (clarification 3, corrected): `SeededRandom.State: Codable, Sendable, Equatable` with `version`,
  `seed`, `words` (hex strings); `state` property and `init(restoring:) throws(RandomStateError)`. Consumers: games
  that save mid-level (UA-F03 sessions).
- **D4 Shader twin** (clarification 4): `ShaderHash` in VisualCoreMath: `pcg(_ v: UInt32) -> UInt32`,
  `hash11(_ p: Float) -> Float`, `hash21(_ x: Float, _ y: Float) -> Float`, `hash22(_ x: Float, _ y: Float) -> (Float,
  Float)`. Parity test renders `vc_pcg(index)` for 64 indexes, packing the four bytes into RGBA8 (exact for 8-bit
  normalized output), and compares with the CPU. Consumer: GPU noise fields that game rules also sample.
- **D5 Numeric hygiene**: `NumericHygiene` in VisualCoreMath: `finite(_:or:)`, `normalizedAngle(_:)` → [−π, π),
  `wrapped(_:modulus:) throws(NumericError)`, `quantized(_:step:) throws(NumericError) -> Int64`. Consumers: A04
  particle positions, R02 physics digests.
- **D6 Document** (clarification 5): `docs/architecture/determinism.md`; a script `scripts/check_doc_names.py`
  (new) checks backticked public names against `docs/api/visualcore-public-api.txt`.
- **D7 Typed throws**: Swift 6 typed throws as already used by `DigestBuilder`.

## 2. Analysis record (`/speckit-analyze`, 2026-11-13)

Round 1: 0 critical, 1 high, 1 medium. C1 (high): A04's committed digests are proven by the ExperiencesCreative
package tests, now in T-R02F03-025 and quickstart. C2 (medium): T-R02F03-024 records new suite durations
(SC-R02F03-008). Round 2: 0 critical, 0 high, 0 medium; 30 of 30 requirements and 8 of 8 success criteria covered.

## 3. Implementation corrections (2026-11-13)

- The float hashes (`vc_hash11`, `vc_hash21`, `vc_hash22` and their twins) return values in [0, 1], not [0, 1):
  float conversion rounds the largest 32-bit words up, so `Float(0xFFFFFFFF) / 2^32 == 1.0` on the GPU and the CPU.
  The `ShaderHash` documentation states [0, 1]; the GLSL comment "[0, 1)" is in the shader library and unchanged.
- `SeededRandom.State` gained `public init(version:seed:words:)` (contracts/api.md updated); `SeededRandom`'s state
  words became `internal private(set)` with an internal initializer, without any change of output or equality.
- The parity test strides by the surface's pixel width (display scale makes the 8×8-point view at least 16×16 pixels),
  so it compares 256 or more words, all exactly.
