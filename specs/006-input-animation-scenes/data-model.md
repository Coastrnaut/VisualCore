# Data model: Phase 5

## VisualCoreMath
- **Vec2 / Vec3 / Vec4** (Double; Float conversions for GL), **Mat3** (2D affine), **Mat4** (column-major), **Quat** (unit; slerp).
- **Camera2D**: `center: Vec2`, `zoom` ∈ [0.1, 100] (clamped), `rotation` (radians); `viewMatrix`, `inverse`.
- **OrbitCamera**: `target`, `distance` > 0, `yaw`, `pitch` ∈ [−89°, 89°], `fovY` ∈ (0, π), `near`/`far`; `view`, `projection(aspect:)`, `project(_:aspect:)`, `ray(ndc:aspect:)`.
- **Easing**: enum curve × mode (in/out/inOut); `value(t)` with f(0)=0, f(1)=1.

## VisualCoreSimulation
- **FixedStepClock**: `step` (default 1/120), `maxSteps` (8), accumulator, `alpha` ∈ [0,1), `droppedTime`, `totalSteps`; `advance(by:) -> Int`.
- **SeededRandom**: xoshiro256** state (4×UInt64) from SplitMix64(seed); `next() -> UInt64`, `double()` [0,1), `float()`, `range(_:)`, `normal()`.
- **Tween**: from, to, duration ≥ 0, easing, repeat (count or forever), autoreverse; `value(at:)`.
- **Timeline**: tweens with offsets; `time`, `rate` (±), `isPaused`, `reduceMotion`; `advance(by:)`, `seek(to:)`, completion events (each fired once per pass).
- **ParticlePool**: capacity (default 10,000, max 100,000), SoA arrays (position, velocity, age, life, size, color), `aliveCount`, `droppedCount`, `nanRemoved`.
- **Emitter**: position, rate/s, burst, lifetime range, speed range, direction + spread, size/color over life; **Force**: gravity(Vec2), drag(k), attractor(point, strength, radius).
- State transitions: particle alive → (age ≥ life | NaN) → removed (swap-remove).

## VisualCoreScenes
- **ViewMetrics**: `size` (points), `scale` > 0; conversions points⇄pixels⇄NDC⇄world (optional result when size is zero).
- **PointerEvent**: `id`, `phase` (began/moved/ended/cancelled), `location` (points), `timestamp`.
- **PointerTracker**: ≤ 10 active pointers; extra ignored (counted).
- **Gesture recognizers**: Tap, DoubleTap, LongPress, Drag, Pinch, Rotate; state possible → began → changed → ended | cancelled | failed (discrete gestures: possible → recognized | failed); values translation, scale, angle, location; thresholds per clarification.
- **SceneNode**: id, transform (position, rotation, scale), z, visible, primitive?, children; `worldTransform`, `hitTest(point)` (topmost visible by z, then order).
- **Primitive**: rect(size), circle(radius), line(from, to, width), polygon(points ≤ 256); fill color RGBA.
- **Mesh**: positions, normals, uvs, UInt32 indices; generators plane(n), cube, uvSphere(segments 3–256, rings 2–256).
