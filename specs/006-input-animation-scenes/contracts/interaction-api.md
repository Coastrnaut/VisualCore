# Contract: interaction, animation, scenes and drawing API (Phase 5)

```swift
// VisualCoreMath (pure)
public struct Vec2, Vec3, Vec4, Mat3, Mat4, Quat            // Double math, Sendable, Equatable
public struct Camera2D { center, zoom (0.1...100), rotation; var matrix: Mat3; var inverse: Mat3
  mutating func zoom(by factor: Double, around anchor: Vec2 = .zero); mutating func pan(by delta: Vec2) }   // pinch / drag (US5)
public struct OrbitCamera { target, distance, yaw, pitch (±89°), fovY, near, far
  func view() -> Mat4; func projection(aspect:) -> Mat4; func project(_ p: Vec3, aspect:) -> Vec3; func ray(ndc: Vec2, aspect:) -> (origin: Vec3, direction: Vec3)
  mutating func orbit(dYaw:dPitch:); mutating func zoom(by:) }
public enum EasingCurve { linear, quad, cubic, sine, expo, back, elastic, bounce }; public enum EasingMode { in, out, inOut }
public func ease(_ t: Double, _ curve: EasingCurve, _ mode: EasingMode) -> Double

// VisualCoreSimulation (pure)
public struct FixedStepClock { init(step: Double = 1/120, maxSteps: Int = 8); mutating func advance(by dt: Double) -> Int
  var alpha: Double; var droppedTime: Double; var totalSteps: Int; var invalidDeltas: Int; var simulatedTime: Double
  mutating func resetAccumulator() }   // return from background without a catch-up burst (US5 AC3)
public struct SeededRandom: RandomNumberGenerator { init(seed: UInt64); mutating func next() -> UInt64; double(); float(); range(_:); normal() }
public struct Tween { from, to, duration, curve, mode, repeatCount (nil = forever), autoreverses; func value(at t: Double) -> Double }
public struct Timeline { add(_:at:name:); advance(by:) -> [TimelineEvent]; seek(to:); rate; isPaused; reduceMotion; value(of name:) }
public struct ParticleSystem { init(capacity: Int = 10_000, seed: UInt64); emitters; forces
  mutating func step(_ dt: Double); var aliveCount; var droppedCount; var nanRemoved; func checksum() -> UInt64
  func instances() -> [ParticleInstance] }   // position, size, color for drawing
public struct ParticleInstance { init(position: Vec2, size: Double, color: Vec4) }   // size = world diameter

// VisualCoreScenes (pure)
public struct ViewMetrics { size: Vec2 (points), scale; func toPixels/toNDC/fromNDC(_:); func toWorld(_:camera:) -> Vec2?; func fromWorld(_:camera:) -> Vec2? }
public struct PointerEvent { id: Int; phase: PointerPhase; location: Vec2; timestamp: Double }
public struct PointerTracker { static let maxPointers = 10; mutating func handle(_:) -> Bool; var active: [Int: Vec2]; var ignored: Int }
public protocol GestureRecognizer { var state: GestureState { get }; mutating func handle(_ e: PointerEvent, tracker: PointerTracker); mutating func tick(now: Double) }
public struct TapRecognizer, DoubleTapRecognizer, LongPressRecognizer, DragRecognizer, PinchRecognizer, RotateRecognizer
  // values: location (tap/double/long/drag), DragRecognizer.translation/velocity, Pinch.scale/center, Rotate.angle/center
public enum GestureState { possible, began, changed, ended, cancelled, failed, recognized }
public final class SceneNode { transform, z, isVisible, primitive, children; func worldTransform() -> Mat3; func hitTest(_ world: Vec2) -> SceneNode? }
public enum Primitive { rect(Vec2), circle(Double), line(Vec2, Vec2, width: Double), polygon([Vec2]) }
public struct Mesh { positions, normals, uvs, indices; static func plane(subdivisions:), cube(), uvSphere(segments:rings:radius:)
  func interleavedPositionNormal() -> [Float] }

// VisualCoreRendering (iOS, @MainActor)
public final class PrimitiveRenderer { init(registry:) throws; func draw(_ root: SceneNode, camera: Camera2D, metrics: ViewMetrics) throws; func release(); var lastTriangleCount: Int }
public final class ParticleRenderer { init(registry:) throws; func draw(_ instances: [ParticleInstance], camera: Camera2D, metrics: ViewMetrics) throws; func release(); var lastInstanceCount: Int }
public final class MeshRenderer { init(mesh: Mesh, registry:) throws; func draw(model: Mat4 = .identity, camera: OrbitCamera, aspect: Double, color: Vec4) throws; func release()
  var lightDirection: Vec3; var ambient: Double }
GPUBuffer.upload(indices: [UInt32], target:)   // index buffers (MeshRenderer)
RenderHost.pointerHandler: ((PointerEvent) -> Void)?   // UIKit touches → PointerEvent (points, timestamp, stable ids); enables multi-touch; touches cancelled when the view leaves its window
```

Bounds (constitution IX): ≤ 10 pointers, particle capacity ≤ 100,000, polygon ≤ 256 points, circle ≤ 128
segments, sphere segments 3–256 / rings 2–256, ≤ 8 steps per frame. Out-of-range inputs are clamped.

Demo harness contract: accessibility identifier `demo.diagnostics` with label `particles=<n> zoom=<z> state=<running|paused>`;
`demo.steps` with label `maxStepsPerFrame=<n>` (since launch or the last return to the foreground); `demo.canvas`
(direct-interaction canvas); buttons `demo.toggle` ("Pause simulation"/"Resume simulation") and `demo.reset`;
launch argument `-uitestReduceMotion YES|NO` overrides the system setting for tests.
