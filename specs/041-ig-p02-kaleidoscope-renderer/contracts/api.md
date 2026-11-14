# Contract: A05-P02 framework additions

```swift
public struct ViewBounds2D: Sendable, Equatable, Codable { public var zoomRange: ClosedRange<Double>; public var extent: Double
  public init(zoomRange: ClosedRange<Double>, extent: Double); public func clamp(_ camera: Camera2D) -> Camera2D }
extension Camera2D { public func panned(by delta: Vec2, within bounds: ViewBounds2D) -> Camera2D
  public func zoomed(by factor: Double, within bounds: ViewBounds2D) -> Camera2D }
public struct OrbitBounds: Sendable, Equatable, Codable { public var pitchLimit: Double; public var distanceRange: ClosedRange<Double>
  public init(pitchLimit: Double, distanceRange: ClosedRange<Double>); public func clamp(_ camera: OrbitCamera) -> OrbitCamera }
extension OrbitCamera { public func orbited(yaw: Double, pitch: Double, within bounds: OrbitBounds) -> OrbitCamera
  public func zoomed(by factor: Double, within bounds: OrbitBounds) -> OrbitCamera }
```

GLSL (`vc/sdf.glsl`): `float vc_sdCircle(vec2 p, float r)`, `float vc_sdBox2(vec2 p, vec2 b)`,
`float vc_sdSegment(vec2 p, vec2 a, vec2 b)`, `vec2 vc_foldDihedral(vec2 p, float n)`; the experience's shader computes the
convex-polygon distance itself from `vc_sdSegment` and an inside test (polygon points are experience data).
