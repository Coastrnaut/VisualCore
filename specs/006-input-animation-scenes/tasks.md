---

description: "Task list for feature 006 — Phase 5 input, animation, scenes, particles (ledger gate F05)"
---

# Tasks: Phase 5 — Input, Animation, Scenes and Procedural Graphics

**Input**: `/specs/006-input-animation-scenes/` · **Tests**: required by the archived prompt (coordinate mapping,
animation timing, state transitions) and constitution IV; written first in each task. IDs `T-F5##`. One commit +
push per task. Each subsystem is implemented separately (supplied prompt). Paths are repo-relative.

## Phase 1: Setup

- [X] T-F501 Add test targets `VisualCoreMathTests`, `VisualCoreSimulationTests`, `VisualCoreScenesTests` to `Packages/VisualCore/Package.swift`; add `VisualCoreSimulation` and `VisualCoreScenes` dependencies to the `VisualCoreRendering` target in `Packages/VisualCoreRendering/Package.swift` and amend the `VisualCoreRendering` row of `specs/002-architecture-contracts/contracts/package-map.md` (owns primitive/particle/mesh drawing and the touch adapter) — Verified 2026-11-10: F05.t501-host/-deps/-generic-ios exit 0: 3 new test targets link and run; R1-R5 pass with Rendering→Simulation/Scenes; generic-iOS build succeeds; package map row amended

## Phase 2: Foundational — math (blocks every story)

- [X] T-F502 Tests + implementation of `Vec2/Vec3/Vec4`, `Mat3` (2D affine), `Mat4` (column-major), `Quat` (unit, slerp) in `Packages/VisualCore/Sources/VisualCoreMath/{Vectors,Matrix4,Quaternion}.swift`, tests `Packages/VisualCore/Tests/VisualCoreMathTests/LinearAlgebraTests.swift` (inverse·m = identity within 1e-12, quaternion rotation matches matrix) — Verified 2026-11-10: F05.t502-linear-algebra exit 0: 6 tests — Mat3/Mat4 inverse·m = identity within 1e-12 (1e-9 projection), quaternion rotation = matrix, slerp, column-major floats
- [X] T-F503 Tests + implementation of `Camera2D` (`zoom` clamped to "[0.1, 100]", `rotation` radians; matrix and inverse) in `VisualCoreMath/Camera2D.swift`, tests `VisualCoreMathTests/Camera2DTests.swift` — Verified 2026-11-10: F05.t503-camera2d exit 0: 5 tests — zoom clamp 0.1-100 and NaN, round trip ≤1e-9, AC2 center (10,0), pinch keeps anchor, pan follows finger

## Phase 3: US1 — Map touches into the scene (P1) 🎯 MVP

**Independent test**: host conversions through every space and back; gesture state sequences from scripted events.

- [X] T-F504 [US1] Tests first `Packages/VisualCore/Tests/VisualCoreScenesTests/CoordinateTests.swift` (AC1 390×844@3 → NDC 0,0 and pixel 585,1266; AC2 zoom 2 pan (10,0) → world (10,0); SC-F501 round trip ≤ 0.001 pt over scales 1/2/3 × aspects 9:19.5, 3:4, 1:1, 16:9 × camera transforms; zero size → nil; after a size change (rotation) conversions use the new size), then `ViewMetrics` in `VisualCoreScenes/ViewMetrics.swift` — Verified 2026-11-10: F05.t504-coordinates exit 0: 5 tests — AC1 NDC 0,0/pixel 585,1266; AC2 world (10,0) ≤0.001 pt back; SC-F501 144 combos (4 aspects × 3 scales × 4 points × 3 cameras) ≤0.001 pt; zero size nil; rotation uses new size
- [X] T-F505 [US1] Tests first `VisualCoreScenesTests/PointerTrackerTests.swift` (≤ 10 pointers, 11th ignored and counted, cancel removes), then `PointerTracker` + `PointerEvent` in `VisualCoreScenes/PointerTracker.swift` — Verified 2026-11-10: F05.t505-pointers-a3 exit 0: 4 tests — began/moved/ended, 11th touch ignored+counted and its end ignored, cancel removes, centroid, non-finite/duplicate rejected (a1/a2 = mutating calls inside #expect, kept)
- [X] T-F506 [US1] Tests first `VisualCoreScenesTests/GestureTests.swift` covering every transition of tap, double-tap, long-press, drag, pinch, rotate incl. cancel and fail (SC-F503), thresholds tap "≤ 10 pt and ≤ 0.3 s", double-tap "within 0.3 s and 30 pt", long-press "≥ 0.5 s within 10 pt", drag "after 10 pt", AC3 pinch 100→200 pt = 2.0, AC4 cancelled touch → cancelled, second finger cancels drag and fails pending tap; then `VisualCoreScenes/GestureRecognizers.swift` — Verified 2026-11-10: F05.t506-gestures-a2 exit 0: 14 gesture tests — tap/double-tap/long-press recognized, failed (distance, duration, timeout, second finger, late, far) and cancelled; drag began/changed/ended, failed, cancelled by second finger and system; AC3 pinch 100→200 = 2.0; pinch+rotate simultaneous 90° CCW; third finger ignored (a1 = wrong test expectation, kept)

## Phase 4: US2 — Deterministic animation and update timing (P1)

**Independent test**: host frame-time sequences, golden RNG, timeline sampling.

- [X] T-F507 [US2] Tests first `Packages/VisualCore/Tests/VisualCoreSimulationTests/FixedStepClockTests.swift` (AC1 120 steps from 60 × 1/60 s, alpha ∈ [0,1); AC2 2 s stall → 8 steps, dropped time counted; NaN/negative/inf delta → 0; 1e-9 s step-boundary tolerance; a clock+RNG replay of 10,000 frames is bit-identical twice), then `VisualCoreSimulation/FixedStepClock.swift` — Verified 2026-11-10: F05.t507-clock exit 0: 8 tests — AC1 120 steps at 60 Hz with alpha in [0,1), 144 Hz also 120; AC2 2 s stall → 8 steps, 232/120 s dropped; NaN/neg/inf → 0; 1e-9 tolerance; 10,000-frame clock+RNG replay bit-identical; 60 vs 120 Hz same state
- [X] T-F508 [US2] Tests first `VisualCoreSimulationTests/SeededRandomTests.swift` (golden first 8 outputs for seed 42 from the xoshiro256**/SplitMix64 reference, double ∈ [0,1), range bounds, normal mean/variance ±5% over 100k), then `VisualCoreSimulation/SeededRandom.swift` — Verified 2026-11-10: F05.t508-random-a2 exit 0: 6 tests — SplitMix64(0) = published 0xE220A8397B1DCDAF; seed-42 first 8 outputs match independent Python reference; double/float in [0,1); unbiased int ranges ±5%; normal mean/variance within 5% over 100k (a1 = rethrowing call inside #expect, kept)
- [X] T-F509 [US2] Tests first `VisualCoreMathTests/EasingTests.swift` (every curve × mode: f(0)=0, f(1)=1, inOut(0.5)=0.5 for symmetric curves), then `VisualCoreMath/Easing.swift` — Verified 2026-11-10: F05.t509-easing exit 0: 15 Math tests — all 8 curves × 3 modes: f(0)=0, f(1)=1, clamping, NaN→0, inOut(0.5)=0.5, out mirrors in; known values; back/elastic overshoot; monotone curves increase
- [X] T-F510 [US2] Tests first `VisualCoreSimulationTests/TimelineTests.swift` (AC4 samples 0/0.5/1, pause, resume, reverse (rate −1), seek, repeat count and forever, autoreverse, completion events fired once, zero duration jumps to end, `reduceMotion` jumps to end and disables repeats), then `VisualCoreSimulation/{Tween,Timeline}.swift` — Verified 2026-11-10: F05.t510-timeline exit 0: 6 tests (Tween and Timeline in VisualCoreSimulation/Timeline.swift) — AC4 samples 0/0.5/1; pause, resume, reverse, seek; repeats, autoreverse, forever; completion/returnedToStart/finished once per pass; zero duration; reduceMotion end values and no repeats

## Phase 5: US3 — Particles and 2D scene primitives (P2)

**Independent test**: host emission/pool/transform/hit tests; simulator pixel tests for drawing.

- [X] T-F511 [US3] Tests first `VisualCoreScenesTests/SceneGraphTests.swift` (AC3 parent 90° + child (1,0) → (0,1); z-order and visibility; hit test topmost; polygon clamped to "≤ 256 points"), then `VisualCoreScenes/SceneGraph.swift` (`SceneNode`, `Primitive`) — Verified 2026-11-10: F05.t511-scene-graph-a2 exit 0: 6 tests — AC3 child of 90° parent at (0,1); z then insertion draw order, hidden subtree skipped; topmost hit test incl. rotation/scale and line/polygon; polygon ≤256 points; sizes bounded; reparenting
- [X] T-F512 [US3] Tests first `VisualCoreSimulationTests/ParticleSystemTests.swift` (AC1 100/s × 1 s life → 99–101 alive after 2 s; AC2 capacity 10,000 never exceeded, dropped counted; capacity clamped to "≤ 100,000"; gravity/drag/attractor; NaN particle removed and counted; SC-F502 10,000-step checksum identical twice and at 60 vs 120 Hz feeding), then `VisualCoreSimulation/ParticleSystem.swift` — Verified 2026-11-10: F05.t512-particles exit 0: 7 tests — AC1 100/s × 1 s → 99-101 alive after 2 s; AC2 burst 12,345 into 10,000 → 2,345 dropped, capacity clamp 1-100,000; gravity/drag/attractor; NaN removed and counted; size/color over life; SC-F502 10,000-step checksum identical twice and at 60 vs 120 Hz
- [X] T-F513 [US3] Sim test first `Packages/VisualCoreRendering/Tests/VisualCoreRenderingTests/PrimitiveRendererTests.swift` (AC4 red circle r=8 center red, 12 px away background; rect and line pixels; camera zoom doubles size; recreation rebuilds; teardown leaks 0), then `VisualCoreRendering/PrimitiveRenderer.swift` (batched triangles, circle "≤ 128 segments") — Verified 2026-11-10: F05.t513-primitives-ios27 exit 0: 5 sim tests — AC4 red circle r=8 center red, 12 px away black; rect/line/concave polygon at expected pixels (notch empty); zoom 2 doubles size, premultiplied alpha 128±2; 12-128 segments; recreation rebuilds, leaked 0; 36 rendering + 17 effects pass
- [X] T-F514 [US3] Sim test first `VisualCoreRenderingTests/ParticleRendererTests.swift` (instances drawn at expected pixels with color; 10,000 instances draw without error; recreation and teardown), then `VisualCoreRendering/ParticleRenderer.swift` (instanced quads) — Verified 2026-11-10: F05.t514-particles-ios27-a2 exit 0: 4 sim tests — instances at expected pixels with color; 10,000 simulated instances drawn with GL_NO_ERROR; empty draw; zoom 2 placement; recreation rebuilds, leaked 0; 40 rendering tests pass (a1 = ParticleInstance init not public, fixed)

## Phase 6: US4 — Minimal 3D camera and meshes (P3)

- [X] T-F515 [US4] Tests first `VisualCoreMathTests/OrbitCameraTests.swift` (AC1 origin → NDC (0,0), center ray hits origin; pitch clamped ±89°; zoom keeps distance > 0), then `VisualCoreMath/OrbitCamera.swift` — Verified 2026-11-10: F05.t515-orbit-camera exit 0: 4 tests — AC1 target → NDC (0,0), center ray passes through origin; handedness and depth order; pitch clamp ±89°, distance clamp, invalid inputs ignored; orbit keeps distance
- [X] T-F516 [US4] Tests first `VisualCoreScenesTests/MeshTests.swift` (AC2 sphere 16×8 counts, unit normals; cube 24 vertices/36 indices; plane; segments "3–256", rings "2–256", subdivisions "≤ 256" clamped), then `VisualCoreScenes/MeshGenerators.swift` — Verified 2026-11-10: F05.t516-meshes exit 0: 3 tests — AC2 sphere 16×8 = 153 vertices / 672 indices, unit normals, all triangles outward and non-degenerate; cube 24/36; plane 4×4; segments/rings/subdivisions/radius clamped
- [ ] T-F517 [US4] Sim test first `VisualCoreRenderingTests/MeshRendererTests.swift` (lit sphere: center brighter than limb, background outside; recreation/teardown), then `VisualCoreRendering/MeshRenderer.swift` (Lambert)

## Phase 7: US5 — Standalone interactive demo (P2)

- [ ] T-F518 [US5] Sim test first `VisualCoreRenderingTests/TouchAdapterTests.swift` (synthesized began/moved/ended/cancelled → `PointerEvent`s in points with ids and timestamps), then `VisualCoreRendering/RenderView+Touches.swift` (`pointerHandler`)
- [ ] T-F519 [US5] Demo harness `Harnesses/InteractiveDemo/{InteractiveDemo.yml,Sources/*.swift}`: drag spawns particles, pinch zooms `Camera2D`, timeline animates shapes, Reduce Motion (system or `-uitestReduceMotion`) disables inertia and jumps tweens, diagnostics `demo.diagnostics` label `particles=<n> zoom=<z> state=<running|paused>`, VoiceOver labels, Dynamic Type; unsigned simulator build
- [ ] T-F520 [US5] UI test `Harnesses/InteractiveDemo/UITests/InteractiveDemoUITests.swift` (AC1 drag → particles > 0; AC2 pinch → zoom > 1; AC3 background/foreground → no burst beyond step cap) on iOS 27.2 and 26.5; `nm` of the built demo shows zero ProjectM symbols (SC-F505)

## Phase 8: Polish & Cross-Cutting

- [ ] T-F521 Document the interaction modules in `Packages/VisualCore/README.md` and `Packages/VisualCoreRendering/README.md` (coordinate spaces, gesture thresholds, determinism scope, bounds)
- [ ] T-F522 Full verification: host tests, sim 27.2 + 26.5, generic iOS, demo build/UI test, dependencies R1–R5, compliance, scripts, docs, reference regression
- [ ] T-F523 {device} Per-device particle/primitive/mesh draw cost and demo frame pacing on D1/D2/D3 — **deferred to campaign II** (constitution V); automation mode added with the AutomationRunner (F09)

## Dependencies

Setup → T-F502/T-F503 (math) → US1 (T-F504→T-F505→T-F506) and US2 (T-F507…T-F510) can proceed independently →
US3 (T-F511, T-F512 need math/RNG; T-F513 needs T-F511; T-F514 needs T-F512) → US4 (T-F515→T-F516→T-F517) →
US5 (T-F518 → T-F519 needs all subsystems → T-F520) → Polish.

## Parallel Opportunities

Pure subsystems in different files could run in parallel ([P]-eligible: T-F504, T-F507, T-F508, T-F509), but the
owner's one-commit-per-task cadence and one-writer rule mean they are executed sequentially here.

## Implementation Strategy

MVP = math + US1 coordinates/gestures. Then timing (US2), primitives/particles (US3), 3D (US4), demo (US5). Each
subsystem lands with its tests and its own commit and push.
