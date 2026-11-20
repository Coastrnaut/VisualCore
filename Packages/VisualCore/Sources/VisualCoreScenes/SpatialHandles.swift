// SpatialHandles — feature 222 (R02-F22) T-R02F22-003 (FR-R02F22-002; SC-R02F22-002; clarification Q2). Handles are
// world points a finger can grab; `HandlePicker.pick` projects them through a view-projection and picks the one the
// touch meant: nearest on screen within max(touch radius, hit radius), the touch radius raised to at least 22 points
// (half the 44-point minimum target), then nearest in NDC depth, then lowest index. Handles behind the camera
// (clip w ≤ 0) or outside the depth range −1 … 1 are skipped; a non-finite touch picks nothing.
import VisualCoreMath

/// What a handle does when dragged; the vectors are directions in world space.
public enum HandleKind: Sendable, Equatable, Codable {
    /// A free point, moved in the view plane.
    case point
    /// A handle that slides along the given axis direction.
    case axis(Vec3)
    /// A handle that slides in the plane with the given normal.
    case plane(Vec3)
    /// A handle that turns about the given axis direction.
    case rotation(Vec3)

    /// The direction a constrained kind carries; nil for `.point`.
    var vector: Vec3? {
        switch self {
        case .point: nil
        case .axis(let v), .plane(let v), .rotation(let v): v
        }
    }
}

/// A grabbable world point with an id, a kind and an extra hit radius in screen points.
public struct SpatialHandle: Sendable, Equatable, Codable {
    /// The caller's identifier of the handle.
    public let id: Int
    /// The world position of the handle (finite).
    public let position: Vec3
    /// What the handle does when dragged.
    public let kind: HandleKind
    /// A hit radius in screen points (finite, ≥ 0); a touch within it picks the handle even beyond the touch radius.
    public let hitRadius: Double

    /// Creates a handle; refuses a non-finite `position` (`.parameter("position")`), a `hitRadius` that is not
    /// finite and ≥ 0 (`.parameter("hitRadius")`) and a kind vector that is not finite or is zero (`.parameter("kind")`).
    public init(id: Int, position: Vec3, kind: HandleKind = .point, hitRadius: Double = 0) throws(SpatialControlError) {
        guard position.isFinite else { throw .parameter("position") }
        guard hitRadius.isFinite, hitRadius >= 0 else { throw .parameter("hitRadius") }
        if let vector = kind.vector {
            guard vector.isFinite, vector != .zero else { throw .parameter("kind") }
        }
        self.id = id
        self.position = position
        self.kind = kind
        self.hitRadius = hitRadius
    }

    private enum CodingKeys: String, CodingKey { case id, position, kind, hitRadius }

    /// Decodes a handle and re-validates it; a handle the initializer refuses is `DecodingError.dataCorrupted`.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(Int.self, forKey: .id)
        let position = try container.decode(Vec3.self, forKey: .position)
        let kind = try container.decode(HandleKind.self, forKey: .kind)
        let hitRadius = try container.decode(Double.self, forKey: .hitRadius)
        do {
            try self.init(id: id, position: position, kind: kind, hitRadius: hitRadius)
        } catch {
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: decoder.codingPath, debugDescription: "invalid spatial handle: \(error.reasonCode)",
                underlyingError: error))
        }
    }
}

/// Picks the handle a touch meant (see the file header for the rule).
public enum HandlePicker {
    /// The most handles one pick accepts; more is `.handleLimit`.
    public static let maxHandles = 1_024
    /// The smallest touch radius in screen points (half the 44-point minimum target); smaller values are raised.
    public static let minimumTouchRadius = 22.0

    /// The index in `handles` of the handle picked by a touch at `touch` (screen points, origin top left) in a
    /// `viewport` (w × h points), or nil when no handle is a candidate or the touch is not finite. A finite
    /// `touchRadius` is raised to at least ``minimumTouchRadius``; a non-finite one counts as ``minimumTouchRadius``.
    /// Refuses more than ``maxHandles`` handles (`.handleLimit`) and a viewport that is not finite and positive
    /// (`.viewport`).
    public static func pick(_ handles: [SpatialHandle], at touch: Vec2, viewProjection: Mat4, viewport: Vec2,
                            touchRadius: Double = minimumTouchRadius) throws(SpatialControlError) -> Int? {
        guard handles.count <= maxHandles else { throw .handleLimit }
        guard viewport.isFinite, viewport.x > 0, viewport.y > 0 else { throw .viewport }
        guard touch.isFinite else { return nil }
        let radius = touchRadius.isFinite ? max(minimumTouchRadius, touchRadius) : minimumTouchRadius
        var best: (index: Int, distance: Double, depth: Double)? = nil
        for index in handles.indices {
            let handle = handles[index]
            guard let projected = ScreenProjection.project(handle.position, viewProjection: viewProjection,
                                                           viewport: viewport) else { continue }
            guard projected.depth >= -1, projected.depth <= 1 else { continue }
            let distance = (projected.point - touch).length
            guard distance <= max(radius, handle.hitRadius) else { continue }
            if let current = best {
                let better = distance < current.distance
                    || (distance == current.distance && projected.depth < current.depth)
                guard better else { continue }
            }
            best = (index, distance, projected.depth)
        }
        return best?.index
    }
}
