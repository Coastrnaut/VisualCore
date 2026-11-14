# VisualCore (pure modules)

Host-testable Swift modules with no GPU and no UIKit. They run on macOS for `swift test` and on
iOS 26+ inside apps. The package map and dependency rules R1–R5 are in
[`specs/002-architecture-contracts/contracts/package-map.md`](../../specs/002-architecture-contracts/contracts/package-map.md).

| Product | Purpose |
|---|---|
| VisualCoreMath | vectors, matrices, quaternions, cameras, double-precision plane viewports (PlaneViewport) and size-independent framings (PlaneFraming), log-scale framing flights and tour timelines (FramingFlight, TourTimeline), precision advice (PrecisionAdvisor), easing |
| VisualCoreSimulation | fixed-step clock, seeded RNG, timelines, particle pool, NaN guard, CPU field grids, storage precision, time-step policy |
| VisualCoreScenes | input mapping, pointer tracking and velocity, seeded synthetic gesture scripts, mesh generators, export geometry |
| VisualCoreShaderSource | shader library, includes, line maps, diagnostics parsing |
| VisualCoreEffectsGraph | effect DAG model, validation, quotas, flash-limiter model |
| VisualCoreDiagnostics | render lifecycle state machine, frame statistics, reports, relative render-cost estimates (RenderCostEstimate) |
| VisualCoreAudioDSP | **placeholder, not built yet** — planned: lock-free ring, FFT, bands, RMS, onsets ([ADR-0006](../../docs/decisions/ADR-0006-unbuilt-readme-modules.md)) |
| VisualCorePersistence | `DocumentStore` (versioned envelopes, atomic writes, migrations, per-file problem reports), A01-P03; app-owned temporary folders (TemporaryFolder); named, favoritable document libraries (NamedLibrary), A03-P03 |
| VisualCoreParameters | parameter schemas (units, ranges, linear/log sliders), resolution, palettes (sRGB, linear-light sampling), presets, stable `ParameterHash` |
| VisualCoreExperience | experience identity (`ExperienceID`, `ExperienceCode`), descriptors, tiers and categories, the validated runtime catalog (`CatalogManifest`: bounded loading with typed errors, launch allocation, search, registry check), UA-F01; the pure part of the experience contract (`ExperienceCore`, `ExperienceEngine`, `ExperienceLifecycle`, `StateDigest`, `ExperienceSnapshot`, `ExperienceDiagnostics`, `ExperienceConformance`), UA-F02 |
| VisualCoreTestSupport | test-only (rule R5): `ImageComparison`, `ImageDifference`, `ImageStatistics` for pixel tests; the sample experience `SampleExperienceCore` with its fault markers and `SampleExperience` (UA-F02); fake clock and fixtures still planned (ADR-0006) |

Imports allowed (R2): Foundation-level system modules (`Foundation`, `Dispatch`, `os`, `simd`,
`Accelerate`, `Synchronization`) and other modules of this package.

```bash
swift test --package-path Packages/VisualCore
python3 scripts/check_dependencies.py
```

Version 1.0.0-rc.1 (semantic versioning; release candidate from the F09 stabilization gate — see [release notes](../../docs/release/release-notes-1.0.0-rc.1.md)).

## Input, animation, scenes and particles (feature 006, gate F05)

Contract: [`specs/006-input-animation-scenes/contracts/interaction-api.md`](../../specs/006-input-animation-scenes/contracts/interaction-api.md).

**Coordinate spaces** (`VisualCoreScenes.ViewMetrics`, `VisualCoreMath.Camera2D`):

| Space | Origin | Axes | Units |
|---|---|---|---|
| view points | top-left | x right, y down | UIKit points |
| pixels | top-left | x right, y down | points × `scale` |
| NDC | center | x right, y up | −1…1 |
| camera | view center | x right, y up | points |
| world | `Camera2D.center` | x right, y up | points at zoom 1 (`zoom` 0.1…100) |

Conversions round-trip within 0.001 pt (SC-F501) and return nil for a zero-size view.
`worldToNDC(camera:)` is the matrix renderers use.

**Gestures** (`PointerTracker` + recognizers; feed the tracker first, then each recognizer; call `tick(now:)`
for time-based transitions). Defaults: tap ≤ 10 pt and ≤ 0.3 s; double-tap second tap within 0.3 s and 30 pt;
long-press ≥ 0.5 s within 10 pt; drag after 10 pt. Pinch and rotate run together; a second finger cancels an
active drag and fails a pending tap. At most 10 pointers; more are ignored and counted.

**Touches as forces** (`PointerVelocityTracker`, feature 020): turns pointer events into samples at most `spacing`
points apart along each finger's path, each with a smoothed velocity in points per second.
- **Smoothing**: an exponential average with α = `smoothing`. The first move uses the raw velocity, and intervals
  under 1 ms keep the previous velocity.
- **Phases**: `began` gives one still sample, `ended` a final sample, and `cancelled` nothing.
- **Limits**: at most 10 pointers and `maxSamplesPerUpdate` samples per update (the newest location is always
  included). Non-finite events are rejected. Every limit is counted.
- **Uses**: fluid splats, physics pushes and brush strokes get a continuous trail with bounded work.

**Timing and determinism** (`VisualCoreSimulation`): `FixedStepClock` (1/120 s, ≤ 8 steps per frame, excess
time dropped and counted, 1e-9 s boundary tolerance, invalid deltas = 0). `SeededRandom` is xoshiro256** seeded
through SplitMix64; integer sequences are identical on every platform. Simulations driven by the clock and the
generator are bit-identical per platform and independent of the display rate (proven at 60 and 120 Hz); float
identity across CPU architectures is not promised.

**Frame pacing** (`VisualCoreDiagnostics`): `FramePacing(thermal:lowPower:requestedMaxFPS:)` gives the display-link
cap and render scale; `FramePacing.Range` is its minimum, maximum and preferred frame rate (`CAFrameRateRange` on
iOS). `FramePacing.Thermal` (`nominal`, `fair`, `serious`, `critical`) mirrors
`ProcessInfo.ThermalState`, so the module stays platform-neutral. Low Power Mode or a serious or critical thermal
state caps the rate at 30 fps (never below 30), and a critical state also scales rendering to 0.75. Simulations
receive frame deltas clamped to `FramePacing.maximumDelta` (0.1 s).

**Quality tiers** (`QualityPolicy`, feature 021): an app defines an ordered list of tiers (0 is the best) and what
each one means, for example solver iterations, particle counts or effect passes. `decide(thermal:lowPower:now:)` picks
the tier:
- **Stepping down**: one tier down on a serious or critical thermal state, or when Low Power Mode is on and the tier
  is better than `lowPowerCeiling`.
- **Stepping up**: one tier up after `calmPeriod` seconds (default 10) of a nominal or fair state without Low Power.
- **Limits**: at most one change per `decisionInterval` (default 2 s), never below the last tier.

**Particle budget and device conditions** (feature 034, gap G-PQUALITY): `ParticleBudget` turns a tier into a count
cap, `limit(requested:tier:) = min(requested, max(minimum, ⌊requested × share⌋))` (`.standard`: shares 1, 0.6, 0.35,
0.2, minimum 100). `DeviceConditions.current()` reads the thermal state and Low Power Mode from `ProcessInfo` for
`QualityPolicy.decide`. `ParticleSystem.liveLimit` applies the cap: emission stops at it, nobody is removed.

Time is passed in, so decisions are deterministic and host-testable. `reset()` returns to the best tier.

**CPU field references** (`VisualCoreSimulation`, feature 019): a `FieldGrid` is a W×H grid with 1…4 channels,
row-major from the bottom row up, as in GL. `StoragePrecision` (`float32`, `float16`, `float16TowardZero`, `unorm8`) rounds values the
way GPU storage does after every step. GLES leaves the rounding of half-float color writes implementation-defined,
and the iOS 27.2 and 26.5 simulators truncate, so compare against both half modes. Half precision uses portable round-to-nearest-even with no `Float16` dependency;
unorm8 is clamped to 0…1 and stored as n/255. Its `tolerance` is one storage step (1e-6, 1e-3, 1.5/255), so a GPU pass
can be compared with a CPU reference of the same precision. `FieldGrid.sampleBilinear(cellX:cellY:)` interpolates exactly, with cell centers at `i + 0.5` and the edge clamped,
using `a + (b − a)·t` in x and then y. It is the CPU twin of the `vc/field.glsl` shader include, so semi-Lagrangian
advection references match the GPU. `SignedRangeEncoding` stores −range…range in 0…1 for RGBA8 fallbacks.
Use `SignedRangeEncoding.unorm8(range:)`, which puts zero at the exactly storable 128/255. With a 0.5 center, a field
at rest would decode to a small non-zero value and drift. `TimeStepPolicy` gives one bounded step per frame (1/240…1/30 s; invalid deltas
use the minimum), so a resume after a pause takes neither a huge step nor a catch-up loop.

**Animation**: `ease(_:_:_:)` (linear, quad, cubic, sine, expo, back, elastic, bounce × in/out/inOut; f(0)=0,
f(1)=1), `Tween` (repeat count or forever, autoreverse) and `Timeline` (play, pause, seek, reverse via negative
`rate`, completion events once per pass, `reduceMotion` jumps to end values and disables repeats).

**Scenes and particles**: `SceneNode` (TRS transform, z-order, visibility, primitive rect/circle/line/polygon
≤ 256 points, hit testing); `ParticleSystem` (capacity 10,000 default, ≤ 100,000; `Emitter`s with rate, burst, lifetime, speed, direction/spread,
size and color over life; `ParticleForce` gravity/drag/attractor and (feature 034, G-FIELDS) repulsor, softened
`gravityWell`, `wind` and `vortex`, each with `clamped()`, `bound(speed:)` and `acceleration(at:velocity:)`, finite at
every position including the center; `liveLimit`; `liveCount(source:)` (feature 035); `TrailDecay` (feature 035: frame-rate-independent fade of 8-bit trail
images, `factor`, `subtraction`, `step8`); NaN removal, `checksum()`; `instances()` →
`ParticleInstance` for `ParticleRenderer`); 3D: `OrbitCamera` (pitch ±89°, `project`, `ray`), `Mesh.plane/cube/uvSphere`
(segments 3–256, rings 2–256, subdivisions ≤ 256). Feature 205 (R02-F05) adds the mesh compiler: `MeshBuilder` (welding of
equal vertices, `MeshBudget` default 262,144 vertices and 1,572,864 indices, typed `MeshError`), the shapes
`Mesh.surface`, `.revolution`, `.extrusion`, `.tube` (rotation-minimizing frames) and `.bevelledBox`,
`withSmoothNormals(creaseAngle:)` and `withFlatNormals()`, `bounds` (`MeshBounds`), a SHA-256 `digest`, and
`validate(requireClosed:budget:)` returning a `MeshReport` of up to 100 `MeshProblem`s (14 kinds) with a
`MeshSummary`; topology is judged by welded position.

## Parameters (feature 012, A01-P01)

`ParameterDefinition(name:title:unit:range:defaultValue:transform:)` validates a user-adjustable value. Names match
`^[a-zA-Z][a-zA-Z0-9_]{0,31}$`, and ranges must be finite; `logarithmic` needs a minimum above 0.
`normalized(_:)`/`value(normalized:)` map to slider positions. `ParameterSchema.resolve(_:)` throws `.nonFinite` for
NaN or ±∞, clamps out-of-range values, fills defaults and drops unknown names (each with a warning in
`ResolvedParameters.warnings`).

`Palette` stores 2–8 sRGB stops. `sample(_:)` interpolates in linear light, `linearStops` are what shaders receive,
and there are six `Palette.builtIns`.

`Preset` encodes its 64-bit seed as a decimal string. `ParameterHash.of(scope:seed:paletteID:values:)` is a stable
FNV-1a key (16 hex digits), suitable for caches that persist across launches.

`VisualCoreTestSupport` (test targets only) compares RGBA8 buffers. `ImageComparison.compare(a, b)` gives an
`ImageDifference` with `meanAbsolute`, `maxAbsolute` and `fractionWithin(_:)` over RGB channels.
`ImageStatistics.meanLuminance(_:)` and `distinctColors(_:)` flag blank renders.

`ParameterEditor(schema:values:)` (feature 013) holds the values being edited plus the baseline that reset returns to.
- `set(_:to:)` clamps a value and refuses non-finite ones.
- `set(_:normalized:)` takes a slider position; a non-finite position counts as 0.
- `reset(_:)` and `resetAll()` return to the baseline; `isModified(_:)` and `modifiedNames` report changes.
- `rebase(_:)` replaces the baseline.
- `formatted(_:)` gives the value with 3 significant digits and its unit.

## Scene clock (feature 013, A01-P02)

`SceneClock(duration:speed:isPlaying:)` turns frame deltas into deterministic scene time, without using the wall
clock.
- `advance(by:)` caps one delta at 0.25 s, so returning from the background never jumps. It multiplies by `speed`
  (0…4) and by 0.5 when `reducedMotion` is on, and wraps at `duration`.
- `scrub(to:)` clamps to the timeline.
- `play()`, `pause()` and `toggle()` switch state; paused time never changes.

## Persistence (feature 014, A01-P03)

`DocumentStore<Value>(directory:kind:migrations:maxBytes:)` keeps `Codable` values as `<id>.json` envelopes
(`kind`, `schemaVersion`, ISO 8601 `savedAt`, `payload`).

- **Writes** (`save(_:id:)`) go to a hidden temporary file in the same folder and then replace the target, so a crash
  leaves either the old or the new complete file. Ids match `^[A-Za-z0-9._-]{1,128}$`.
- **Reads**: `load()` returns a `LoadReport` of readable `StoredItem`s plus one `StoreProblem` per unreadable file:
  `.corrupt`, `.wrongKind`, `.newerVersion` or `.tooLarge`. The size is checked before reading. Problem files are
  never modified, moved or deleted.
- **Migrations**: `MigrationChain(currentVersion:steps:)` upgrades older payloads (JSON objects) step by step on
  load. The file is rewritten only by a later save. Newer versions are rejected.

## Export geometry (feature 015, A01-P04)

`ExportGeometry(maxEdge:maxPixels:)` turns a requested long edge and an `ExportAspect` (built-ins `square` 1:1,
`portrait` 4:5, `landscape` 16:9, `story` 9:16, or any positive ratio) into an even `ExportSize`:

- long edge = min(requested, `maxEdge`, 8192);
- short edge = the ratio's share of the long edge, rounded to an even number (1080 at 4:5 → 864 × 1080; at 16:9 →
  1080 × 608);
- the long edge shrinks in steps of 2 until width × height ≤ `maxPixels` (default 64 million).

Pass `RenderHost.maxRenderSize` as `maxEdge` to stay within the device's renderer limits.

## Accessibility preferences (feature 016, A01-P05)

`AccessibilityPreferences` (VisualCoreSimulation) holds an app's choices for Reduce Motion and Reduce Flashing, each an
`AccessibilityChoice`: `.system` (default), `.on` or `.off`. `resolve(_:)` combines them with `SystemAccessibility`
(the system's Reduce Motion and Dim Flashing Lights flags) into `EffectiveAccessibility`:

- `.system` takes the system flag, while `.on` and `.off` override it (Off is the user's explicit choice);
- `playbackRate` is `SceneClock.reducedMotionFactor` (0.5) under Reduce Motion, else 1;
- `AccessibilityChoice(storedValue:)` and decoding turn an unknown stored value into `.system`.

- `AccessibilityPreferences.keys(prefix:)`, `load(from:keyPrefix:)` and `save(to:keyPrefix:)` store the choices in
  `UserDefaults` as `<prefix>.reduceMotion` and `<prefix>.reduceFlashing` (the keys also work with `@AppStorage`).

On iOS, `VisualCoreUI.SystemAccessibilityObserver` supplies the system values.

## Experience contract (feature 188, UA-F02)

Every experience of the unified app has two parts. The pure part is a value type that conforms to `ExperienceCore`:
it is prepared from a 64-bit seed, advances in fixed steps, carries out validated actions, writes its state into a
`DigestBuilder` (SHA-256 through `StableHash` of VisualCoreMath) and can be captured in a versioned
`ExperienceSnapshot`. `ExperienceEngine<Core>` drives a core through `ExperienceLifecycle` (registered, preparing,
ready, active, suspended, deactivating, inactive, failed) and answers every call in every state: an operation that
is not legal is refused with a typed error, counted, and never reaches the core.

```swift
var engine = ExperienceEngine<MyCore>(id: myID)
try await engine.prepare(seed: 42)          // deterministic: the same seed gives the same digest
try engine.activate()
try engine.advance(frame: 1.0 / 60)         // fixed steps, at most 8 per frame, no catch-up after resume()
let result = engine.handle(control: "move", values: [1, 0])   // .accepted or .rejected(reason); a rejection changes nothing
let snapshot = try engine.snapshot()        // versioned envelope with seed, step index, digest and checksum
try engine.restore(snapshot)                // typed refusal for a foreign, newer, damaged or mismatching snapshot
try engine.reset()                          // the state of a fresh preparation with the same seed
```

Each experience's tests hand its core to the conformance helper, which runs seven checks and names every failure:

```swift
let report = await ExperienceConformance.run(MyCore.self, id: myID, plan: plan)
#expect(report.passed, "\(report.failed)")
```

`ExperienceDiagnostics` is the readable state for evidence files (state, seed, step index, tier, GPU counts, last
error, digest, counters). `ExperienceScenario` and the engine's `run(_:)` exist only under `DEBUG` or
`VISUALCORE_AUTOMATION`; `scripts/check_experience_symbols.py` proves that a release build has none of them.
Contract: [experience-core-api.md](../../specs/188-ua-f02-experience-sdk/contracts/experience-core-api.md).

## Verification scenarios (feature 195, UA-F09)

An experience's `ScenarioManifest` lists its scenarios. Each `ScenarioSpec` has a name, a seed, a list of
`ScenarioStep` entries (a number of fixed steps, then an optional `ScriptedAction` with its expected result and
digest) and `ScenarioExpectations` (initial and final digest, outcome, frame-probe classes, reset digest; an absent
item is not checked). `ScenarioManifestValidator.problems(_:controls:)` rejects a manifest that names an undeclared
control or lacks a standard scenario. A run's `EvidenceRecord` names the experience, the build, and in
`EvidenceRecord.Environment` the kind of machine and its operating system.
Contract: [verification-api.md](../../specs/195-ua-f09-verification-runner/contracts/verification-api.md).

A run's `EvidenceRecord.Environment` may carry a `RendererRecord` (feature 202): the renderer's versions, a few
limits, the missing entry points, the context generation and the floor findings, every field optional, under the key
`renderer`; a record without it stays valid.

## Games input, accessibility and haptics (feature 226, R02-F26)

`GestureArbiter` (VisualCoreScenes) takes pointer events and a game's `GestureDeclaration`s (kind, priority, pointer
count) and lets one gesture at a time own the touch; a loser or a cancelled touch ends as `cancelled`. It is pure and
deterministic. `GestureAlternatives.missing(gesture:native:)` (VisualCoreExperience) names every gesture action no native
control sends. `AnnouncementPlanner` and `HapticPlanner` (VisualCoreSimulation) apply rate limits (0.5 s and 0.05 s)
and the person's switches; `stateSignProblems` checks that every state has a distinct non-colour sign;
`transitionDuration(_:reduceMotion:)` makes animated transitions instant under Reduce Motion. `ShellPreferences.haptics`
is the Settings switch (absent means on).

## Numerical foundations (feature 203, R02-F03)

Time and randomness reuse `FixedStepClock`, `SceneClock`, `SplitMix64` and `SeededRandom` unchanged; their output and
every committed scenario digest stay the same. Added (all pure, value types or caseless enums):
`SeedDerivation` (VisualCoreSimulation) derives independent sub-seeds from a seed and a label or an index (SplitMix64
finalizer and FNV-1a-64); `SeededRandom(seed:label:)` and `SeededRandom(seed:index:)` start such a stream.
`SeededRandom.index(below:)`, `shuffle(_:)`, `shuffled(_:)`, `pick(_:)` and `weightedIndex(_:)` are owned algorithms
with a fixed draw count (one draw per random index), so results never change with the toolchain; they report bad input
with `RandomChoiceError`. `SeededRandom.state` and `SeededRandom(restoring:)` save and resume a generator
(`SeededRandom.State`, version 1, hexadecimal words; `RandomStateError` refuses other versions, malformed words and the
all-zero state). `ShaderHash` (VisualCoreMath) computes on the CPU exactly what `vc/hash.glsl` computes (`vc_pcg`
matches the GPU bit for bit; the float hashes lie in [0, 1]). `NumericHygiene` provides `finite(_:or:)`,
`normalizedAngle(_:)` ([−π, π)), `wrapped(_:modulus:)` ([0, modulus)) and `quantized(_:step:)` (`NumericError`). The rules
and conventions are in `docs/architecture/determinism.md`.
