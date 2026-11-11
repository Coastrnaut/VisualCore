# VisualCore (pure modules)

Host-testable Swift modules with no GPU and no UIKit. They run on macOS for `swift test` and on
iOS 26+ inside apps. The package map and dependency rules R1–R5 are in
[`specs/002-architecture-contracts/contracts/package-map.md`](../../specs/002-architecture-contracts/contracts/package-map.md).

| Product | Purpose |
|---|---|
| VisualCoreMath | vectors, matrices, quaternions, cameras, easing |
| VisualCoreSimulation | fixed-step clock, seeded RNG, timelines, particle pool, NaN guard |
| VisualCoreScenes | input mapping, pointer tracking, mesh generators, export geometry |
| VisualCoreShaderSource | shader library, includes, line maps, diagnostics parsing |
| VisualCoreEffectsGraph | effect DAG model, validation, quotas, flash-limiter model |
| VisualCoreDiagnostics | render lifecycle state machine, frame statistics, reports |
| VisualCoreAudioDSP | **placeholder, not built yet** — planned: lock-free ring, FFT, bands, RMS, onsets ([ADR-0006](../../docs/decisions/ADR-0006-unbuilt-readme-modules.md)) |
| VisualCorePersistence | `DocumentStore` (versioned envelopes, atomic writes, migrations, per-file problem reports), A01-P03 |
| VisualCoreParameters | parameter schemas (units, ranges, linear/log sliders), resolution, palettes (sRGB, linear-light sampling), presets, stable `ParameterHash` |
| VisualCoreTestSupport | test-only (rule R5): `ImageComparison`, `ImageDifference`, `ImageStatistics` for pixel tests; fake clock and fixtures still planned (ADR-0006) |

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

**Timing and determinism** (`VisualCoreSimulation`): `FixedStepClock` (1/120 s, ≤ 8 steps per frame, excess
time dropped and counted, 1e-9 s boundary tolerance, invalid deltas = 0). `SeededRandom` is xoshiro256** seeded
through SplitMix64; integer sequences are identical on every platform. Simulations driven by the clock and the
generator are bit-identical per platform and independent of the display rate (proven at 60 and 120 Hz); float
identity across CPU architectures is not promised.

**Animation**: `ease(_:_:_:)` (linear, quad, cubic, sine, expo, back, elastic, bounce × in/out/inOut; f(0)=0,
f(1)=1), `Tween` (repeat count or forever, autoreverse) and `Timeline` (play, pause, seek, reverse via negative
`rate`, completion events once per pass, `reduceMotion` jumps to end values and disables repeats).

**Scenes and particles**: `SceneNode` (TRS transform, z-order, visibility, primitive rect/circle/line/polygon
≤ 256 points, hit testing); `ParticleSystem` (capacity 10,000 default, ≤ 100,000; `Emitter`s with rate, burst, lifetime, speed, direction/spread,
size and color over life; `ParticleForce` gravity/drag/attractor; NaN removal, `checksum()`; `instances()` →
`ParticleInstance` for `ParticleRenderer`); 3D: `OrbitCamera` (pitch ±89°, `project`, `ray`), `Mesh.plane/cube/uvSphere`
(segments 3–256, rings 2–256, subdivisions ≤ 256).

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
