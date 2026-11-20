// ScreenProjection — feature 222 (R02-F22) T-R02F22-002 (FR-R02F22-001; SC-R02F22-001; clarification Q1; research R1).
// Screen points are in points with the origin at the top left, y down, inside a viewport w × h. NDC is
// (2x / w − 1, 1 − 2y / h) with clip depth −1 … +1 (the GL convention of `Mat4.perspective`). A ray unprojects the
// screen point at depths −1 and +1 through the inverse view-projection; projecting goes the other way.

/// Turns screen points into world rays and world points into screen points, for any view-projection.
public enum ScreenProjection {
    /// The world ray through `point` of a `viewport` (w × h points), from the near to the far plane; nil outside the
    /// viewport (its edges are inside), for a viewport that is not finite and positive, for non-finite input or for a
    /// degenerate unprojection.
    public static func ray(through point: Vec2, viewport: Vec2, inverseViewProjection: Mat4) -> Ray3? {
        guard viewport.isFinite, viewport.x > 0, viewport.y > 0, point.isFinite else { return nil }
        guard point.x >= 0, point.x <= viewport.x, point.y >= 0, point.y <= viewport.y else { return nil }
        let ndc = Vec2(2 * point.x / viewport.x - 1, 1 - 2 * point.y / viewport.y)
        guard let near = unproject(Vec3(ndc.x, ndc.y, -1), inverseViewProjection),
              let far = unproject(Vec3(ndc.x, ndc.y, 1), inverseViewProjection) else { return nil }
        return Ray3(origin: near, direction: far - near)
    }

    /// The screen point (points, origin top left) and NDC depth of `world`; nil when it lies behind the camera (clip
    /// w ≤ 0), for a viewport that is not finite and positive, or for non-finite input. The point may lie outside the
    /// viewport and the depth outside −1 … 1.
    public static func project(_ world: Vec3, viewProjection: Mat4, viewport: Vec2) -> (point: Vec2, depth: Double)? {
        guard viewport.isFinite, viewport.x > 0, viewport.y > 0, world.isFinite else { return nil }
        let clip = viewProjection * Vec4(world, 1)
        guard clip.w > 0, clip.w.isFinite else { return nil }
        let ndc = clip.xyz / clip.w
        guard ndc.isFinite else { return nil }
        return (Vec2((ndc.x + 1) / 2 * viewport.x, (1 - ndc.y) / 2 * viewport.y), ndc.z)
    }

    /// `ndc` mapped back to world space; nil when the homogeneous w is not positive-finite or the result not finite.
    private static func unproject(_ ndc: Vec3, _ inverse: Mat4) -> Vec3? {
        let h = inverse * Vec4(ndc, 1)
        guard h.w.isFinite, h.w != 0 else { return nil }
        let p = h.xyz / h.w
        return p.isFinite ? p : nil
    }
}
