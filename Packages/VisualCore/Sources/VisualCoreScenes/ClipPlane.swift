// ClipPlane — feature 212 (R02-F12) T-R02F12-002 (FR-R02F12-002, FR-R02F12-003). An oriented plane n · p = offset with a
// unit normal; a cut keeps the side where `distance(to:)` ≤ 0 (below the plane) and removes the side above.
import VisualCoreMath

/// An oriented cut plane (see the file header).
public struct ClipPlane: Sendable, Equatable, Codable {
    /// The unit normal, pointing to the removed side.
    public let normal: Vec3
    /// The plane's offset along the normal: points with n · p = offset lie on it.
    public let offset: Double

    /// A plane from a finite, non-zero `normal` (normalised unless it already has unit length within 1e-12, so a stored
    /// plane reads back bit for bit) and a finite `offset`.
    public init(normal: Vec3, offset: Double) throws(ConvexSolidError) {
        guard normal.x.isFinite, normal.y.isFinite, normal.z.isFinite else { throw .nonFinite("normal") }
        guard offset.isFinite else { throw .nonFinite("offset") }
        let length = normal.length
        guard length > 0 else { throw .zeroNormal }
        self.normal = abs(length - 1) <= 1e-12 ? normal : normal / length
        self.offset = offset
    }

    /// The signed distance of `p`: negative on the kept side, positive on the removed side.
    public func distance(to p: Vec3) -> Double { normal.dot(p) - offset }

    private enum CodingKeys: String, CodingKey { case normal, offset }

    /// Decodes and re-validates a stored plane.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let n = try c.decode(Vec3.self, forKey: .normal)
        let h = try c.decode(Double.self, forKey: .offset)
        do { try self.init(normal: n, offset: h) } catch {
            throw DecodingError.dataCorrupted(.init(codingPath: c.codingPath, debugDescription: error.reasonCode,
                                                    underlyingError: error))
        }
    }

    /// Encodes the normal and the offset.
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(normal, forKey: .normal)
        try c.encode(offset, forKey: .offset)
    }
}
