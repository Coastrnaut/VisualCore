// OriginRebase — feature 054 (A07-P01) T-A07-102 (FR-A07-103; gap G-ORIGINREBASE; research D4).
// Keeps drawn positions near the camera so Float precision does not degrade with distance from the world origin.

/// A floating origin on a 1,024-unit grid: positions are drawn relative to it, so their Float values stay small and
/// precise however far the camera travels. The origin is part of the deterministic state.
public struct OriginRebase: Sendable, Equatable, Codable {
    /// Grid step and distance (per axis) the camera may move from the origin before it is rebased, world units.
    public static let threshold = 1024.0

    /// The current origin; always a multiple of ``threshold`` on every axis.
    public var origin: Vec3

    /// Creates a rebase state at `origin` (default: the world origin).
    public init(origin: Vec3 = .zero) { self.origin = origin }

    /// Rebases when the camera is farther than ``threshold`` from the origin on any axis: the origin becomes
    /// `threshold · round(camera ÷ threshold)` per axis. A non-finite camera position is ignored.
    ///
    /// - Parameter camera: The camera position in world units.
    public mutating func update(camera: Vec3) {
        guard camera.isFinite else { return }
        let offset = camera - origin
        let t = Self.threshold
        guard abs(offset.x) > t || abs(offset.y) > t || abs(offset.z) > t else { return }
        origin = Vec3(t * (camera.x / t).rounded(), t * (camera.y / t).rounded(), t * (camera.z / t).rounded())
    }

    /// The drawing position of `p`: `Float(p − origin)`, subtracting in Double first so precision is kept.
    ///
    /// - Parameter p: A world position.
    public func local(_ p: Vec3) -> SIMD3<Float> {
        let d = p - origin
        return SIMD3<Float>(Float(d.x), Float(d.y), Float(d.z))
    }
}
