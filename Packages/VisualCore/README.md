# VisualCore (pure modules)

Host-testable Swift modules with no GPU and no UIKit. They run on macOS for `swift test` and on
iOS 26+ inside apps. The package map and dependency rules R1–R5 are in
[`specs/002-architecture-contracts/contracts/package-map.md`](../../specs/002-architecture-contracts/contracts/package-map.md).

| Product | Purpose |
|---|---|
| VisualCoreMath | vectors, matrices, quaternions, cameras, double-precision plane viewports (PlaneViewport) and size-independent framings (PlaneFraming), log-scale framing flights and tour timelines (FramingFlight, TourTimeline), precision advice (PrecisionAdvisor), easing, camera rails with comfort limits (CameraRail, RailPose, ComfortLimits, RailFlight) origin rebasing for long journeys (OriginRebase) and anchored-label layout (AnchoredLabelLayout) |
| VisualCoreSimulation | fixed-step clock, seeded RNG, timelines, particle pool, NaN guard, CPU field grids, storage precision, time-step policy, bounded steering and neighbour search, 2D overlap and swept collision tests |
| VisualCoreScenes | input mapping, pointer tracking and velocity, seeded synthetic gesture scripts, mesh generators, export geometry, streaming piece windows (SegmentWindow), fixed-size slot pools (SlotPool) and per-quality-level streaming budgets (StreamingBudget, StreamingLevel); feature 062 (A08-P02): `Primitive.polyline` (a bounded multi-point line of up to 8,192 finite points with a width) |
| VisualCoreShaderSource | shader library, includes, line maps, diagnostics parsing |
| VisualCoreEffectsGraph | effect DAG model, validation, quotas, flash-limiter model |
| VisualCoreDiagnostics | render lifecycle state machine, frame statistics, reports, relative render-cost estimates (RenderCostEstimate); `TessellationChoice` — segments from a quality tier's share, monotonic, optionally fitted to a mesh budget (feature 044, A05-P05) |
| VisualCoreAudioDSP | feature 047 (A06-P01): `SampleRingBuffer` (single-producer/single-consumer, atomic positions, never blocks or allocates while writing, drops the oldest on overflow), `DemoSignal` (seeded pentatonic melody, 440 Hz and 1 kHz tones, silence), `SpectrumAnalyzer` (Hann-windowed vDSP FFT, 256–4,096 points, magnitudes in dBFS, peak bin); feature 048 (A06-P02): `LevelMeter` (RMS, peak, dBFS with a −120 floor), `BandLayout` (log bands over the bins), `SpectrumWorkspace` + `powerSpectrum` (allocation-free), `FeatureSmoother` (attack/release in seconds), `OnsetDetector` (adaptive spectral-flux threshold), `AudioFeatures` and `FeatureExtractor` (one window per update, buffers allocated once); feature 049 (A06-P03): `AudioFeatureKind` (level, peak, beat, four frequency regions, normalised 0…1), `AudioMapping` (feature, gain, attack, release, clamp; versioned and validated) and `AudioMapper` (maps features into a parameter range); feature 051 (A06-P05): `AnalysisQuality` (window size and band count per quality level 0…2); feature 061 (A08-P01): `TestSignal` (deterministic sine, naive square and logarithmic sweep, optional second channel with frequency ratio and phase), `StereoSampleBuffer` (interleaved two-channel single-writer buffer with reads by absolute frame that refuse overwritten or unwritten ranges), `ScopeTrigger` with `TriggerSettings` (level, rising/falling slope, hysteresis, auto/normal) and `TimebaseWindow` (time per division × 10 divisions → samples, capped at 4,096); feature 062 (A08-P02): `MinMaxDecimator` with `ColumnRange` (per-column minimum and maximum of a window, at most 8,192 columns, identity when the window fits, non-finite samples skipped); feature 077 (A10-P03): `SoundEffect` (sine/triangle/square, exponential 40–4,000 Hz sweep, 0.02–1 s, linear attack and release ≥ 2 ms, deterministic noise, gain ≤ 0.9) and `SoundEffectSynth.render` (deterministic, finite, clamped to the gain, silent first and last sample; invalid effects give no samples); feature 155 (A21-P04): `AmbientLoopRecipe` with `AmbientLoopPartial` (4–16 whole seconds at 48 kHz, 1–6 sine partials of whole cycles per loop and amplitude 0…1, a slow swell of whole cycles per loop, gain ≤ 0.3, `gentle` default) and `AmbientLoopSynth.render` (deterministic, finite, normalised to the gain, seamless at the wrap; invalid recipes give no samples) |
| VisualCorePersistence | `DocumentStore` (versioned envelopes, atomic writes, migrations, per-file problem reports), A01-P03; app-owned temporary folders (TemporaryFolder); named, favoritable document libraries (NamedLibrary), A03-P03 |
| VisualCoreParameters | parameter schemas (units, ranges, linear/log sliders), resolution, palettes (sRGB, linear-light sampling), presets, stable `ParameterHash` |
| VisualCoreExperience | experience identity (`ExperienceID`, `ExperienceCode`), descriptors, tiers and categories, the validated runtime catalog (`CatalogManifest`: bounded loading with typed errors, launch allocation, search, registry check), UA-F01; the pure part of the experience contract (`ExperienceCore`, `ExperienceEngine`, `ExperienceLifecycle`, `StateDigest`, `ExperienceSnapshot`, `ExperienceDiagnostics`, `ExperienceConformance`), UA-F02; controls carry at most `ExperienceControl.maxValues` = 24 values per action (8 until feature 043, A05-P04, raised so one action can restore a saved document); feature 131 (A18-P01): the wall-clock source (`ClockSource`, `SystemClock` — `Date()` with no offset, `FixedClock` for tests and replays with `set` and `advance(by:)`) and `TimeChangeMonitor` (maps notification names to `TimeChangeKind` — foreground, significantTime, timeZone, locale, calendarDay — over an injected `NotificationCenter`, one handler call per notification; `foundationNames` holds the time-zone, locale and calendar-day names) |
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

**Bounded steering** (`VisualCoreSimulation`, feature 069): `NeighbourSearch.neighbours(of:in:radius:limit:)` returns at
most `limit` indices of `SteeringAgent`s within `radius`, nearest first with ties broken by index, never the agent itself
(a linear scan, meant for a few dozen agents). `Steering.force(for:agents:neighbours:parameters:bounds:)` adds weighted
separation (all neighbours inside `separationRadius`; coincident agents part along ±x by index), alignment and cohesion
(only neighbours of the same `group`) and an inward boundary push inside `boundaryMargin` of valid `SteeringBounds`;
each term and the sum are capped to `maxForce`, and non-finite input gives zero force. Deterministic, no randomness;
host tests `SteeringForceTests` and `NeighbourSearchTests`.

**2D collision** (`VisualCoreSimulation`, feature 075): `CollisionCircle` and `CollisionCapsule` (a segment with a
radius) are plain values; `Collision2D.overlaps` answers circle–circle and circle–capsule overlap with touching counting
(tolerance 1e-9), `Collision2D.closestPoint(on:to:)` gives the nearest point of a capsule's segment, and
`Collision2D.sweep(_:moving:_:moving:)` returns the earliest fraction 0…1 of one step at which two linearly moving
circles first touch (0 when already touching, nil for no contact), so a fast object cannot pass through another
between steps. Non-finite input or a negative radius gives no hit. Pure and deterministic; host tests
`Collision2DTests`.

**2D rigid-body contacts and impulse solver** (`VisualCoreSimulation`, feature 082): `Shape2D` is a circle (radius)
or a box (half-extents) with its `area` and `inertia(mass:)`; `Pose2D` places it (position, angle) and maps points
with `toWorld` and `toLocal`. `Contacts2D.collide(_:_:_:_:)` returns a `ContactManifold2D` for circle–circle,
circle–box and box–box — a unit normal from the first shape to the second, a depth ≥ 0 and one or two world points
(boxes by the separating-axis test with reference-face clipping) — with touching counting (tolerance 1e-9) and nil
for separated shapes, non-finite poses or non-positive sizes. `ImpulseSolver2D.solve(_:contacts:settings:)` resolves
`Contact2D`s between `RigidBodyState2D`s (inverse mass and inertia, restitution, friction) by sequential impulses:
a fixed number of velocity iterations (default 10) with restitution max(eA, eB) above a 0.5 m/s closing speed and
Coulomb friction √(μA·μB), then a positional correction of 80 % of the depth beyond a 0.005 slop. Inverse mass 0 is
static and never changes; nothing non-finite is written. Pure and deterministic; host tests `Contacts2DTests` and
`ImpulseSolver2DTests`.

**Springs, broad phase and warm starting** (`VisualCoreSimulation`, feature 083): a `Spring2D` joins two
`SpringAnchor2D`s (a body index with a body-local point, or a fixed world point) with a rest length, stiffness and
damping ratio; `Springs2D.apply(_:springs:dt:)` applies its force as impulses at the anchors, with stiffness clamped to
`stableStiffness` (0.1·m/dt²) and damping to `stableDamping` (m/dt) for the ends' effective mass, so a spring can never
make the step unstable; a zero-length or static–static spring does nothing. `Shape2D.bounds(at:)` gives an `AABB2D`, and
`BroadPhase2D.pairs(_:)` sweeps and prunes along x to return exactly the overlapping pairs (inclusive within 1e-9) as
sorted `BroadPhasePair2D`s, the same as testing every pair. `Contact2D` can carry the previous tick's normal and tangent
impulses; `ImpulseSolver2D.solve(_:contacts: inout ...)` starts from them (warm starting) and writes the new ones back,
which keeps resting stacks standing; with nothing stored it gives exactly the earlier results. Host tests
`Springs2DTests`, `BroadPhase2DTests` and `ImpulseSolver2DTests`.

**Seeded noise and height-field terrain** (`VisualCoreScenes`, feature 089): `GradientNoise2D(seed:)` gives 2D
gradient noise in −1…1 (lattice corners hashed with the SplitMix64 finalizer, eight gradient directions, quintic fade;
only +, −, × and floor, so values are bit-identical on every device; non-finite input gives 0). `FractalNoise2D` sums
1…8 octaves (lacunarity 1…4, gain 0…1, frequency > 0; invalid settings give nil) normalised to −1…1. `HeightField`
samples a height function on a grid of 1…512 columns and rows at a cell size from an origin in the x–z plane (y up),
keeping one ring beyond the grid so its normals come from the field itself: two pieces that share an edge from one
function get bit-identical edge heights and normals (for cell sizes exact in binary). It offers grid heights, a
bilinear sampler clamped to the grid, normals, and `mesh(budget:)` (one vertex per grid point, two counter-clockwise
triangles per cell seen from +y, checked against the `MeshBudget` before building; non-finite input is refused with
`MeshError.invalidInput`). Used by Tiny Worlds (A12) for its preset terrains.

**Anchored-label layout** (`VisualCoreMath`, feature 127, A17-P04): `AnchoredLabelLayout.place(_:camera:aspect:canvas:budget:)`
places text-label boxes (`Candidate`: id, model-space anchor, size in points, priority) on a canvas overlay (points,
origin top-left, y down) and returns `Placement`s (id, projected anchor, box). Candidates are taken by priority, then
id; an anchor behind the camera or outside clip depth is culled (`canvasPoint(of:camera:aspect:canvas:)` gives nil);
the box sits `offset` = 6 points right of and above the projected anchor (minX = x + 6, maxY = y − 6); a box not wholly
inside the canvas, or overlapping an already placed box by a positive area (`overlaps`; touching edges do not
overlap), is skipped; at most `budget` boxes are placed, and non-finite anchors or sizes are skipped. Deterministic and
independent of input order. The generic form of the Solar System Explorer (A14) and Molecular Explorer (A15) label
layouts; used by Interactive Anatomy (A17).

**Ray intersection** (`VisualCoreMath`, feature 090): `Ray3(origin:direction:)` (nil for non-finite values or a zero
direction; the direction is normalised) intersects an axis-aligned box (slab method), a sphere and a triangle
(two-sided Möller–Trumbore) and returns the nearest `RayHit3` at distance ≥ 0 with a unit normal facing against the
ray; a start inside a box or sphere hits at distance 0 with the normal −direction, a tangent ray hits once, and a ray
parallel to a triangle, a degenerate triangle or an invalid shape gives nil (tolerance 1e-12); `Ray3.nearest` picks
the closest of several hits. With `OrbitCamera.ray(ndc:aspect:)` it gives picking. **2D ray casting and reflection**
(`VisualCoreMath`, feature 096): `Ray2(origin:direction:)` (nil for non-finite values or a zero direction; the direction
is normalised) casts against an array of `Segment2` with `cast(against:excluding:minimumDistance:)` and returns the
nearest `RayHit2` (distance above the minimum, default 1e-9; point; segment index; unit normal facing against the ray);
parallel and collinear segments miss (tolerance 1e-12), end points count, segments with non-finite or coincident end
points are skipped, equal distances go to the lower index, and `excluding` ignores the segment just left so a reflected
ray never hits its own surface at distance 0. `Vec2.reflected(about:)` mirrors a direction about a normal
(`d − 2(d·n)n`, the normal normalised first; a zero or non-finite normal leaves it unchanged), keeping its length and
making the angle of incidence equal the angle of reflection. Used by Light Maze (A13). **Per-vertex colours**
(`VisualCoreRendering`, feature 090): `MeshRenderer(mesh:colors:registry:)` takes one RGBA (0…1) per vertex,
multiplied into the draw colour before lighting (also through `DepthMeshPass`); without colours the attribute is a
constant 1, so existing pixels are unchanged; a wrong count or a value that is non-finite or outside 0…1 is refused
with `MeshError.invalidInput`; the stream is rebuilt after a context recreation. Used by Tiny Worlds (A12).
**Kepler orbits** (`VisualCoreMath`, feature 104): `KeplerOrbit(semiMajorAxis:eccentricity:inclination:ascendingNode:
argumentOfPeriapsis:meanAnomalyAtEpoch:meanMotion:)` (radians and radians per time unit; nil for a non-finite value,
e outside 0 ≤ e < 1, or a non-positive axis or mean motion) propagates an elliptical two-body orbit approximately:
`meanAnomaly(at:)` is M₀ + n·t normalised to (−π, π]; `eccentricAnomaly(meanAnomaly:eccentricity:)` solves Kepler's
equation by Newton's method from E₀ = M (e < 0.8) or π, at most 32 steps, stopping below 1e-12 rad (residual below
1e-10 for e up to 0.95); `position(at:)` returns the position in the reference frame (x toward the reference
direction, z toward the plane's north) after rotating by ω, i and Ω, in the axis's unit, always finite (a non-finite
time is the epoch); `period` is 2π/n. No secular rates or perturbations. Used by Solar System Explorer (A14).

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
`ParticleInstance` for `ParticleRenderer`); 3D: `OrbitCamera` (pitch ±89°, `project`, `ray`), symmetry (feature 040, A05-P01: `PointGroup` cyclic and
dihedral of order 1–24 and `WallpaperLattice` square p4m and hexagonal p6m, each with `images` in a fixed order and an
idempotent `fold` into the fundamental region), camera bounds (feature 041, A05-P02: `ViewBounds2D` clamps a `Camera2D`'s
zoom and centre, `Camera2D.panned(by:within:)` and `zoomed(by:within:)`; `OrbitBounds` clamps an `OrbitCamera`'s pitch and
distance and wraps yaw, `OrbitCamera.orbited(yaw:pitch:within:)` and `zoomed(by:within:)`; non-finite or non-positive
inputs leave the camera unchanged), mesh cache (feature 044, A05-P05: `MeshCache`, least-recently-used by a use counter,
limits of 16 entries and 32 MiB by default, hit/miss/eviction counts; `Mesh.byteSize`), orbit view bounds (feature 042, A05-P03: `OrbitViewBounds` adds a target radius, a
field-of-view range and the bounding-sphere rule — minimum distance = max(lower bound, |target| + clearance + 2 · near);
`OrbitCamera.forward/right/up`, `panned(by:within:)` in view space, `withFieldOfView(_:within:)`), `Mesh.plane/cube/uvSphere`
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

## Shader expansion, variants, precision and uniform layouts (feature 206, R02-F06)

VisualCoreShaderSource expands shader text safely: `ShaderLibrary` pastes each included file once and refuses cycles,
depth above 8 and more than 64 KiB (counted in bytes); `DefineSet` validates defines; `ShaderVariantSet` declares a
shader's switches (at most 64 combinations, stable order and keys); `PrecisionPolicy` gives a fragment shader without
a float precision statement `highp` or `mediump` from the device report and flags `highp` where it is missing;
`UniformLayout` declares uniforms and checks them against a program's active ones; `ShaderReasonCode` and
`ShaderFailureReport` name every refusal. Rules: [docs/architecture/shaders.md](../../docs/architecture/shaders.md).

## Emissive reference and pass schema (feature 207, R02-F07)

VisualCoreEffectsGraph declares the `emissive` pass (threshold, knee, intensity, radius, quality, exposure, tonemap)
and holds its CPU reference, `EmissiveReference` (sRGB transfer, luminance, soft-knee prefilter, tone maps,
composite, premultiplied over); `composite` mode 2 is premultiplied over; the validator refuses non-finite parameters
and out-of-range emissive ones. `RenderState.premultipliedBlended` draws premultiplied layers. Rules:
[docs/architecture/shaders.md](../../docs/architecture/shaders.md).

## Puzzle contract (feature 223, R02-F23)

VisualCoreSimulation certifies puzzle levels: `PuzzleRules` (the pure rules an experience supplies), `PuzzleLevel`
(immutable, with a content-derived `StableHash` identity; JSON schema 1, edited forms refused), `PuzzleUniqueness`,
`FairnessBudget`, `PuzzleValidator` with `PuzzleCertificate` and `PuzzleVerdict` (replay, length bounds, bounded
breadth-first proof of branching, shortest length and uniqueness) and `PuzzleGenerator` with `PuzzleGeneration`
(seeded attempts that hand out only certified levels). Refusals are `PuzzleError` with `r2-f23.*` codes. Rules:
[docs/architecture/puzzle-contract.md](../../docs/architecture/puzzle-contract.md).

## Spatial controls (feature 222, R02-F22)

VisualCoreMath adds `Plane3`, `Ray3.intersect(plane:)` and `ScreenProjection` (screen point to world ray and back for any
camera). VisualCoreScenes adds `SpatialHandle` and `HandleKind` with `HandlePicker` (depth-aware picking within a 44-point
target), `DragConstraint` and `HandleDrag` (exact, grazing-safe drags along an axis or across a plane), `ControlHistory`
(bounded, coalescing undo and redo of any `Codable` value; schema 1) and `AssistiveStep` (exact discrete steps with a
spoken value). Refusals are `SpatialControlError` with `r2-f22.*` codes. Rules:
[docs/architecture/spatial-controls.md](../../docs/architecture/spatial-controls.md).

## Nutrient fields (feature 221, R02-F21)

VisualCoreSimulation spreads nutrients exactly: `NutrientField` (walled grid, 1 … 4 channels of integer quanta, stable
explicit diffusion in bounded sub-steps, decay), `NutrientSource` (sources and sinks with exact long-run rates),
`ViabilityBand` (where life thrives), `GrowthNetwork` (deterministic bounded growth into viable cells, handed on as a
`RouteGraph`), `NutrientLedger` and `NutrientAccount` (exact conservation) and `NutrientStepReport` (what a frame did);
`Codable` schema 1; fields and viability as `FieldGrid`s. Refusals are `NutrientError` with `r2-f21.*` codes. Rules:
[docs/architecture/nutrient-fields.md](../../docs/architecture/nutrient-fields.md).

## Bounded swarms (feature 220, R02-F20)

VisualCoreSimulation steps swarms on top of the unchanged steering: `NeighbourGrid` (hashed integer cells; exactly the
lists of `NeighbourSearch`), `MagneticField` and `MagneticPole` (an exact uniform-field turn and softened, bounded pole
forces), `Swarm` with `SwarmEdges` (fixed steps with a speed limit, walled or wrapping bounds, parallel charges; `Codable`
schema 1) and `DensityRaster` (bilinear splatting whose total is the in-area count, handed on as a `FieldGrid`).
Refusals are `SwarmError` with `r2-f20.*` codes. Rules: [docs/architecture/swarms.md](../../docs/architecture/swarms.md).

## Grammar-grown vegetation (feature 219, R02-F19)

VisualCoreScenes grows plants from code: `PlantGrammar` (start word, weighted rules, generations, turtle settings, seed;
`Codable` schema 1), `LSystem.derive` (seeded rewriting), `PlantTurtle.interpret` and `grow` (bracketed turtle to
`PlantBranch`es and petal, cap and leaf `PlantMarker`s), `PetalShape`, `CapShape` and `StemShape` (parametric part
meshes), `PlantMesh.build` (branches through `Mesh.tube`, parts at markers, merged) and `PlantScatter.scatter`
(seeded dart throwing with a minimum spacing into `PlantInstance`s with model matrices for instanced drawing).
Refusals are `PlantError` with `r2-f19.*` codes. Rules: [docs/architecture/vegetation.md](../../docs/architecture/vegetation.md).

## Terrain levels of detail, masks and sky (feature 218, R02-F18)

VisualCoreScenes splits a large terrain into pieces: `TerrainSettings` (P × P pieces of C × C cells, L levels, a
distance per level, a vertex budget; `Codable` schema 1) and `TerrainLOD.select` (levels by distance, neighbours within
one level, farthest pieces coarsened first to fit the budget) choose `TerrainPiece`s, and `TerrainLOD.mesh(for:height:)`
samples each through `HeightField` with crack-free edges towards coarser neighbours. `ErosionMask.masks(of:)` gives
steepness, D8 flow and wear as a `FieldGrid`. `SkyParameters` and `SkyModel.colour` are the CPU reference of the analytic
sky drawn by `vc/sky.glsl` and `SkyRenderer` in VisualCoreRendering. Refusals are `TerrainError` and `SkyError` with
`r2-f18.*` codes. Rules: [docs/architecture/terrain-and-sky.md](../../docs/architecture/terrain-and-sky.md).

## Heightfield transport (feature 217, R02-F17)

VisualCoreSimulation moves water, dye and rock over terrain without gaining or losing a quantum: `Heightfield` keeps
every amount as `Int64` quanta (65,536 per height unit) and steps the virtual-pipe shallow-water law in bounded
sub-steps (stability limit, at most 64 per frame, dropped time in a `HeightfieldStepReport`); dye and sediment travel in
proportion to the water, open borders drain into a `HeightfieldLedger`, and optional erosion exchanges rock and
sediment within cells. `fieldGrid()` and `dyeField()` hand the heights to the existing field passes; the state is
`Codable` (schema 1). Refusals are `HeightfieldError` with `r2-f17.*` codes. Rules: [docs/architecture/heightfield-transport.md](../../docs/architecture/heightfield-transport.md).

## Route solvers (feature 216, R02-F16)

VisualCoreSimulation solves and proves routing puzzles with integer costs: `RouteGraph` (directed, costs 0…1,000,000)
and `GridGraph` (four or eight neighbours, no corner cutting); `RouteSearch.breadthFirst` and `.bestFirst` (ties by
(g + h, h, node id), a budget, "gave up" never "unreachable"); `TimeExpandedGraph.earliestArrival` over a
`RouteSchedule`; `MinimumCut.between` with edge-disjoint routes; `SubgraphMatcher` placements and isomorphism. Every
answer carries a `SolverCertificate` (JSON schema 1) that `CertificateChecker` verifies without the solvers.
Refusals are `RouteError` with `r2-f16.*` codes. Rules: [docs/architecture/route-solvers.md](../../docs/architecture/route-solvers.md).

## Conic orbits and eclipses (feature 215, R02-F15)

VisualCoreMath moves bodies on two-body conics and decides eclipses: `KeplerSolver` solves the elliptic (reusing
`KeplerOrbit.eccentricAnomaly`), hyperbolic and parabolic (Barker) forms of Kepler's equation, always finite;
`ConicOrbit` (periapsis distance, eccentricity, orientation, time of periapsis, μ; `Codable` schema 1) gives an
`OrbitState` (position, velocity, true anomaly) and equals `KeplerOrbit` for e < 1; `PhaseStepper` keeps drift-free
time t₀ + k·Δt (ticks 0…1,000,000,000) with phases and periapsis/apoapsis `Passage`s in half-open spans;
`DiskOverlap` gives the exact lens area; `EclipseGeometry.classify` returns an `EclipseVerdict` (angular radii,
separation, covered fraction) with an `EclipseClass` (none, partial, annular, total, hidden).
Refusals are `OrbitError` with `r2-f15.*` codes. Rules: [docs/architecture/conic-orbits.md](../../docs/architecture/conic-orbits.md).

## Reversible timeline (feature 214, R02-F14)

VisualCoreSimulation scrubs any deterministic `FixedStepSimulation` value type: `EventLog` holds commands by step
(steps 0…10,000,000, at most 1,048,576 commands, applied in insertion order just before their step advances);
`SnapshotRing` keeps (step, state, hash) every `interval` steps (default 64, at most 32 kept); `ReplayHash` chains
SHA-256 over every step's checksum; `ReversibleTimeline` seeks back by restoring the latest kept snapshot and replaying,
recomputes after `insert`/`remove`/`replace` edits, and refuses a non-deterministic simulation (`hashMismatch`).
VisualCoreExperience stores a run as `TimelineRunDocument` (schema 1, migrated from schema 0, verified by replay).
Refusals are `TimelineError` with `r2-f14.*` codes. Rules: [docs/architecture/reversible-timeline.md](../../docs/architecture/reversible-timeline.md).

## Shadows and silhouettes (feature 213, R02-F13)

VisualCoreScenes decides shadow puzzles on the CPU: `ShadowProjector` projects points, triangles, meshes and convex
solids onto a `ProjectionPlane` (a `ClipPlane` with a fixed u, v basis) from a point or directional `ShadowLight`,
clipped to the slab where shadows are cast, and gives the same projection as a matrix; `ConvexHull2D` gives a solid's
outline; `CoverageMask` rasterises polygons by cell centres (1…2,048 cells a side, half-open edges, packed bits, digest,
`CoverageMaskDocument` schema 1); `MaskComparison` gives intersection, union and IoU. Refusals are `ShadowError` with
`r2-f13.*` codes. Rules: [docs/architecture/shadow-silhouettes.md](../../docs/architecture/shadow-silhouettes.md).

## Convex solids and cuts (feature 212, R02-F12)

VisualCoreScenes: `ConvexSolid` holds vertices and outward convex polygon faces (at most 4,096 vertices, 1,024 faces,
256 corners per face), made from a box, from `ClipPlane`s bounded by a box, or from a closed convex `Mesh`;
`cut(by:)` returns the kept and removed parts, the cap and both volumes under a tolerance of 1e-9 × the bounding
diagonal, with no sliver, repeated or zero-area face; `VolumeLedger` records every cut and keeps original = remaining +
Σ removed within 1e-9; `PolygonCleanup` removes repeated and collinear points and orients a polygon; `ConvexSolidDocument`
stores a solid and its ledger (schema 1); `mesh()` gives a `Mesh` that validates closed. Refusals are
`ConvexSolidError` with `r2-f12.*` codes. Rules: [docs/architecture/convex-cutting.md](../../docs/architecture/convex-cutting.md).

## Signed-distance shapes (feature 211, R02-F11)

VisualCoreScenes: `SDFShape` describes a shape from planes, spheres, boxes, rounded boxes, capsules and tori with
union, intersection, subtraction, smooth union, translation, rotation and uniform scale (validating makers, at most 256
nodes and depth 32, refusals as `SDFError` with `r2-f11.*` codes); it gives the signed distance, the normal and
containment on the CPU — the proxy that decides outcomes — and `glslFunction(name:)` emits the same description for
the shader. `SDFMarch` sphere-traces a `Ray3` (conservative or fast, neither skips a surface), `SDFVolume` samples an
n³ grid with a replayable digest, `SDFDocument` stores a description (schema 1). Rules:
[docs/architecture/sdf-proxies.md](../../docs/architecture/sdf-proxies.md).

## Colour accessibility (feature 210, R02-F10)

VisualCoreParameters: `PerceptualColor` (sRGB ↔ linear ↔ OKLab ↔ OKLCh, relative luminance, WCAG `contrastRatio`, ΔE_OK
`difference`, `rotateHue` keeping lightness with a 24-step chroma bisection back into gamut, `outline(for:on:)`),
`ColorVisionCondition` (Machado 2009 protanopia, deuteranopia, tritanopia; achromatopsia), `PaletteSeparation` (pairs
closer than ΔE_OK 0.08 under any condition), `ColorVisionPresets` (three original six-colour palettes that pass it), and
coded states with a non-colour clue: `ClueShape` × `CluePattern` (8 × 4), `CodedState`, `CodedStateSet` (refusals with
`ColorAccessError` and `r2-f10.*` reason codes) and the CPU drawing reference `ClueReference`. VisualCoreSimulation:
`ColorVisionChoice` and `AccessibilityPreferences.colorVision` (older data decodes as `standard`). Rules:
[docs/architecture/color-accessibility.md](../../docs/architecture/color-accessibility.md).

## Instance order and beam profile (feature 209, R02-F09)

`InstanceOrder.backToFront(depths:)` (VisualCoreScenes) orders translucent instances by view-space z, farthest first,
ties in submission order, and refuses a non-finite depth with `MeshError.invalidInput`. `BeamProfile` is the CPU
reference of a beam's cross-section: `falloff(r)` = exp(−4 r²) for r ≤ 1 and 0 beyond, `distanceToSegment` and
`coverage(point:a:b:width:)`; a beam whose ends coincide is a round point. `BeamRenderer` and `InstancedMeshRenderer`
in VisualCoreRendering use them.

## Curves, ribbons and tubes (feature 208, R02-F08)

VisualCoreScenes builds curves from code: `CubicBezierChain` and centripetal `CatmullRomSpline` (open or closed),
`CurveSampler.sample` (samples within a tolerance, dense where the curve bends, with arc length),
`CurveFrames.parallelTransport` (frames that do not twist, closing on loops, defined through cusps and reversals),
`Mesh.ribbon` and `Mesh.tube(samples:)` (texture coordinate along the curve in world units, continuous across closed
seams; tiled values above 1 are reported by the validator's 0…1 rule, which applies to atlased meshes) and
`Mesh.merged`, so the existing `MeshRenderer` draws many curves in one call.

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

## Camera rails and comfort (feature 054, A07-P01)

`CameraRail` (VisualCoreMath) is a closed centripetal Catmull–Rom loop through at least four control points, sampled
into an arc-length table so equal travelled distances are equal lengths; `pose(at:)` wraps the distance and returns a
level frame (right = direction × world up), so the horizon never tilts and the frame is identical at the wrap point.
Rails whose direction comes within 30° of vertical are refused. `orbitCamera(at:fovY:near:far:)` expresses a pose as an
`OrbitCamera`, so existing drawing passes can fly a rail. `ComfortLimits` caps speed, acceleration, turn rate, sway and
roll (`.standard`, `.reducedMotion`); `RailFlight` eases speed toward a target within the limits, caps a time step at
0.1 s and ignores invalid ones. `OriginRebase` snaps an origin to a 1,024-unit grid near the camera, so positions far
along a journey are drawn relative to it in single precision without losing accuracy.

## Clock source (feature 131, A18-P01)

`SystemClock.now` (VisualCoreExperience) is the only reader of the wall clock in production; tests and replays inject
`FixedClock`, and nothing adds an offset. `TimeChangeMonitor(center:names:handler:)` observes a `NotificationCenter`
and calls its handler once per posted notification, synchronously, with the notification's `TimeChangeKind`; `start()`
twice observes once, and `stop()` or deinitialization ends the observation. `foundationNames` covers the system time
zone, the current locale and the calendar day; `TimeChangeMonitor.applicationNames` (VisualCoreExperienceHost, UIKit)
adds `UIApplication.significantTimeChangeNotification` and `willEnterForegroundNotification`, so every kind is mapped
once. Contract: [clock.md](../../specs/131-ac-p01-clock-a11y/contracts/clock.md).

## Benchmark timing sources (feature 175, A24-P03)

The renderer's facts reach a presenter as `ResourceRegistry.renderCapabilities`, and GPU frame times come only from
`GPUFrameTimer` (both in VisualCoreRendering) where `GL_EXT_disjoint_timer_query` is offered; without it no GPU time is
reported.

## Pictures as pass inputs (feature 183, A25-P04)

A picture decoded on the CPU becomes a pass input through `RenderTarget.upload(rgba:)` (VisualCoreRendering), one byte
per channel; the experience keeps the bytes to upload them again after a context loss.
