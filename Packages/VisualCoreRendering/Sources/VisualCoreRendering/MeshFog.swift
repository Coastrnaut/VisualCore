// MeshFog.swift — linear eye-depth fog for MeshRenderer and DepthMeshPass (feature 055 (A07-P02) T-A07-203
// (FR-A07-202; gap G-RAILDRAW)). The fragment colour is mixed toward `color` with the factor
// clamp((depth − start) / (end − start), 0, 1), where depth is the eye-space distance along the view direction.
import VisualCoreMath

/// Linear depth fog: geometry nearer than `start` keeps its colour, geometry beyond `end` takes `color`, and the mix is
/// linear in eye-space depth between them.
public struct MeshFog: Sendable, Equatable {
    /// Eye-space depth (world units in front of the camera) where the fog begins; at least 0.
    public let start: Double
    /// Eye-space depth where the fog is complete; greater than `start`.
    public let end: Double
    /// Premultiplied-alpha fog colour (RGBA 0…1), usually the clear colour so far geometry dissolves into it.
    public let color: Vec4

    /// Creates a fog from `start` to `end` toward `color`; returns nil when any value is not finite, `start` is
    /// negative or `end` is not greater than `start`.
    public init?(start: Double, end: Double, color: Vec4) {
        guard start.isFinite, end.isFinite, start >= 0, end > start,
              color.x.isFinite, color.y.isFinite, color.z.isFinite, color.w.isFinite else { return nil }
        self.start = start
        self.end = end
        self.color = color
    }
}
