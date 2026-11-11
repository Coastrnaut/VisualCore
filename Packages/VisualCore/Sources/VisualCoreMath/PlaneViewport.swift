// PlaneViewport.swift — a double-precision view of an unbounded 2D plane (complex plane, simulation domain) on a
// screen (feature 026 T-A03-101; gap G-VIEWPORT; FR-A03-104; research R1–R2). Unlike Camera2D (point-space scenes,
// zoom 0.1…100) it keeps pixels square at any aspect and zooms over ~18 orders of magnitude with an anchored pinch.

/// A plane-to-screen mapping: `center` is the plane point at the view's middle, `unitsPerPoint` the plane distance
/// per screen point (equal on both axes, so pixels stay square) and `size` the view in points. Screen y grows down;
/// plane y grows up. Values are validated: non-finite centers become (0, 0), the scale is clamped to
/// `minUnitsPerPoint…maxUnitsPerPoint` (`wasClamped` reports it) and invalid sizes keep the last valid size.
public struct PlaneViewport: Sendable, Equatable {
    /// The finest scale: Double keeps about 1e-15 relative resolution near |center| ≈ 1.
    public static let minUnitsPerPoint = 1e-15
    /// The coarsest scale.
    public static let maxUnitsPerPoint = 1e3

    /// Plane point at the middle of the view.
    public private(set) var center: Vec2
    /// Plane units per screen point.
    public private(set) var unitsPerPoint: Double
    /// View size in points (always positive and finite).
    public private(set) var size: Vec2
    /// True when the requested scale was outside the limits (or not finite) and was clamped.
    public private(set) var wasClamped: Bool

    /// Creates a viewport; invalid values are replaced as described on the type.
    public init(center: Vec2, unitsPerPoint: Double, size: Vec2) {
        self.center = center.isFinite ? center : .zero
        (self.unitsPerPoint, wasClamped) = Self.clamp(unitsPerPoint)
        self.size = Self.valid(size) ? size : Vec2(1, 1)
    }

    /// A viewport showing `width` plane units across the shorter side of `size`, centered on `center`.
    public static func framing(width: Double, center: Vec2, size: Vec2) -> PlaneViewport {
        let s = valid(size) ? size : Vec2(1, 1)
        return PlaneViewport(center: center, unitsPerPoint: width / Swift.min(s.x, s.y), size: s)
    }

    /// The plane point under a screen point (points, origin top-left).
    public func plane(fromScreen p: Vec2) -> Vec2 {
        Vec2(center.x + (p.x - size.x / 2) * unitsPerPoint, center.y - (p.y - size.y / 2) * unitsPerPoint)
    }

    /// The screen point (points, origin top-left) of a plane point.
    public func screen(fromPlane p: Vec2) -> Vec2 {
        Vec2(size.x / 2 + (p.x - center.x) / unitsPerPoint, size.y / 2 - (p.y - center.y) / unitsPerPoint)
    }

    /// Zooms by `scale` (> 1 magnifies) keeping the plane point under `anchor` fixed. Non-finite or non-positive input
    /// returns the viewport unchanged.
    public func pinched(by scale: Double, anchor: Vec2) -> PlaneViewport {
        guard scale.isFinite, scale > 0, anchor.isFinite else { return self }
        let fixed = plane(fromScreen: anchor)
        var out = self
        (out.unitsPerPoint, out.wasClamped) = Self.clamp(unitsPerPoint / scale)
        out.center = Vec2(fixed.x - (anchor.x - size.x / 2) * out.unitsPerPoint,
                          fixed.y + (anchor.y - size.y / 2) * out.unitsPerPoint)
        return out
    }

    /// Moves the content with a finger drag of `delta` screen points. Non-finite input returns the viewport unchanged.
    public func panned(by delta: Vec2) -> PlaneViewport {
        guard delta.isFinite else { return self }
        var out = self
        out.center = Vec2(center.x - delta.x * unitsPerPoint, center.y + delta.y * unitsPerPoint)
        return out
    }

    /// The same center and scale on a new view size (rotation, split view). An invalid size keeps the current one.
    public func resized(to newSize: Vec2) -> PlaneViewport {
        guard Self.valid(newSize) else { return self }
        var out = self
        out.size = newSize
        return out
    }

    private static func valid(_ s: Vec2) -> Bool { s.isFinite && s.x > 0 && s.y > 0 }

    private static func clamp(_ u: Double) -> (Double, Bool) {
        guard u.isFinite, u > 0 else { return (u == .infinity ? maxUnitsPerPoint : 1, true) }
        let c = Swift.min(Swift.max(u, minUnitsPerPoint), maxUnitsPerPoint)
        return (c, c != u)
    }
}
