# Research: Phase 5

- **R1 Coordinate spaces** — Decision: view points (origin top-left, y down) → pixels (× scale) → NDC
  (x right, y up, −1…1) → world through `Camera2D` (inverse of translate·rotate·scale). Rationale: matches
  UIKit input and GL output; one 3×3 affine per direction keeps round trips exact to ~1e-12 in Double.
  Alternatives: Float math (fails 0.001-pt round trip at large zoom), CGAffineTransform (UIKit, violates R2).
- **R2 Gesture recognition** — Decision: pure state machines fed by `PointerEvent`s with timestamps
  (no timers; long-press is evaluated on events and on `tick(now:)`). Rationale: host-testable,
  deterministic. Alternatives: UIGestureRecognizer (not host-testable), SwiftUI gestures (apps may still use).
- **R3 Fixed step** — Decision: accumulator clock ("Fix Your Timestep", Fiedler) with step 1/120 s, max 8
  steps, drop and count excess, alpha = accumulator/step. Invalid/negative deltas = 0.
- **R4 RNG** — Decision: xoshiro256** (Blackman & Vigna, public domain) seeded via SplitMix64; integer
  core so sequences are identical everywhere; golden test for seed 42. Alternatives: `SystemRandomNumberGenerator`
  (not seedable), LCG (poor quality), PCG32 (fine, but xoshiro256** is 64-bit native).
- **R5 Easing** — Decision: Penner-style curves (quad, cubic, sine, expo, back, elastic, bounce) with
  exact endpoints enforced (`t<=0→0`, `t>=1→1`). Timelines: list of tweens with start offsets; seek is
  pure (state = f(time)), so reverse/pause are trivial and deterministic.
- **R6 Particles** — Decision: structure-of-arrays pool with swap-remove, fixed capacity, emission
  accumulator for fractional rates; semi-implicit Euler; forces gravity/drag/attractor; NaN/inf guard
  removes and counts. Rationale: cache-friendly, bounded memory, deterministic order.
- **R7 GL drawing** — Decision: primitives as a CPU-built triangle batch (circles tessellated by radius,
  ≤ 128 segments) in one dynamic VBO; particles as instanced quads (`glDrawArraysInstanced`, per-instance
  position/size/color buffer, `gl_VertexID` corners); meshes as VBO+IBO with a simple Lambert program.
  All buffers from `ResourceRegistry` with byte accounting; premultiplied-alpha blending.
- **R8 3D scope** — Decision: cameras, quaternions and plane/cube/UV-sphere generators only, justified by
  manuals 14 (Solar System), 15 (Molecular), 17 (Anatomy), 12 (Tiny Worlds), 24 (Benchmark). No scene
  graph in 3D, no materials beyond Lambert, no model loading (apps add their own).
- **R9 Demo harness** — Decision: `Harnesses/InteractiveDemo` XcodeGen app with a SwiftUI shell hosting
  `RenderView`, a diagnostics `Text` with accessibility identifier `demo.diagnostics`
  (`particles=N zoom=Z state=S`), unsigned simulator build, XCUITest drag/pinch/background.
- **R10 Determinism scope** — Decision: bit-identical per platform/architecture (same binary); cross-arch
  float identity not promised; frame-rate independence proven by checksums at 60/120 Hz.
