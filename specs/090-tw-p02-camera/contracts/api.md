# Contract: public API added in A12-P02

```swift
// VisualCoreMath
public struct Ray3: Sendable, Equatable {
    public let origin: Vec3, direction: Vec3                  // direction is unit length
    public init?(origin: Vec3, direction: Vec3)               // nil for non-finite values or a zero direction
    public func intersect(boxMin: Vec3, boxMax: Vec3) -> RayHit3?
    public func intersect(sphereCenter: Vec3, radius: Double) -> RayHit3?
    public func intersect(triangle a: Vec3, _ b: Vec3, _ c: Vec3) -> RayHit3?
    public static func nearest(_ hits: [RayHit3?]) -> RayHit3?
}
public struct RayHit3: Sendable, Equatable { public let distance: Double, point: Vec3, normal: Vec3 }

// VisualCoreRendering
extension MeshRenderer {
    /// colors: one RGBA (0…1) per vertex, or nil for today's behaviour. Throws MeshError.invalidInput for a wrong count,
    /// a non-finite value or one outside 0…1.
    public convenience init(mesh: Mesh, colors: [Vec4]?, registry: ResourceRegistry) throws
}
```

Documented with `///`; API baseline additive; existing behaviour unchanged.
