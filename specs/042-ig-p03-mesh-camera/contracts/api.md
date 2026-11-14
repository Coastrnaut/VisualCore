# Contract: A05-P03 framework additions

```swift
// VisualCoreMath
public struct OrbitViewBounds: Sendable, Equatable, Codable {
  public var orbit: OrbitBounds; public var targetRadius: Double; public var fovRange: ClosedRange<Double>; public var clearance: Double
  public init(orbit: OrbitBounds, targetRadius: Double, fovRange: ClosedRange<Double>, clearance: Double = 0)
  public func minimumDistance(for camera: OrbitCamera) -> Double      // max(lower, |target| + clearance + 2·near)
  public func clamp(_ camera: OrbitCamera) -> OrbitCamera             // pitch, yaw wrap, target radius, fov, distance (with the rule)
}
extension OrbitCamera {
  public var forward: Vec3; public var right: Vec3; public var up: Vec3          // view basis (world up y)
  public func panned(by delta: Vec2, within bounds: OrbitViewBounds) -> OrbitCamera
  public func withFieldOfView(_ fovY: Double, within bounds: OrbitViewBounds) -> OrbitCamera
  public func orbited(yaw: Double, pitch: Double, within bounds: OrbitViewBounds) -> OrbitCamera
  public func zoomed(by factor: Double, within bounds: OrbitViewBounds) -> OrbitCamera
}
// VisualCoreRendering
public final class DepthMeshPass {
  public struct Item { public var renderer: MeshRenderer; public var model: Mat4; public var color: Vec4
    public init(renderer: MeshRenderer, model: Mat4 = .identity, color: Vec4) }
  public var clearColor: Vec4
  public init(registry: ResourceRegistry)
  public func draw(_ items: [Item], camera: OrbitCamera, context: RenderContext) throws
  public func release()
}
```

Invalid inputs (non-finite delta, fov, factor ≤ 0) return the camera unchanged. `draw` with a zero-sized context draws
nothing; with no items it clears to `clearColor` and blits.
