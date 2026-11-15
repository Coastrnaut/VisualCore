# Contract: public API added to VisualCoreMath (A13-P01)

```swift
public struct Segment2: Sendable, Equatable, Hashable, Codable {
    public var a: Vec2, b: Vec2
    public init(_ a: Vec2, _ b: Vec2)
}

public struct RayHit2: Sendable, Equatable {
    public let distance: Double        // > minimumDistance
    public let point: Vec2
    public let segmentIndex: Int       // index into the array passed to cast
    public let normal: Vec2            // unit, facing the ray (dot(normal, direction) < 0)
}

public struct Ray2: Sendable, Equatable {
    public let origin: Vec2
    public let direction: Vec2         // unit length
    /// nil for a non-finite origin or a zero or non-finite direction; the direction is normalised.
    public init?(origin: Vec2, direction: Vec2)
    /// The point at distance t along the ray.
    public func point(at t: Double) -> Vec2
    /// Nearest hit with distance > minimumDistance; parallel and collinear segments miss; end points count; segments
    /// with non-finite or coincident end points are skipped; the segment at index `excluding` is ignored.
    public func cast(against segments: [Segment2], excluding: Int? = nil, minimumDistance: Double = 1e-9) -> RayHit2?
}

extension Vec2 {
    /// self − 2 (self · n) n for a unit normal n; a zero or non-finite normal returns self unchanged.
    public func reflected(about normal: Vec2) -> Vec2
}
```

All declarations carry `///` documentation; the API baseline is updated; no existing declaration changes.
