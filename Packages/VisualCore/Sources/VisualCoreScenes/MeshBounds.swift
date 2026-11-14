// MeshBounds.swift — feature 205 (R02-F05) T-R02F05-004 (FR-R02F05-040, SC-R02F05-004).
// Tight axis-aligned bounds and the enclosing sphere of a mesh, with an explicit empty result.
import VisualCoreMath

/// The bounds of a mesh: an explicit empty result, or a tight axis-aligned box.
public enum MeshBounds: Sendable, Equatable {
    /// The mesh has no vertices.
    case empty
    /// The smallest axis-aligned box holding every vertex.
    case box(min: Vec3, max: Vec3)

    /// The box centre, or `nil` when empty.
    public var center: Vec3? {
        guard case let .box(lo, hi) = self else { return nil }
        return (lo + hi) * 0.5
    }

    /// The radius of the enclosing sphere around `center` (half the box diagonal), or `nil` when empty.
    public var radius: Double? {
        guard case let .box(lo, hi) = self else { return nil }
        return (hi - lo).length * 0.5
    }

    /// Whether `p` lies in the box, widened by `tolerance` on every side; always `false` when empty.
    public func contains(_ p: Vec3, tolerance: Double = 1e-9) -> Bool {
        guard case let .box(lo, hi) = self else { return false }
        return p.x >= lo.x - tolerance && p.x <= hi.x + tolerance
            && p.y >= lo.y - tolerance && p.y <= hi.y + tolerance
            && p.z >= lo.z - tolerance && p.z <= hi.z + tolerance
    }
}

extension Mesh {
    /// The tight axis-aligned bounds of all positions, or `.empty` for a mesh without vertices.
    public var bounds: MeshBounds {
        guard var lo = positions.first else { return .empty }
        var hi = lo
        for p in positions.dropFirst() {
            lo = Vec3(Swift.min(lo.x, p.x), Swift.min(lo.y, p.y), Swift.min(lo.z, p.z))
            hi = Vec3(Swift.max(hi.x, p.x), Swift.max(hi.y, p.y), Swift.max(hi.z, p.z))
        }
        return .box(min: lo, max: hi)
    }
}
