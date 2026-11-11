// ViewMetrics.swift — conversions between view points, pixels, NDC and 2D world coordinates
// (feature 006 T-F504; FR-F501, SC-F501; research R1).
//   points: origin top-left, y down (UIKit)       pixels: points × scale, origin top-left, y down
//   NDC:    origin center, x right, y up, −1…1    camera: points from the view center, y up
//   world:  camera space through Camera2D.inverse
// Conversions needing the size return nil for a zero-size (not yet laid out) view.
import VisualCoreMath

public struct ViewMetrics: Sendable, Equatable {
    /// View size in points.
    public var size: Vec2
    /// Points → pixels factor (display scale × content scale).
    public var scale: Double

    public init(size: Vec2, scale: Double) {
        self.size = size
        self.scale = scale
    }

    /// True when every conversion is defined.
    public var isValid: Bool { size.x > 0 && size.y > 0 && scale > 0 && size.isFinite && scale.isFinite }
    public var pixelSize: Vec2 { size * scale }
    public var aspect: Double? { isValid ? size.x / size.y : nil }

    public func toPixels(_ p: Vec2) -> Vec2? { isValid ? p * scale : nil }
    public func fromPixels(_ p: Vec2) -> Vec2? { isValid ? p / scale : nil }

    public func toNDC(_ p: Vec2) -> Vec2? {
        guard isValid else { return nil }
        return Vec2(2 * p.x / size.x - 1, 1 - 2 * p.y / size.y)
    }
    public func fromNDC(_ n: Vec2) -> Vec2? {
        guard isValid else { return nil }
        return Vec2((n.x + 1) / 2 * size.x, (1 - n.y) / 2 * size.y)
    }

    /// View point → camera space (points from the center, y up).
    public func toCamera(_ p: Vec2) -> Vec2? { isValid ? Vec2(p.x - size.x / 2, size.y / 2 - p.y) : nil }
    public func fromCamera(_ c: Vec2) -> Vec2? { isValid ? Vec2(c.x + size.x / 2, size.y / 2 - c.y) : nil }

    public func toWorld(_ p: Vec2, camera: Camera2D) -> Vec2? { toCamera(p).map { camera.inverse.apply($0) } }
    public func fromWorld(_ w: Vec2, camera: Camera2D) -> Vec2? { fromCamera(camera.matrix.apply(w)) }

    /// World → NDC matrix for drawing (camera space scaled by 2 / size).
    public func worldToNDC(camera: Camera2D) -> Mat3? {
        guard isValid else { return nil }
        return Mat3.scale(Vec2(2 / size.x, 2 / size.y)) * camera.matrix
    }
}
